#include <libasr/asr.h>
#include <libasr/asr_utils.h>
#include <libasr/pass/recursion_analysis.h>

#include <algorithm>
#include <map>
#include <set>
#include <vector>

/*
Which procedures can have more than one instance active at the same time.

Function::m_recursive says whether a procedure may have more than one
instance active at the same time. The frontend sets it from what the program
declares (RECURSIVE or NON_RECURSIVE, otherwise recursive unless elemental)
and a pass that creates a procedure makes it recursive unless it knows
better, so the flag can always be relied on. Under --fast this pass proves
procedures non-recursive and clears the flag for them; it never sets it. A
procedure that is not recursive needs one thunk per procedure value of an
internal procedure instead of a pool of them (nested_vars).

Without threads, a procedure can be active twice only if it lies on a cycle
of the call graph. The graph has a node for each procedure with a body in
this translation unit and one node, `unknown`, for code that is not visible
here:

* A call of a procedure with a body here is an edge to it.
* A call whose target is not known here is an edge to `unknown`: through a
  procedure variable or dummy procedure, a type-bound procedure (it can be
  overridden), an interface, or a procedure of a module loaded from a module
  file. Procedures of intrinsic modules call no user code, so a call of one
  is no edge.
* `unknown` has an edge to every procedure that code outside this analysis
  can call: external procedures, public module procedures and procedures of
  submodules, bind(c) procedures, specific procedures of generic interfaces
  and operators, procedures bound to a type (including final procedures),
  and procedures used as values (actual arguments, pointer targets,
  c_funloc).
* A procedure that works with derived types can call user code that does not
  appear as a call: final procedures, defined assignment of components and
  defined input/output. When the translation unit has any of those, such a
  procedure gets an edge to `unknown`.

A procedure is not recursive if it is alone in its strongly connected
component (Tarjan's algorithm), does not call itself and is not in the
component of `unknown`. Threads are a separate matter: nested_vars keeps the
full pool for a host that is not recursive under OpenMP.

A pass that runs after this one and adds a call between existing procedures
must keep the flag of the procedures it can make recursive.
*/

namespace LCompilers {

namespace {

ASR::symbol_t *scope_owner(SymbolTable *scope) {
    if (scope != nullptr && scope->asr_owner != nullptr &&
            ASR::is_a<ASR::symbol_t>(*scope->asr_owner)) {
        return ASR::down_cast<ASR::symbol_t>(scope->asr_owner);
    }
    return nullptr;
}

bool is_implementation(const ASR::Function_t &f) {
    return ASRUtils::get_FunctionType(f)->m_deftype ==
        ASR::deftypeType::Implementation;
}

// A module whose procedures are compiled elsewhere (or are intrinsic)
bool is_external_module(ASR::symbol_t *sym) {
    if (sym == nullptr || !ASR::is_a<ASR::Module_t>(*sym)) {
        return false;
    }
    ASR::Module_t *m = ASR::down_cast<ASR::Module_t>(sym);
    return m->m_loaded_from_mod || m->m_intrinsic;
}

// The module, program or translation unit a procedure belongs to
ASR::asr_t *unit_of(ASR::Function_t *f) {
    SymbolTable *scope = f->m_symtab->parent;
    while (scope != nullptr) {
        ASR::symbol_t *owner = scope_owner(scope);
        if (owner == nullptr) {
            return scope->asr_owner;
        }
        if (ASR::is_a<ASR::Module_t>(*owner) ||
                ASR::is_a<ASR::Program_t>(*owner)) {
            return (ASR::asr_t *) owner;
        }
        scope = scope->parent;
    }
    return nullptr;
}

bool is_in_intrinsic_module(ASR::Function_t *f) {
    ASR::asr_t *unit = unit_of(f);
    return unit != nullptr && ASR::is_a<ASR::symbol_t>(*unit) &&
        ASR::is_a<ASR::Module_t>(*ASR::down_cast<ASR::symbol_t>(unit)) &&
        ASR::down_cast<ASR::Module_t>(
            ASR::down_cast<ASR::symbol_t>(unit))->m_intrinsic;
}

bool is_derived_type(ASR::ttype_t *type) {
    if (type == nullptr) {
        return false;
    }
    type = ASRUtils::type_get_past_array(
        ASRUtils::type_get_past_allocatable_pointer(type));
    return ASR::is_a<ASR::StructType_t>(*type);
}

class CallGraph {
public:
    // Node 0 is `unknown`
    static constexpr size_t unknown = 0;
    std::vector<ASR::Function_t *> procedures {nullptr};
    std::map<const ASR::Function_t *, size_t> node;
    std::vector<std::set<size_t>> callees {{}};
    // Whether a procedure that works with derived types can call user code
    // that does not appear as a call
    bool implicit_calls = false;
    std::set<size_t> uses_derived_types;

