// What a parallel loop defines and the host reads after it.
//
// A variable of unspecified locality that only one iteration defines has
// that value after the loop (Fortran 2018, 11.1.7.5), and one that an
// iteration defines before it references it is a temporary of that
// iteration. The threads of a kernel run the iterations at the same time,
// so a variable all of them read and write in place would serve neither:
// one thread could read what another wrote in between. Each thread keeps
// a private copy of the variable instead, which it takes from where the
// value is shared on entry, and after each statement that defines the
// copy or a part of it puts that part back (GpuLiveoutWriteBack).
//
// A scalar is shared in a one-element buffer the launch copies the value
// into and back out of. A derived-type variable is a kernel argument, which
// the device writes in place; a thread keeps a copy of each scalar
// component (or component of a component) the loop defines, and of the
// whole value only where the loop names it whole. An element or a section
// of an array component is defined in place, as an element of an array.

#include <map>
#include <set>
#include <string>
#include <utility>
#include <vector>

#include <libasr/asr.h>
#include <libasr/asr_builder.h>
#include <libasr/asr_utils.h>
#include <libasr/containers.h>
#include <libasr/pass/gpu_data_layout.h>
#include <libasr/pass/gpu_offload_collect.h>
#include <libasr/pass/gpu_offload_liveout.h>
#include <libasr/pass/gpu_offload_rewrite.h>
#include <libasr/pass/gpu_offload_visitor.h>
#include <libasr/pass/pass_utils.h>

