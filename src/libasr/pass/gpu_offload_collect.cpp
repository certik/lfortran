#include <deque>

#include <libasr/asr_utils.h>
#include <libasr/codegen/gpu_utils.h>
#include <libasr/pass/gpu_offload_collect.h>

namespace LCompilers {

bool expr_has_function_call(ASR::expr_t *expr) {
    if (!expr) return false;
    ContainsFunctionCall checker;
    checker.visit_expr(*expr);
    return checker.found;
}

bool gpu_is_array_function_result(ASR::expr_t *e) {
    if (!e) return false;
    e = ASRUtils::get_past_array_physical_cast(e);
    if (!ASR::is_a<ASR::FunctionCall_t>(*e)) return false;
    ASR::FunctionCall_t *fc = ASR::down_cast<ASR::FunctionCall_t>(e);
    if (ASRUtils::is_elemental(fc->m_name)) return false;
    if (!ASRUtils::is_array(fc->m_type)) return false;
    ASR::ttype_t *elem = ASRUtils::extract_type(fc->m_type);
    return ASR::is_a<ASR::Integer_t>(*elem) || ASR::is_a<ASR::Real_t>(*elem)
        || ASR::is_a<ASR::Complex_t>(*elem)
        || ASR::is_a<ASR::Logical_t>(*elem)
        || ASR::is_a<ASR::StructType_t>(*elem);
}

void gpu_check_host_expr_index_free(ASR::expr_t *host_expr,
        const std::set<std::string> &index_names, const std::string &what) {
    if (!host_expr || index_names.empty()) return;
    GpuVarNameCollector c;
    c.visit_expr(*host_expr);
    for (const std::string &n : c.names) {
        if (index_names.count(n)) {
            throw LCompilersException(
                "GPU offload: the host expression for " + what +
                " refers to the loop index '" + n + "', which has no "
                "value outside the loop");
        }
    }
}

bool is_single_assignment_binding(ASR::symbol_t *sym,
        ASR::stmt_t **body, size_t n_body) {
    AssignmentTargetCounter counter(sym);
    for (size_t i = 0; i < n_body; i++) {
        counter.visit_stmt(*body[i]);
    }
    return counter.count == 1;
}

std::vector<ASR::Function_t*> reachable_routines(ASR::stmt_t **body,
        size_t n_body, GpuProcedureImplementations &implementations) {
    std::vector<ASR::Function_t*> order;
    std::set<ASR::Function_t*> seen;
    std::deque<ASR::Function_t*> work;
    auto reach = [&](ASR::Function_t *fn) {
        fn = implementations.implementation(fn);
        if (seen.insert(fn).second) work.push_back(fn);
    };
    for (ASR::Function_t *fn : gpu_callees(body, n_body, false)) reach(fn);
    while (!work.empty()) {
        ASR::Function_t *fn = work.front();
        work.pop_front();
        order.push_back(fn);
        for (ASR::Function_t *callee : gpu_callees(fn->m_body,
                fn->n_body, false)) {
            reach(callee);
        }
    }
    return order;
}

namespace {

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

// Adds to `names` what may be referenced once `loop` has run, when one of
// `stmts` holds it, and says whether one does.
bool gpu_collect_after_loop(ASR::stmt_t **stmts, size_t n,
        const ASR::OMPRegion_t &loop, std::set<std::string> &names) {
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
                        names)
                    || gpu_collect_after_loop(x->m_orelse, x->n_orelse,
                        loop, names);
            } else if (ASR::is_a<ASR::BlockCall_t>(*s)) {
                ASR::symbol_t *m = ASRUtils::symbol_get_past_external(
                    ASR::down_cast<ASR::BlockCall_t>(s)->m_m);
                if (ASR::is_a<ASR::Block_t>(*m)) {
                    ASR::Block_t *b = ASR::down_cast<ASR::Block_t>(m);
                    inner = gpu_collect_after_loop(b->m_body, b->n_body,
                        loop, names);
                }
            } else if (ASR::is_a<ASR::AssociateBlockCall_t>(*s)) {
                ASR::symbol_t *m = ASRUtils::symbol_get_past_external(
                    ASR::down_cast<ASR::AssociateBlockCall_t>(s)->m_m);
                if (ASR::is_a<ASR::AssociateBlock_t>(*m)) {
                    ASR::AssociateBlock_t *b =
                        ASR::down_cast<ASR::AssociateBlock_t>(m);
                    inner = gpu_collect_after_loop(b->m_body, b->n_body,
                        loop, names);
                }
            }
            if (!inner) {
                PostLoopVarCollector c(names, &loop);
                c.visit_stmt(*s);
            }
        }
        PostLoopVarCollector c(names, &loop);
        for (size_t j = i + 1; j < n; j++) {
            c.visit_stmt(*stmts[j]);
        }
        return true;
    }
    return false;
}

} // namespace

std::set<std::string> gpu_names_referenced_after_loop(
        const ASR::OMPRegion_t &loop, SymbolTable *scope) {
    std::set<std::string> names;
    ASR::symbol_t *proc = gpu_procedure_of(scope);
    if (proc == nullptr) return names;
    if (ASR::is_a<ASR::Program_t>(*proc)) {
        ASR::Program_t *p = ASR::down_cast<ASR::Program_t>(proc);
        gpu_collect_after_loop(p->m_body, p->n_body, loop, names);
    } else {
        ASR::Function_t *f = ASR::down_cast<ASR::Function_t>(proc);
        gpu_collect_after_loop(f->m_body, f->n_body, loop, names);
    }
    return names;
}

bool gpu_visible_outside_procedure(ASR::symbol_t *sym, SymbolTable *scope) {
    if (sym == nullptr) return false;
    if (ASR::is_a<ASR::ExternalSymbol_t>(*sym)) return true;
    if (!ASR::is_a<ASR::Variable_t>(*sym)) return false;
    ASR::Variable_t *v = ASR::down_cast<ASR::Variable_t>(sym);
    if (v->m_intent != ASR::intentType::Local) return true;
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

std::set<ASR::Function_t*> gpu_parallel_loop_routines(Allocator &al,
        ASR::TranslationUnit_t &unit, const PassOptions &pass_options) {
    std::set<ASR::Function_t*> routines;
    GpuParallelRegionCollector regions;
    regions.visit_TranslationUnit(unit);
    GpuProcedureImplementations implementations(al, unit, pass_options);
    for (ASR::OMPRegion_t *r : regions.loops) {
        for (ASR::Function_t *fn : reachable_routines(r->m_body, r->n_body,
                implementations)) {
            routines.insert(fn);
        }
    }
    return routines;
}

} // namespace LCompilers