    size_t add(ASR::Function_t *f) {
        auto it = node.find(f);
        if (it != node.end()) {
            return it->second;
        }
        size_t i = procedures.size();
        procedures.push_back(f);
        node[f] = i;
        callees.push_back({});
        return i;
    }

    // The node of a procedure with a body here, or `unknown`
    size_t find(const ASR::Function_t *f) const {
        auto it = node.find(f);
        return it == node.end() ? unknown : it->second;
    }

    // `unknown` can call `sym` if it is a procedure with a body here
    void enter(ASR::symbol_t *sym) {
        if (sym == nullptr) {
            return;
        }
        sym = ASRUtils::symbol_get_past_external(sym);
        if (ASR::is_a<ASR::Function_t>(*sym)) {
            size_t i = find(ASR::down_cast<ASR::Function_t>(sym));
            if (i != unknown) {
                callees[unknown].insert(i);
            }
        }
    }

    // The strongly connected component of each node (Tarjan's algorithm,
    // without recursion so that deep call chains do not exhaust the stack)
    std::vector<size_t> components() const {
        size_t n = procedures.size();
        const size_t unvisited = n;
        std::vector<size_t> index(n, unvisited), low(n, 0), component(n, 0);
        std::vector<bool> on_stack(n, false);
        std::vector<size_t> stack;
        size_t next_index = 0, next_component = 0;
        struct Frame {
            size_t v;
            std::set<size_t>::const_iterator next;
        };
        for (size_t root = 0; root < n; root++) {
            if (index[root] != unvisited) {
                continue;
            }
            std::vector<Frame> frames;
            auto open = [&](size_t v) {
                index[v] = low[v] = next_index++;
                stack.push_back(v);
                on_stack[v] = true;
                frames.push_back({v, callees[v].begin()});
            };
            open(root);
            while (!frames.empty()) {
                Frame &frame = frames.back();
                size_t v = frame.v;
                if (frame.next != callees[v].end()) {
                    size_t w = *frame.next;
                    ++frame.next;
                    if (index[w] == unvisited) {
                        open(w);
                    } else if (on_stack[w]) {
                        low[v] = std::min(low[v], index[w]);
                    }
                    continue;
                }
                if (low[v] == index[v]) {
                    size_t w;
                    do {
                        w = stack.back();
                        stack.pop_back();
                        on_stack[w] = false;
                        component[w] = next_component;
                    } while (w != v);
                    next_component++;
                }
                frames.pop_back();
                if (!frames.empty()) {
                    size_t parent = frames.back().v;
                    low[parent] = std::min(low[parent], low[v]);
                }
            }
        }
        return component;
    }
};

// The procedures with a body in this translation unit
class NodeCollector : public ASR::BaseWalkVisitor<NodeCollector> {
public:
    CallGraph &graph;

    NodeCollector(CallGraph &graph_) : graph(graph_) {}

    void visit_Module(const ASR::Module_t &x) {
        if (x.m_loaded_from_mod || x.m_intrinsic) {
            return;
        }
        ASR::BaseWalkVisitor<NodeCollector>::visit_Module(x);
    }