namespace LCompilers {

namespace {

// --- What may be read after the loop ------------------------------------

// The procedure or main program whose body holds the statements of
// `scope`, past the BLOCK and ASSOCIATE constructs around them.
ASR::symbol_t *gpu_procedure_of(SymbolTable *scope) {
    for (; scope && scope->asr_owner; scope = scope->parent) {
        if (scope->asr_owner->type != ASR::asrType::symbol) return nullptr;
        ASR::symbol_t *owner = ASR::down_cast<ASR::symbol_t>(
            scope->asr_owner);
        if (ASR::is_a<ASR::Program_t>(*owner)
                || ASR::is_a<ASR::Function_t>(*owner)) {
            return owner;
        }
        if (!ASR::is_a<ASR::Block_t>(*owner)
                && !ASR::is_a<ASR::AssociateBlock_t>(*owner)) {
            return nullptr;
        }
    }
    return nullptr;
}

// The variables the statements walked reference, except in the parallel
// loop `skip`.
class GpuVariableUses : public ASRUtils::BlockBodyWalkVisitor<GpuVariableUses> {
public:
    std::set<ASR::symbol_t*> &used;
    const ASR::OMPRegion_t *skip;
    GpuVariableUses(std::set<ASR::symbol_t*> &used_,
        const ASR::OMPRegion_t *skip_ = nullptr) : used(used_), skip(skip_) {}
    void visit_Var(const ASR::Var_t &x) {
        used.insert(ASRUtils::symbol_get_past_external(x.m_v));
    }
    void visit_OMPRegion(const ASR::OMPRegion_t &x) {
        if (&x == skip) return;
        ASR::BaseWalkVisitor<GpuVariableUses>::visit_OMPRegion(x);
    }
};

class GpuLoopFinder : public ASRUtils::BlockBodyWalkVisitor<GpuLoopFinder> {
public:
    const ASR::OMPRegion_t *loop;
    bool found = false;
    GpuLoopFinder(const ASR::OMPRegion_t *loop_) : loop(loop_) {}
    void visit_OMPRegion(const ASR::OMPRegion_t &x) {
        if (&x == loop) {
            found = true;
            return;
        }
        ASR::BaseWalkVisitor<GpuLoopFinder>::visit_OMPRegion(x);
    }
};

// Adds to `used` what may be referenced once `loop` has run, when one of
// `stmts` holds it, and says whether one does.
bool gpu_collect_after_loop(ASR::stmt_t **stmts, size_t n,
        const ASR::OMPRegion_t &loop, std::set<ASR::symbol_t*> &used) {
    for (size_t i = 0; i < n; i++) {
        GpuLoopFinder finder(&loop);
        finder.visit_stmt(*stmts[i]);
        if (!finder.found) continue;
        ASR::stmt_t *s = stmts[i];
        if (s != &loop.base) {
            // Only the branch of an IF or the body of a BLOCK or ASSOCIATE
            // holding the loop is followed into; any other construct, a
            // loop around it in particular, can run its statements again
            // after the loop, so all of them count.
            bool inner = false;
            if (ASR::is_a<ASR::If_t>(*s)) {
                ASR::If_t *x = ASR::down_cast<ASR::If_t>(s);
                inner = gpu_collect_after_loop(x->m_body, x->n_body, loop,
                        used)
                    || gpu_collect_after_loop(x->m_orelse, x->n_orelse,
                        loop, used);
            } else if (ASR::is_a<ASR::BlockCall_t>(*s)) {
                ASR::symbol_t *m = ASRUtils::symbol_get_past_external(
                    ASR::down_cast<ASR::BlockCall_t>(s)->m_m);
                if (ASR::is_a<ASR::Block_t>(*m)) {
                    ASR::Block_t *b = ASR::down_cast<ASR::Block_t>(m);
                    inner = gpu_collect_after_loop(b->m_body, b->n_body,
                        loop, used);
                }
            } else if (ASR::is_a<ASR::AssociateBlockCall_t>(*s)) {
                ASR::symbol_t *m = ASRUtils::symbol_get_past_external(
                    ASR::down_cast<ASR::AssociateBlockCall_t>(s)->m_m);
                if (ASR::is_a<ASR::AssociateBlock_t>(*m)) {
                    ASR::AssociateBlock_t *b =
                        ASR::down_cast<ASR::AssociateBlock_t>(m);
                    inner = gpu_collect_after_loop(b->m_body, b->n_body,
                        loop, used);
                }
            }
            if (!inner) {
                GpuVariableUses c(used, &loop);
                c.visit_stmt(*s);
            }
        }
        GpuVariableUses c(used, &loop);
        for (size_t j = i + 1; j < n; j++) {
            c.visit_stmt(*stmts[j]);
        }
        return true;
    }
    return false;
}

// Whether a GO TO after the loop jumps back to a label before it.
class GpuBackwardJumpFinder
        : public ASRUtils::BlockBodyWalkVisitor<GpuBackwardJumpFinder> {
public:
    const ASR::OMPRegion_t *loop;
    bool passed = false;
    bool found = false;
    std::set<int64_t> labels_before;
    GpuBackwardJumpFinder(const ASR::OMPRegion_t *loop_) : loop(loop_) {}
    void visit_OMPRegion(const ASR::OMPRegion_t &x) {
        if (&x == loop) {
            passed = true;
            return;
        }
        ASR::BaseWalkVisitor<GpuBackwardJumpFinder>::visit_OMPRegion(x);
    }
    void visit_GoToTarget(const ASR::GoToTarget_t &x) {
        if (!passed) labels_before.insert(x.m_id);
    }
    void visit_GoTo(const ASR::GoTo_t &x) {
        if (passed && labels_before.count(x.m_target_id)) found = true;
    }
};

// The variables whose address the statements walked take, which another
// name can then read: an EQUIVALENCE, or the target of a pointer.
class GpuAddressTaken
        : public ASRUtils::BlockBodyWalkVisitor<GpuAddressTaken> {
public:
    std::set<ASR::symbol_t*> &used;
    GpuAddressTaken(std::set<ASR::symbol_t*> &used_) : used(used_) {}
    void note(ASR::expr_t *e) {
        if (e && ASR::is_a<ASR::Var_t>(*e)) {
            used.insert(ASRUtils::symbol_get_past_external(
                ASR::down_cast<ASR::Var_t>(e)->m_v));
        }
    }
    void visit_GetPointer(const ASR::GetPointer_t &x) {
        note(x.m_arg);
        ASR::BaseWalkVisitor<GpuAddressTaken>::visit_GetPointer(x);
    }
    void visit_Associate(const ASR::Associate_t &x) {
        note(x.m_value);
        ASR::BaseWalkVisitor<GpuAddressTaken>::visit_Associate(x);
    }
};

// Adds to `used` what the procedures contained in `scope` reference, any
// of which a statement after a loop may call.
void gpu_collect_contained(SymbolTable *scope, std::set<ASR::symbol_t*> &used) {
    for (auto &item : scope->get_scope()) {
        if (!ASR::is_a<ASR::Function_t>(*item.second)) continue;
        ASR::Function_t *f = ASR::down_cast<ASR::Function_t>(item.second);
        GpuVariableUses c(used);
        for (size_t i = 0; i < f->n_body; i++) c.visit_stmt(*f->m_body[i]);
        gpu_collect_contained(f->m_symtab, used);
    }
}

// --- Derived-type variables ----------------------------------------------

// The variable `e` is a chain of components of, and the names and the
// symbols of those components, outermost last, if it is one of `variables`.
ASR::symbol_t *gpu_component_chain(ASR::expr_t *e,
        const std::set<ASR::symbol_t*> &variables,
        std::vector<std::string> &path, std::vector<ASR::symbol_t*> &members) {
    path.clear();
    members.clear();
    while (ASR::is_a<ASR::StructInstanceMember_t>(*e)) {
        ASR::StructInstanceMember_t *m =
            ASR::down_cast<ASR::StructInstanceMember_t>(e);
        path.push_back(ASRUtils::symbol_name(
            ASRUtils::symbol_get_past_external(m->m_m)));
        members.push_back(m->m_m);
        e = m->m_v;
    }
    if (!ASR::is_a<ASR::Var_t>(*e)) return nullptr;
    ASR::symbol_t *v = ASRUtils::symbol_get_past_external(
        ASR::down_cast<ASR::Var_t>(e)->m_v);
    if (!variables.count(v)) return nullptr;
    std::reverse(path.begin(), path.end());
    std::reverse(members.begin(), members.end());
    return v;
}

std::string gpu_designator_text(ASR::symbol_t *v,
        const std::vector<std::string> &path) {
    std::string text = ASRUtils::symbol_name(v);
    for (auto &c : path) text += "%" + c;
    return text;
}

bool gpu_struct_has_array_component(ASR::symbol_t *struct_sym) {
    ASR::Struct_t *st = gpu_struct_definition(struct_sym);
    if (!st) return true;
    if (st->m_parent && gpu_struct_has_array_component(st->m_parent)) {
        return true;
    }
    for (size_t i = 0; i < st->n_members; i++) {
        ASR::symbol_t *member = st->m_symtab->get_symbol(st->m_members[i]);
        if (!member || !ASR::is_a<ASR::Variable_t>(*member)) continue;
        ASR::ttype_t *t = ASRUtils::symbol_type(member);
        if (ASRUtils::is_array(t)) return true;
        if (ASR::is_a<ASR::StructType_t>(*ASRUtils::extract_type(t)) &&
                gpu_struct_has_array_component(
                    ASR::down_cast<ASR::Variable_t>(member)
                        ->m_type_declaration)) {
            return true;
        }
    }
    return false;
}

// The number of bytes a value of a derived type takes, or a number larger
// than any limit when that is not known at compile time.
int64_t gpu_struct_bytes(ASR::symbol_t *struct_sym) {
    const int64_t unknown = int64_t(1) << 40;
    ASR::Struct_t *st = gpu_struct_definition(struct_sym);
    if (!st) return unknown;
    int64_t bytes = st->m_parent ? gpu_struct_bytes(st->m_parent) : 0;
    for (size_t i = 0; i < st->n_members; i++) {
        ASR::symbol_t *member = st->m_symtab->get_symbol(st->m_members[i]);
        if (!member || !ASR::is_a<ASR::Variable_t>(*member)) continue;
        ASR::ttype_t *t = ASRUtils::symbol_type(member);
        if (ASRUtils::is_allocatable_or_pointer(t)) return unknown;
        int64_t count = 1;
        ASR::dimension_t *dims = nullptr;
        size_t rank = ASRUtils::extract_dimensions_from_ttype(t, dims);
        for (size_t d = 0; d < rank; d++) {
            int64_t extent;
            if (dims[d].m_length == nullptr || !ASRUtils::extract_value(
                    ASRUtils::expr_value(dims[d].m_length), extent)) {
                return unknown;
            }
            count *= extent;
        }
        ASR::ttype_t *e = ASRUtils::extract_type(t);
        int64_t each;
        if (ASR::is_a<ASR::StructType_t>(*e)) {
            each = gpu_struct_bytes(ASR::down_cast<ASR::Variable_t>(
                member)->m_type_declaration);
        } else if (ASR::is_a<ASR::Integer_t>(*e) || ASR::is_a<ASR::Real_t>(*e)
                || ASR::is_a<ASR::Logical_t>(*e)
                || ASR::is_a<ASR::Complex_t>(*e)) {
            each = ASRUtils::extract_kind_from_ttype_t(e)
                * (ASR::is_a<ASR::Complex_t>(*e) ? 2 : 1);
        } else {
            return unknown;
        }
        bytes += count * each;
        if (bytes >= unknown) return unknown;
    }
    return bytes;
}

// A thread keeps a copy of a whole derived-type value only up to this
// size: the copy is a local of the thread and is read from the variable on
// entry.
constexpr int64_t gpu_private_struct_limit = 1024;

bool gpu_private_scalar_type(ASR::ttype_t *t) {
    return !ASRUtils::is_array(t) && !ASRUtils::is_allocatable_or_pointer(t)
        && (ASR::is_a<ASR::Integer_t>(*t) || ASR::is_a<ASR::Real_t>(*t)
            || ASR::is_a<ASR::Logical_t>(*t) || ASR::is_a<ASR::Complex_t>(*t));
}

// What a loop body does with derived-type variables: every part of one it
// names, and every part of one it defines.
class GpuStructParts
        : public ASRUtils::BlockBodyWalkVisitor<GpuStructParts> {
public:
    const std::set<ASR::symbol_t*> &variables;
    struct Use {
        ASR::symbol_t *variable;
        std::vector<std::string> path;
        std::vector<ASR::symbol_t*> members;
        ASR::ttype_t *type;
    };
    std::vector<Use> uses;
    struct Definition {
        ASR::symbol_t *variable;
        std::vector<std::string> path;
        // Whether a thread can keep a private copy of what is defined; a
        // part of an array is defined in place instead.
        enum class Kind { Private, InPlace, Unsupported } kind;
        Location loc;
    };
    std::vector<Definition> definitions;

    GpuStructParts(const std::set<ASR::symbol_t*> &v) : variables(v) {}

    void note_definition(ASR::expr_t *designator, const Location &loc,
            bool by_call) {
        while (ASR::is_a<ASR::ArrayPhysicalCast_t>(*designator)) {
            designator = ASR::down_cast<ASR::ArrayPhysicalCast_t>(
                designator)->m_arg;
        }
        // The chain of components of the variable the designator selects
        // from, under any element or section taken of it.
        ASR::expr_t *e = designator;
        bool part_of_array = false;
        std::vector<std::string> path;
        std::vector<ASR::symbol_t*> members;
        ASR::symbol_t *v = nullptr;
        while (true) {
            v = gpu_component_chain(e, variables, path, members);
            if (v != nullptr) break;
            if (ASR::is_a<ASR::StructInstanceMember_t>(*e)) {
                e = ASR::down_cast<ASR::StructInstanceMember_t>(e)->m_v;
            } else if (ASR::is_a<ASR::ArrayItem_t>(*e)) {
                part_of_array = true;
                e = ASR::down_cast<ASR::ArrayItem_t>(e)->m_v;
            } else if (ASR::is_a<ASR::ArraySection_t>(*e)) {
                part_of_array = true;
                e = ASR::down_cast<ASR::ArraySection_t>(e)->m_v;
            } else {
                return;
            }
        }
        using Kind = Definition::Kind;
        Kind kind;
        ASR::ttype_t *t = ASRUtils::expr_type(e);
        if (part_of_array || ASRUtils::is_array(t) || ASRUtils::is_pointer(t)) {
            // An element or section of an array, or what a pointer points
            // to, is not stored in the variable as a scalar is.
            kind = Kind::InPlace;
        } else if (ASRUtils::is_allocatable(t)) {
            kind = Kind::Unsupported;
        } else if (ASR::is_a<ASR::StructType_t>(*t)) {
            // A procedure may define any part of it; what changed is told
            // by comparing its scalars, not its arrays.
            kind = ASRUtils::is_class_type(t) || (by_call &&
                    gpu_struct_has_array_component(
                        ASRUtils::get_struct_sym_from_struct_expr(e)))
                ? Kind::Unsupported : Kind::Private;
        } else {
            kind = gpu_private_scalar_type(t) ? Kind::Private
                : Kind::Unsupported;
        }
        definitions.push_back({v, path, kind, loc});
        uses.push_back({v, path, members, t});
    }

    void visit_Assignment(const ASR::Assignment_t &x) {
        note_definition(x.m_target, x.base.base.loc, false);
        ASR::BaseWalkVisitor<GpuStructParts>::visit_Assignment(x);
    }

    void visit_SubroutineCall(const ASR::SubroutineCall_t &x) {
        for (size_t i = 0; i < x.n_args; i++) {
            if (x.m_args[i].m_value && gpu_call_may_define(x, i)) {
                note_definition(x.m_args[i].m_value, x.base.base.loc, true);
            }
        }
        if (x.m_dt) note_definition(x.m_dt, x.base.base.loc, true);
        ASR::BaseWalkVisitor<GpuStructParts>::visit_SubroutineCall(x);
    }

    void visit_StructInstanceMember(const ASR::StructInstanceMember_t &x) {
        std::vector<std::string> path;
        std::vector<ASR::symbol_t*> members;
        ASR::expr_t *e = const_cast<ASR::expr_t*>(&x.base);
        if (ASR::symbol_t *v = gpu_component_chain(e, variables, path,
                members)) {
            uses.push_back({v, path, members, x.m_type});
            return;
        }
        ASR::BaseWalkVisitor<GpuStructParts>::visit_StructInstanceMember(x);
    }

    void visit_Var(const ASR::Var_t &x) {
        ASR::symbol_t *v = ASRUtils::symbol_get_past_external(x.m_v);
        if (variables.count(v)) {
            uses.push_back({v, {}, {}, ASRUtils::symbol_type(v)});
        }
    }
};

bool gpu_strict_prefix(const std::vector<std::string> &a,
        const std::vector<std::string> &b) {
    return a.size() < b.size() && std::equal(a.begin(), a.end(), b.begin());
}

// Replaces each part of a derived-type variable a thread keeps a private
// copy of with that copy.
class GpuPrivatePartReplacer
        : public ASR::BaseExprReplacer<GpuPrivatePartReplacer> {
public:
    Allocator &al;
    std::set<ASR::symbol_t*> variables;
    // (variable, path) -> the private copy.
    std::map<std::pair<ASR::symbol_t*, std::vector<std::string>>,
        ASR::symbol_t*> copies;

    GpuPrivatePartReplacer(Allocator &al_) : al(al_) {}

    bool replace_with_copy(ASR::expr_t *e) {
        std::vector<std::string> path;
        std::vector<ASR::symbol_t*> members;
        ASR::symbol_t *v = gpu_component_chain(e, variables, path, members);
        if (v == nullptr) return false;
        auto it = copies.find({v, path});
        if (it == copies.end()) return false;
        *current_expr = ASRUtils::EXPR(ASR::make_Var_t(al, e->base.loc,
            it->second));
        return true;
    }

    void replace_StructInstanceMember(ASR::StructInstanceMember_t *x) {
        if (replace_with_copy(&x->base)) return;
        ASR::BaseExprReplacer<GpuPrivatePartReplacer>::
            replace_StructInstanceMember(x);
    }

    void replace_Var(ASR::Var_t *x) {
        replace_with_copy(&x->base);
    }
};

class GpuPrivatePartVisitor : public ASR::CallReplacerOnExpressionsVisitor<
        GpuPrivatePartVisitor> {
public:
    GpuPrivatePartReplacer replacer;
    GpuPrivatePartVisitor(Allocator &al) : replacer(al) {}
    void call_replacer() {
        replacer.current_expr = current_expr;
        replacer.replace_expr(*current_expr);
    }
};

// --- Putting a private copy back -----------------------------------------

// Where the base of a designator is: the operand a component, an element
// or a section is taken from.
ASR::expr_t **gpu_designator_base_slot(ASR::expr_t *e) {
    if (ASR::is_a<ASR::StructInstanceMember_t>(*e)) {
        return &ASR::down_cast<ASR::StructInstanceMember_t>(e)->m_v;
    } else if (ASR::is_a<ASR::ArrayItem_t>(*e)) {
        return &ASR::down_cast<ASR::ArrayItem_t>(e)->m_v;
    } else if (ASR::is_a<ASR::ArraySection_t>(*e)) {
        return &ASR::down_cast<ASR::ArraySection_t>(e)->m_v;
    }
    return nullptr;
}

// An actual argument as the designator it is, past the change of
// descriptor it may be passed through.
ASR::expr_t *gpu_actual_designator(ASR::expr_t *e) {
    while (ASR::is_a<ASR::ArrayPhysicalCast_t>(*e)) {
        e = ASR::down_cast<ASR::ArrayPhysicalCast_t>(e)->m_arg;
    }
    return e;
}

// `a /= b`, for two scalars of one intrinsic type.
ASR::expr_t *gpu_differs(Allocator &al, const Location &loc, ASR::expr_t *a,
        ASR::expr_t *b) {
    ASR::ttype_t *t = ASRUtils::type_get_past_allocatable_pointer(
        ASRUtils::expr_type(a));
    if (ASR::is_a<ASR::Complex_t>(*t)) {
        return ASRUtils::EXPR(ASR::make_ComplexCompare_t(al, loc, a,
            ASR::cmpopType::NotEq, b,
            ASRUtils::TYPE(ASR::make_Logical_t(al, loc, 4)), nullptr));
    }
    return ASRUtils::ASRBuilder(al, loc).NotEq(a, b);
}

// The scalar parts of `designator`: itself when it is a scalar of an
// intrinsic type, else each scalar component, or component of one.
void gpu_scalar_parts(Allocator &al, ASR::expr_t *designator,
        std::vector<ASR::expr_t*> &parts) {
    ASR::ttype_t *t = ASRUtils::expr_type(designator);
    if (!ASR::is_a<ASR::StructType_t>(*t)) {
        parts.push_back(designator);
        return;
    }
    ASR::symbol_t *struct_sym = ASRUtils::symbol_get_past_external(
        ASRUtils::get_struct_sym_from_struct_expr(designator));
    std::vector<ASR::Struct_t*> types;
    for (ASR::Struct_t *st = gpu_struct_definition(struct_sym); st;
            st = st->m_parent ? gpu_struct_definition(st->m_parent)
                : nullptr) {
        types.push_back(st);
    }
    for (ASR::Struct_t *st : types) {
        for (size_t i = 0; i < st->n_members; i++) {
            ASR::symbol_t *member = st->m_symtab->get_symbol(
                st->m_members[i]);
            if (!member || !ASR::is_a<ASR::Variable_t>(*member)) continue;
            ASRUtils::ExprStmtDuplicator dup(al);
            gpu_scalar_parts(al, ASRUtils::EXPR(
                ASR::make_StructInstanceMember_t(al, designator->base.loc,
                    dup.duplicate_expr(designator), member,
                    ASRUtils::duplicate_type(al, ASRUtils::symbol_type(
                        member)), nullptr)), parts);
        }
    }
}

// Whether a statement can be left before its end other than by finishing
// it: by a CYCLE or EXIT of a loop around it, a RETURN, a GO TO or a STOP.
class GpuEarlyExitFinder
        : public ASRUtils::BlockBodyWalkVisitor<GpuEarlyExitFinder> {
public:
    bool found = false;
    int loops = 0;
    void visit_Cycle(const ASR::Cycle_t &x) {
        if (loops == 0 || x.m_stmt_name) found = true;
    }
    void visit_Exit(const ASR::Exit_t &x) {
        if (loops == 0 || x.m_stmt_name) found = true;
    }
    void visit_Return(const ASR::Return_t &) { found = true; }
    void visit_GoTo(const ASR::GoTo_t &) { found = true; }
    void visit_Stop(const ASR::Stop_t &) { found = true; }
    void visit_ErrorStop(const ASR::ErrorStop_t &) { found = true; }
    void visit_DoLoop(const ASR::DoLoop_t &x) {
        loops++;
        ASR::BaseWalkVisitor<GpuEarlyExitFinder>::visit_DoLoop(x);
        loops--;
    }
    void visit_WhileLoop(const ASR::WhileLoop_t &x) {
        loops++;
        ASR::BaseWalkVisitor<GpuEarlyExitFinder>::visit_WhileLoop(x);
        loops--;
    }
    void visit_DoConcurrentLoop(const ASR::DoConcurrentLoop_t &x) {
        loops++;
        ASR::BaseWalkVisitor<GpuEarlyExitFinder>::visit_DoConcurrentLoop(x);
        loops--;
    }
};

// Puts the value of the private copy each thread of a kernel keeps of a
// variable whose value is kept after the loop back where it is shared,
// after the statements that define the copy or a part of it: only the
// part an assignment or the actual argument of a call defines is put
// back, so that what other iterations define of the variable is left
// alone, and after a call only the scalars it changed. `entries` are the
// assignments that give each copy its value on entry, from where the value
// is shared, which is where it is put back.
//
// A definition of a scalar copy in a loop of a statement of the kernel body
// would put the value back on every trip; it sets the copy's flag instead,
// and the value is put back once, after that statement, if the flag is
// set. That is not done in a statement that can be left early (see
// GpuEarlyExitFinder), which could skip the write after it.
class GpuLiveoutWriteBack : public PassUtils::PassVisitor<GpuLiveoutWriteBack> {
public:
    std::set<ASR::stmt_t*> entries;

    GpuLiveoutWriteBack(Allocator &al_)
            : PassUtils::PassVisitor<GpuLiveoutWriteBack>(al_, nullptr) {
        pass_result.reserve(al, 4);
    }

    void run(ASR::Function_t &kernel) {
        kernel_scope = kernel.m_symtab;
        Vec<ASR::stmt_t*> body;
        body.reserve(al, kernel.n_body);
        for (size_t i = 0; i < kernel.n_body; i++) {
            ASR::stmt_t *s = kernel.m_body[i];
            GpuEarlyExitFinder exits;
            exits.visit_stmt(*s);
            deferring = !exits.found;
            loops = 0;
            deferred.clear();
            pass_result.n = 0;
            visit_stmt(*s);
            std::vector<ASR::stmt_t*> done;
            if (pass_result.size() > 0) {
                for (size_t j = 0; j < pass_result.size(); j++) {
                    done.push_back(pass_result[j]);
                }
                pass_result.n = 0;
            } else {
                done.push_back(s);
            }
            const Location &loc = s->base.loc;
            ASR::ttype_t *logical_type = ASRUtils::TYPE(
                ASR::make_Logical_t(al, loc, 4));
            // Each flag is cleared before the statement and tested after.
            for (ASR::symbol_t *copy : deferred) {
                body.push_back(al, ASRUtils::STMT(ASR::make_Assignment_t(al,
                    loc, ASRUtils::EXPR(ASR::make_Var_t(al, loc,
                        flags[copy])),
                    ASRUtils::EXPR(ASR::make_LogicalConstant_t(al, loc,
                        false, logical_type)), nullptr, false, false, false)));
            }
            for (ASR::stmt_t *d : done) body.push_back(al, d);
            for (ASR::symbol_t *copy : deferred) {
                Vec<ASR::stmt_t*> then;
                then.reserve(al, 1);
                then.push_back(al, put_back(loc, ASRUtils::EXPR(
                    ASR::make_Var_t(al, loc, copy)), copy));
                body.push_back(al, ASRUtils::STMT(ASR::make_If_t(al, loc,
                    nullptr, ASRUtils::EXPR(ASR::make_Var_t(al, loc,
                        flags[copy])), then.p, then.n, nullptr, 0)));
            }
        }
        kernel.m_body = body.p;
        kernel.n_body = body.size();
        // The BLOCKs and ASSOCIATEs of the kernel, whose statements are not
        // statements of the kernel body.
        deferring = false;
        for (auto &item : kernel.m_symtab->get_scope()) {
            if (ASR::is_a<ASR::Block_t>(*item.second)) {
                visit_Block(*ASR::down_cast<ASR::Block_t>(item.second));
            } else if (ASR::is_a<ASR::AssociateBlock_t>(*item.second)) {
                visit_AssociateBlock(
                    *ASR::down_cast<ASR::AssociateBlock_t>(item.second));
            }
        }
    }