    void visit_Function(const ASR::Function_t &x) {
        if (is_implementation(x)) {
            graph.add(const_cast<ASR::Function_t *>(&x));
        }
        ASR::BaseWalkVisitor<NodeCollector>::visit_Function(x);
    }

    void visit_Template(const ASR::Template_t &/*x*/) {}
    void visit_Requirement(const ASR::Requirement_t &/*x*/) {}
};

// The procedures that code outside this analysis can call, and whether the
// translation unit has user code that can be called without a call
class EntryCollector : public ASR::BaseWalkVisitor<EntryCollector> {
public:
    CallGraph &graph;

    EntryCollector(CallGraph &graph_) : graph(graph_) {}

    void visit_Module(const ASR::Module_t &x) {
        if (x.m_loaded_from_mod || x.m_intrinsic) {
            return;
        }
        ASR::BaseWalkVisitor<EntryCollector>::visit_Module(x);
    }

    void visit_Function(const ASR::Function_t &x) {
        if (is_implementation(x)) {
            ASR::symbol_t *owner = scope_owner(x.m_symtab->parent);
            bool external = owner == nullptr;
            bool from_module = owner != nullptr &&
                ASR::is_a<ASR::Module_t>(*owner) &&
                (x.m_access == ASR::accessType::Public ||
                 ASR::down_cast<ASR::Module_t>(owner)->m_parent_module
                    != nullptr);
            bool bind_c = ASRUtils::get_FunctionType(x)->m_abi ==
                ASR::abiType::BindC;
            if (external || from_module || bind_c) {
                graph.enter((ASR::symbol_t *) &x);
            }
        }
        ASR::BaseWalkVisitor<EntryCollector>::visit_Function(x);
    }

    void visit_GenericProcedure(const ASR::GenericProcedure_t &x) {
        for (size_t i = 0; i < x.n_procs; i++) {
            graph.enter(x.m_procs[i]);
        }
    }

    void visit_CustomOperator(const ASR::CustomOperator_t &x) {
        graph.implicit_calls = true;
        for (size_t i = 0; i < x.n_procs; i++) {
            graph.enter(x.m_procs[i]);
        }
    }

    void visit_Struct(const ASR::Struct_t &x) {
        if (x.n_member_functions > 0) {
            graph.implicit_calls = true;
        }
        for (size_t i = 0; i < x.n_member_functions; i++) {
            graph.enter(x.m_symtab->parent->resolve_symbol(
                x.m_member_functions[i]));
        }
        for (auto &item: x.m_symtab->get_scope()) {
            ASR::symbol_t *sym = item.second;
            if (ASR::is_a<ASR::StructMethodDeclaration_t>(*sym)) {
                graph.enter(ASR::down_cast<ASR::StructMethodDeclaration_t>(
                    sym)->m_proc);
            } else if (ASR::is_a<ASR::GenericProcedure_t>(*sym)) {
                graph.implicit_calls = true;
            }
        }
        ASR::BaseWalkVisitor<EntryCollector>::visit_Struct(x);
    }

    void visit_dtio_binding(const ASR::dtio_binding_t &x) {
        graph.implicit_calls = true;
        graph.enter(x.m_procedure);
        graph.enter(x.m_callback);
    }

    // A procedure used as a value
    void visit_Var(const ASR::Var_t &x) {
        graph.enter(x.m_v);
    }

    void visit_Template(const ASR::Template_t &/*x*/) {}
    void visit_Requirement(const ASR::Requirement_t &/*x*/) {}
};

// The calls of one procedure, in its body and in its declarations, except
// those of its internal procedures, which are nodes of their own
class CallCollector : public ASR::BaseWalkVisitor<CallCollector> {
public:
    CallGraph &graph;
    const ASR::Function_t *procedure;
    size_t from;

    CallCollector(CallGraph &graph_, const ASR::Function_t *procedure_)
        : graph(graph_), procedure(procedure_),
          from(graph_.find(procedure_)) {}