    void visit_Assignment(const ASR::Assignment_t &x) {
        if (entries.count(const_cast<ASR::stmt_t*>(&x.base))) {
            if (ASR::is_a<ASR::Var_t>(*x.m_target)) {
                shared[ASR::down_cast<ASR::Var_t>(x.m_target)->m_v] =
                    x.m_value;
            }
            return;
        }
        ASR::symbol_t *copy = copy_of(x.m_target);
        if (copy == nullptr) return;
        std::vector<ASR::stmt_t*> after;
        define(x.base.base.loc, x.m_target, copy, after);
        pass_result.push_back(al, const_cast<ASR::stmt_t*>(&x.base));
        for (ASR::stmt_t *s : after) pass_result.push_back(al, s);
    }

    // A procedure may leave an actual argument as it was, so each scalar
    // of it is put back only when the call changed it.
    void visit_SubroutineCall(const ASR::SubroutineCall_t &x) {
        const Location &loc = x.base.base.loc;
        std::vector<ASR::stmt_t*> before, after;
        auto actual = [&](ASR::expr_t *a) {
            a = gpu_actual_designator(a);
            ASR::symbol_t *copy = copy_of(a);
            if (copy == nullptr) return;
            std::vector<ASR::expr_t*> parts;
            gpu_scalar_parts(al, a, parts);
            for (ASR::expr_t *part : parts) {
                ASRUtils::ExprStmtDuplicator dup(al);
                ASR::symbol_t *saved = gpu_new_variable(al, loc,
                    kernel_scope, kernel_scope->get_unique_name(
                        "__gpu_before"), ASRUtils::duplicate_type(al,
                        ASRUtils::expr_type(part)));
                ASR::expr_t *saved_var = ASRUtils::EXPR(ASR::make_Var_t(al,
                    loc, saved));
                before.push_back(ASRUtils::STMT(ASR::make_Assignment_t(al,
                    loc, saved_var, dup.duplicate_expr(part), nullptr,
                    false, false, false)));
                std::vector<ASR::stmt_t*> changed;
                define(loc, part, copy, changed);
                Vec<ASR::stmt_t*> then;
                then.reserve(al, changed.size());
                for (ASR::stmt_t *s : changed) then.push_back(al, s);
                after.push_back(ASRUtils::STMT(ASR::make_If_t(al, loc,
                    nullptr, gpu_differs(al, loc, dup.duplicate_expr(part),
                        ASRUtils::EXPR(ASR::make_Var_t(al, loc, saved))),
                    then.p, then.n, nullptr, 0)));
            }
        };
        for (size_t i = 0; i < x.n_args; i++) {
            if (x.m_args[i].m_value && gpu_call_may_define(x, i)) {
                actual(x.m_args[i].m_value);
            }
        }
        if (x.m_dt != nullptr) actual(x.m_dt);
        if (after.empty()) return;
        for (ASR::stmt_t *s : before) pass_result.push_back(al, s);
        pass_result.push_back(al, const_cast<ASR::stmt_t*>(&x.base));
        for (ASR::stmt_t *s : after) pass_result.push_back(al, s);
    }

    void visit_DoLoop(const ASR::DoLoop_t &x) {
        loops++;
        PassUtils::PassVisitor<GpuLiveoutWriteBack>::visit_DoLoop(x);
        loops--;
    }

    void visit_WhileLoop(const ASR::WhileLoop_t &x) {
        loops++;
        PassUtils::PassVisitor<GpuLiveoutWriteBack>::visit_WhileLoop(x);
        loops--;
    }

    void visit_DoConcurrentLoop(const ASR::DoConcurrentLoop_t &x) {
        loops++;
        PassUtils::PassVisitor<GpuLiveoutWriteBack>::visit_DoConcurrentLoop(x);
        loops--;
    }

private:
    // The private copy, and where its value is shared.
    std::map<ASR::symbol_t*, ASR::expr_t*> shared;
    SymbolTable *kernel_scope = nullptr;
    // Whether the statement of the kernel body being visited can have a
    // write put after it, and how many loops of it are around the one
    // visited.
    bool deferring = false;
    int loops = 0;
    // The flag of each copy, and the copies whose value is put back after
    // the statement of the kernel body being visited.
    std::map<ASR::symbol_t*, ASR::symbol_t*> flags;
    std::vector<ASR::symbol_t*> deferred;

    // The private copy `designator` is a part of, if it is one.
    ASR::symbol_t *copy_of(ASR::expr_t *designator) {
        ASR::expr_t *root = designator;
        while (ASR::expr_t **base = gpu_designator_base_slot(root)) {
            root = *base;
        }
        if (!ASR::is_a<ASR::Var_t>(*root)) return nullptr;
        ASR::symbol_t *copy = ASR::down_cast<ASR::Var_t>(root)->m_v;
        return shared.count(copy) ? copy : nullptr;
    }