    // A call of `name`, through the type-bound procedures of `dt` if given
    void call(ASR::symbol_t *name, ASR::expr_t *dt=nullptr) {
        if (dt != nullptr) {
            // It can be overridden
            graph.callees[from].insert(CallGraph::unknown);
        }
        ASR::symbol_t *target = ASRUtils::symbol_get_past_external(name);
        if (ASR::is_a<ASR::Function_t>(*target)) {
            ASR::Function_t *f = ASR::down_cast<ASR::Function_t>(target);
            if (is_in_intrinsic_module(f)) {
                return;
            }
            graph.callees[from].insert(graph.find(f));
            return;
        }
        // A procedure variable, a dummy procedure, a type-bound procedure
        graph.callees[from].insert(CallGraph::unknown);
    }

    void visit_Function(const ASR::Function_t &x) {
        if (&x != procedure) {
            return;
        }
        ASR::BaseWalkVisitor<CallCollector>::visit_Function(x);
    }

    void visit_FunctionCall(const ASR::FunctionCall_t &x) {
        call(x.m_name, x.m_dt);
        if (is_derived_type(x.m_type)) {
            graph.uses_derived_types.insert(from);
        }
        ASR::BaseWalkVisitor<CallCollector>::visit_FunctionCall(x);
    }

    void visit_SubroutineCall(const ASR::SubroutineCall_t &x) {
        call(x.m_name, x.m_dt);
        ASR::BaseWalkVisitor<CallCollector>::visit_SubroutineCall(x);
    }

    void visit_dtio_binding(const ASR::dtio_binding_t &x) {
        call(x.m_procedure);
        if (x.m_polymorphic || x.m_callback != nullptr) {
            graph.callees[from].insert(CallGraph::unknown);
        }
    }

    void visit_Variable(const ASR::Variable_t &x) {
        if (is_derived_type(x.m_type)) {
            graph.uses_derived_types.insert(from);
        }
        ASR::BaseWalkVisitor<CallCollector>::visit_Variable(x);
    }

    void visit_Var(const ASR::Var_t &x) {
        ASR::symbol_t *v = ASRUtils::symbol_get_past_external(x.m_v);
        if (ASR::is_a<ASR::Variable_t>(*v) && is_derived_type(
                ASR::down_cast<ASR::Variable_t>(v)->m_type)) {
            graph.uses_derived_types.insert(from);
        }
    }

    void visit_StructConstructor(const ASR::StructConstructor_t &x) {
        graph.uses_derived_types.insert(from);
        ASR::BaseWalkVisitor<CallCollector>::visit_StructConstructor(x);
    }
};

} // namespace

void pass_recursion_analysis(Allocator &/*al*/, ASR::TranslationUnit_t &unit,
        const PassOptions &pass_options) {
    if (!pass_options.fast) {
        return;
    }
    CallGraph graph;
    NodeCollector nodes(graph);
    nodes.visit_TranslationUnit(unit);
    EntryCollector entries(graph);
    entries.visit_TranslationUnit(unit);
    for (size_t i = 1; i < graph.procedures.size(); i++) {
        CallCollector calls(graph, graph.procedures[i]);
        calls.visit_Function(*graph.procedures[i]);
    }
    if (graph.implicit_calls) {
        for (size_t i: graph.uses_derived_types) {
            graph.callees[i].insert(CallGraph::unknown);
        }
    }
    std::vector<size_t> component = graph.components();
    std::vector<size_t> size(graph.procedures.size(), 0);
    for (size_t c: component) {
        size[c]++;
    }
    for (size_t i = 1; i < graph.procedures.size(); i++) {
        ASR::Function_t *f = graph.procedures[i];
        if (f->m_recursive &&
                component[i] != component[CallGraph::unknown] &&
                size[component[i]] == 1 &&
                graph.callees[i].count(i) == 0) {
            f->m_recursive = false;
        }
    }
}

} // namespace LCompilers