    // `<the same part of the shared value> = designator`.
    ASR::stmt_t *put_back(const Location &loc, ASR::expr_t *designator,
            ASR::symbol_t *copy) {
        ASRUtils::ExprStmtDuplicator dup(al);
        ASR::expr_t *target = dup.duplicate_expr(designator);
        ASR::expr_t **at = &target;
        while (ASR::expr_t **base = gpu_designator_base_slot(*at)) at = base;
        *at = dup.duplicate_expr(shared[copy]);
        return ASRUtils::STMT(ASR::make_Assignment_t(al, loc, target,
            dup.duplicate_expr(designator), nullptr, false, false, false));
    }

    // Puts a definition of `designator` back, right away (into `after`),
    // or, for the whole of a scalar copy in a loop, after the statement of
    // the kernel body.
    void define(const Location &loc, ASR::expr_t *designator,
            ASR::symbol_t *copy, std::vector<ASR::stmt_t*> &after) {
        if (!deferring || loops == 0 || kernel_scope == nullptr
                || !ASR::is_a<ASR::Var_t>(*designator)
                || ASR::is_a<ASR::StructType_t>(*ASRUtils::expr_type(
                    designator))) {
            after.push_back(put_back(loc, designator, copy));
            return;
        }
        ASR::ttype_t *logical_type = ASRUtils::TYPE(
            ASR::make_Logical_t(al, loc, 4));
        if (!flags.count(copy)) {
            flags[copy] = gpu_new_variable(al, loc, kernel_scope,
                kernel_scope->get_unique_name("__gpu_defined"), logical_type);
        }
        if (std::find(deferred.begin(), deferred.end(), copy)
                == deferred.end()) {
            deferred.push_back(copy);
        }
        after.push_back(ASRUtils::STMT(ASR::make_Assignment_t(al, loc,
            ASRUtils::EXPR(ASR::make_Var_t(al, loc, flags[copy])),
            ASRUtils::EXPR(ASR::make_LogicalConstant_t(al, loc, true,
                logical_type)), nullptr, false, false, false)));
    }
};

// The kind of scalar a one-element buffer can carry back to the host, or
// what to call the one `type` is not.
std::string gpu_liveout_scalar_unsupported(ASR::ttype_t *type) {
    if (ASRUtils::is_allocatable(type)) return "allocatable";
    if (ASRUtils::is_pointer(type)) return "pointer";
    ASR::ttype_t *t = ASRUtils::type_get_past_allocatable_pointer(type);
    if (ASR::is_a<ASR::Integer_t>(*t) || ASR::is_a<ASR::Real_t>(*t)
            || ASR::is_a<ASR::Logical_t>(*t)) {
        return "";
    }
    if (ASR::is_a<ASR::Complex_t>(*t)) return gpu_scalar_type_name(t);
    if (ASR::is_a<ASR::String_t>(*t)) return "character";
    return "non-numeric";
}

bool gpu_struct_has_derived_component(ASR::symbol_t *struct_sym) {
    ASR::Struct_t *st = gpu_struct_definition(struct_sym);
    if (!st) return false;
    if (st->m_parent && gpu_struct_has_derived_component(st->m_parent)) {
        return true;
    }
    for (size_t i = 0; i < st->n_members; i++) {
        ASR::symbol_t *member = st->m_symtab->get_symbol(st->m_members[i]);
        if (!member || !ASR::is_a<ASR::Variable_t>(*member)) continue;
        if (ASR::is_a<ASR::StructType_t>(*ASRUtils::extract_type(
                ASRUtils::symbol_type(member)))) {
            return true;
        }
    }
    return false;
}

} // namespace

ASR::expr_t* gpu_liveout_slot(Allocator &al, const Location &loc,
        ASR::symbol_t *buffer, ASR::ttype_t *scalar_type) {
    ASR::array_index_t index;
    index.loc = loc;
    index.m_left = nullptr;
    index.m_right = ASRUtils::EXPR(ASR::make_IntegerConstant_t(al, loc, 1,
        ASRUtils::TYPE(ASR::make_Integer_t(al, loc, 4)),
        ASR::integerbozType::Decimal));
    index.m_step = nullptr;
    Vec<ASR::array_index_t> indices;
    indices.reserve(al, 1);
    indices.push_back(al, index);
    return ASRUtils::EXPR(ASR::make_ArrayItem_t(al, loc,
        ASRUtils::EXPR(ASR::make_Var_t(al, loc, buffer)), indices.p, 1,
        ASRUtils::duplicate_type(al, scalar_type),
        ASR::arraystorageType::ColMajor, nullptr, false));
}

std::set<ASR::symbol_t*> gpu_variables_referenced_after_loop(
        const ASR::OMPRegion_t &loop, SymbolTable *scope, bool &everything) {
    std::set<ASR::symbol_t*> used;
    everything = false;
    ASR::symbol_t *proc = gpu_procedure_of(scope);
    if (proc == nullptr) {
        everything = true;
        return used;
    }
    ASR::stmt_t **body;
    size_t n_body;
    if (ASR::is_a<ASR::Program_t>(*proc)) {
        ASR::Program_t *p = ASR::down_cast<ASR::Program_t>(proc);
        body = p->m_body;
        n_body = p->n_body;
    } else {
        ASR::Function_t *f = ASR::down_cast<ASR::Function_t>(proc);
        body = f->m_body;
        n_body = f->n_body;
    }
    GpuBackwardJumpFinder jumps(&loop);
    for (size_t i = 0; i < n_body; i++) jumps.visit_stmt(*body[i]);
    if (jumps.found) {
        everything = true;
        return used;
    }
    [[maybe_unused]] bool found = gpu_collect_after_loop(body, n_body, loop,
        used);
    LCOMPILERS_ASSERT(found);
    gpu_collect_contained(ASRUtils::symbol_symtab(proc), used);
    GpuAddressTaken address(used);
    for (size_t i = 0; i < n_body; i++) address.visit_stmt(*body[i]);
    return used;
}

bool gpu_visible_outside_procedure(ASR::symbol_t *sym, SymbolTable *scope) {
    if (sym == nullptr) return false;
    if (ASR::is_a<ASR::ExternalSymbol_t>(*sym)) return true;
    if (!ASR::is_a<ASR::Variable_t>(*sym)) return false;
    ASR::Variable_t *v = ASR::down_cast<ASR::Variable_t>(sym);
    if (v->m_intent != ASR::intentType::Local) return true;
    if (v->m_target_attr || v->m_is_volatile || v->m_common_block
            || ASRUtils::is_pointer(v->m_type)) {
        return true;
    }
    ASR::symbol_t *proc = gpu_procedure_of(scope);
    if (proc == nullptr) return true;
    if (v->m_storage == ASR::storage_typeType::Save
            && ASR::is_a<ASR::Function_t>(*proc)) {
        return true;
    }
    SymbolTable *proc_scope = ASRUtils::symbol_symtab(proc);
    for (SymbolTable *t = v->m_parent_symtab; t != proc_scope;
            t = t->parent) {
        if (t == nullptr || t->asr_owner == nullptr
                || t->asr_owner->type != ASR::asrType::symbol) {
            return true;
        }
        ASR::symbol_t *owner = ASR::down_cast<ASR::symbol_t>(t->asr_owner);
        if (!ASR::is_a<ASR::Block_t>(*owner)
                && !ASR::is_a<ASR::AssociateBlock_t>(*owner)) {
            return true;
        }
    }
    return false;
}

bool gpu_no_kernel_local_struct(SymbolTable *scope,
        const std::string &name, ASR::ttype_t *type) {
    if (ASRUtils::is_array(type) || ASRUtils::is_class_type(type)
            || ASRUtils::is_allocatable_or_pointer(type)
            || !ASR::is_a<ASR::StructType_t>(*ASRUtils::extract_type(type))) {
        return false;
    }
    ASR::symbol_t *sym = scope->resolve_symbol(name);
    if (sym == nullptr) return false;
    sym = ASRUtils::symbol_get_past_external(sym);
    if (!ASR::is_a<ASR::Variable_t>(*sym)) return false;
    ASR::symbol_t *struct_sym =
        ASR::down_cast<ASR::Variable_t>(sym)->m_type_declaration;
    return gpu_struct_has_allocatable_parts(struct_sym)
        && gpu_struct_has_derived_component(struct_sym);
}

bool GpuOffloadVisitor::plan_liveouts(const Location &loc,
        ASR::stmt_t **body, size_t n_body,
        const std::set<std::string> &assigned_vars,
        const std::set<std::string> &loop_var_set,
        const std::set<std::string> &reduction_names,
        std::set<std::string> &local_scalar_names,
        std::map<std::string, std::pair<ASR::ttype_t*, ASR::expr_t*>>
            &involved_syms,
        GpuLiveoutPlan &plan) {
    // Every question that can stop the offload is asked before anything
    // is created.
    std::vector<std::string> scalars;
    std::set<ASR::symbol_t*> structs;
    std::map<ASR::symbol_t*, ASR::symbol_t*> named;
    for (auto &name : assigned_vars) {
        if (loop_var_set.count(name)) continue;
        if (local_scalar_names.count(name)) continue;
        // A reduction accumulator is written by every thread. One shared
        // slot would be a race, so it gets a slot per thread instead.
        if (reduction_names.count(name)) continue;
        auto it = involved_syms.find(name);
        if (it == involved_syms.end()) continue;
        ASR::ttype_t *type = it->second.first;
        if (ASRUtils::is_array(type)) continue;
        if (ASR::is_a<ASR::StructType_t>(*ASRUtils::extract_type(type))) {
            ASR::symbol_t *sym = current_scope->resolve_symbol(name);
            if (sym == nullptr) continue;
            ASR::symbol_t *v = ASRUtils::symbol_get_past_external(sym);
            if (!ASR::is_a<ASR::Variable_t>(*v)) continue;
            structs.insert(v);
            named[v] = sym;
            continue;
        }
        std::string unsupported = gpu_liveout_scalar_unsupported(type);
        if (!unsupported.empty()) {
            GpuDecline decline(GpuDeclineReason::LiveoutScalar, name);
            decline.type_name = unsupported;
            report_not_offloaded(loc, decline);
            return false;
        }
        scalars.push_back(name);
    }

    // The parts of each derived-type variable a thread keeps a copy of:
    // each scalar it defines, or the part around it the loop also names,
    // which a copy of the scalar alone would leave stale.
    std::vector<GpuLiveoutPlan::Copy> copies;
    if (!structs.empty()) {
        GpuStructParts parts(structs);
        for (size_t i = 0; i < n_body; i++) parts.visit_stmt(*body[i]);
        using Kind = GpuStructParts::Definition::Kind;
        for (ASR::symbol_t *v : structs) {
            std::set<std::vector<std::string>> privatized;
            Location first = loc;
            bool any = false;
            for (auto &d : parts.definitions) {
                if (d.variable != v) continue;
                if (d.kind == Kind::Unsupported) {
                    report_not_offloaded(d.loc, GpuDecline(
                        GpuDeclineReason::LiveoutDerivedType,
                        gpu_designator_text(v, d.path)));
                    return false;
                }
                if (d.kind != Kind::Private) continue;
                if (!any) first = d.loc;
                any = true;
                privatized.insert(d.path);
            }
            bool changed = true;
            while (changed) {
                changed = false;
                for (auto &u : parts.uses) {
                    if (u.variable != v) continue;
                    for (auto &p : privatized) {
                        if (gpu_strict_prefix(u.path, p)) {
                            privatized.erase(p);
                            privatized.insert(u.path);
                            changed = true;
                            break;
                        }
                    }
                    if (changed) break;
                }
            }
            if (privatized.empty()) continue;
            ASR::Variable_t *var = ASR::down_cast<ASR::Variable_t>(v);
            if (ASRUtils::is_class_type(var->m_type)
                    || ASRUtils::is_allocatable_or_pointer(var->m_type)) {
                report_not_offloaded(first, GpuDecline(
                    GpuDeclineReason::LiveoutDerivedType,
                    ASRUtils::symbol_name(v)));
                return false;
            }
            for (auto &p : privatized) {
                // What the path selects, as the loop names it.
                const GpuStructParts::Use *use = nullptr;
                for (auto &u : parts.uses) {
                    if (u.variable == v && u.path == p) {
                        use = &u;
                        break;
                    }
                }
                LCOMPILERS_ASSERT(use != nullptr);
                ASR::ttype_t *t = use->type;
                if (ASR::is_a<ASR::StructType_t>(*t)) {
                    ASR::symbol_t *struct_sym = p.empty()
                        ? var->m_type_declaration
                        : ASR::down_cast<ASR::Variable_t>(
                            ASRUtils::symbol_get_past_external(
                                use->members.back()))->m_type_declaration;
                    // A part of a derived-type component would need its
                    // type in the kernel; its copy is not made yet.
                    if (!p.empty() || ASRUtils::is_class_type(t)
                            || gpu_struct_has_allocatable_parts(struct_sym)
                            || gpu_struct_bytes(struct_sym)
                                > gpu_private_struct_limit) {
                        report_not_offloaded(first, GpuDecline(
                            GpuDeclineReason::LiveoutDerivedType,
                            gpu_designator_text(v, p)));
                        return false;
                    }
                } else if (!gpu_private_scalar_type(t)) {
                    report_not_offloaded(first, GpuDecline(
                        GpuDeclineReason::LiveoutDerivedType,
                        gpu_designator_text(v, p)));
                    return false;
                }
                std::string copy = "__gpu_private_"
                    + std::string(ASRUtils::symbol_name(v));
                for (auto &c : p) copy += "_" + c;
                copies.push_back({v, named[v], p, use->members, t, copy});
            }
        }
    }

    // The kernel takes the buffer, and the private copy is a local of it
    // under the scalar's own name, which the body names.
    ASR::ttype_t *int4_type = ASRUtils::TYPE(ASR::make_Integer_t(al, loc, 4));
    for (auto &name : scalars) {
        auto it = involved_syms.find(name);
        ASR::ttype_t *scalar_type = it->second.first;
        ASR::dimension_t dim;
        dim.loc = loc;
        dim.m_start = ASRUtils::EXPR(ASR::make_IntegerConstant_t(al, loc, 1,
            int4_type, ASR::integerbozType::Decimal));
        dim.m_length = ASRUtils::EXPR(ASR::make_IntegerConstant_t(al, loc,
            1, int4_type, ASR::integerbozType::Decimal));
        Vec<ASR::dimension_t> dims;
        dims.reserve(al, 1);
        dims.push_back(al, dim);
        ASR::ttype_t *buffer_type = ASRUtils::TYPE(ASR::make_Array_t(al,
            loc, ASRUtils::duplicate_type(al, scalar_type), dims.p, 1,
            ASR::array_physical_typeType::FixedSizeArray,
            ASR::memory_spaceType::Global));
        std::string buf_name = current_scope->get_unique_name(
            "__gpu_buf_" + name);
        ASR::symbol_t *buf_sym = gpu_new_variable(al, loc, current_scope,
            buf_name, ASRUtils::duplicate_type(al, buffer_type));
        involved_syms.erase(it);
        involved_syms[buf_name] = {buffer_type,
            ASRUtils::EXPR(ASR::make_Var_t(al, loc, buf_sym))};
        plan.scalars.push_back({name, buf_name, buf_sym,
            current_scope->resolve_symbol(name), scalar_type});
    }
    plan.copies = copies;
    return true;
}

void GpuOffloadVisitor::declare_liveout_copies(const Location &loc,
        SymbolTable *kernel_scope, GpuLiveoutPlan &plan) {
    for (auto &ls : plan.scalars) {
        gpu_new_variable(al, loc, kernel_scope, ls.orig_name,
            ASRUtils::duplicate_type(al, ls.scalar_type));
    }
    for (auto &c : plan.copies) {
        ASR::symbol_t *type_decl = nullptr;
        if (c.path.empty()) {
            type_decl = import_struct_type(c.named, current_scope,
                kernel_scope, loc);
        }
        gpu_new_variable(al, loc, kernel_scope, c.copy,
            ASRUtils::duplicate_type(al, c.type), ASR::intentType::Local,
            type_decl);
    }
}

void GpuOffloadVisitor::privatize_liveout_block(SymbolTable *kernel_scope,
        ASR::stmt_t **body, size_t n_body, GpuLiveoutPlan &plan) {
    if (plan.copies.empty()) return;
    GpuPrivatePartVisitor replace(al);
    for (auto &c : plan.copies) {
        ASR::symbol_t *copy = kernel_scope->get_symbol(c.copy);
        replace.replacer.variables.insert(c.variable);
        replace.replacer.copies[{c.variable, c.path}] = copy;
        // The kernel argument, which a remapped body names instead.
        if (ASR::symbol_t *argument = kernel_scope->get_symbol(
                ASRUtils::symbol_name(c.named))) {
            replace.replacer.variables.insert(argument);
            replace.replacer.copies[{argument, c.path}] = copy;
        }
    }
    for (size_t i = 0; i < n_body; i++) {
        replace.visit_stmt(*body[i]);
    }
}

void GpuOffloadVisitor::privatize_liveout_body(const Location &loc,
        SymbolTable *kernel_scope, Vec<ASR::stmt_t*> &body,
        GpuLiveoutPlan &plan) {
    if (plan.copies.empty()) return;
    privatize_liveout_block(kernel_scope, body.p, body.n, plan);
    // Each copy starts as the part of the variable, read through the
    // host's symbols like the rest of the body, and remapped with it.
    Vec<ASR::stmt_t*> entered;
    entered.reserve(al, plan.copies.size() + body.n);
    for (auto &c : plan.copies) {
        ASR::expr_t *part = ASRUtils::EXPR(ASR::make_Var_t(al, loc,
            c.named));
        for (ASR::symbol_t *m : c.members) {
            part = ASRUtils::EXPR(ASR::make_StructInstanceMember_t(al, loc,
                part, m, ASRUtils::duplicate_type(al, ASRUtils::symbol_type(
                    ASRUtils::symbol_get_past_external(m))), nullptr));
        }
        ASR::stmt_t *entry = ASRUtils::STMT(ASR::make_Assignment_t(al, loc,
            ASRUtils::EXPR(ASR::make_Var_t(al, loc,
                kernel_scope->get_symbol(c.copy))),
            part, nullptr, false, false, false));
        plan.entries.insert(entry);
        entered.push_back(al, entry);
    }
    for (size_t i = 0; i < body.n; i++) entered.push_back(al, body.p[i]);
    body = entered;
}

void GpuOffloadVisitor::enter_liveouts(const Location &loc,
        SymbolTable *kernel_scope, Vec<ASR::stmt_t*> &kernel_body,
        GpuLiveoutPlan &plan) {
    for (auto &ls : plan.scalars) {
        ASR::stmt_t *entry = ASRUtils::STMT(ASR::make_Assignment_t(al, loc,
            ASRUtils::EXPR(ASR::make_Var_t(al, loc,
                kernel_scope->get_symbol(ls.orig_name))),
            gpu_liveout_slot(al, loc, kernel_scope->get_symbol(ls.buf_name),
                ls.scalar_type),
            nullptr, false, false, false));
        plan.entries.insert(entry);
        kernel_body.push_back(al, entry);
    }
}

void GpuOffloadVisitor::write_back_liveouts(ASR::Function_t &kernel,
        GpuLiveoutPlan &plan) {
    if (plan.entries.empty()) return;
    GpuLiveoutWriteBack write_back(al);
    write_back.entries = plan.entries;
    write_back.run(kernel);
}

} // namespace LCompilers
