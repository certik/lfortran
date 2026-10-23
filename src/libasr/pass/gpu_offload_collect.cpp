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

bool gpu_call_may_define(const ASR::SubroutineCall_t &x, size_t i) {
    // Which dummy argument a type-bound call associates an actual
    // argument with depends on the passed object; it is not worked out.
    if (x.m_dt != nullptr) return true;
    ASR::symbol_t *callee = ASRUtils::symbol_get_past_external(x.m_name);
    if (!ASR::is_a<ASR::Function_t>(*callee)) return true;
    ASR::Function_t *f = ASR::down_cast<ASR::Function_t>(callee);
    if (i >= f->n_args || !ASR::is_a<ASR::Var_t>(*f->m_args[i])) return true;
    ASR::symbol_t *dummy = ASRUtils::symbol_get_past_external(
        ASR::down_cast<ASR::Var_t>(f->m_args[i])->m_v);
    if (!ASR::is_a<ASR::Variable_t>(*dummy)) return true;
    ASR::Variable_t *v = ASR::down_cast<ASR::Variable_t>(dummy);
    return v->m_intent != ASR::intentType::In && !v->m_value_attr;
}

ASR::symbol_t *gpu_defined_variable(ASR::expr_t *e) {
    while (ASR::is_a<ASR::ArrayPhysicalCast_t>(*e)) {
        e = ASR::down_cast<ASR::ArrayPhysicalCast_t>(e)->m_arg;
    }
    // An allocatable or pointer array component handed over whole: what
    // is defined is its elements.
    if (!ASR::is_a<ASR::Var_t>(*e) && ASRUtils::is_array(
            ASRUtils::expr_type(e)) && ASRUtils::is_allocatable_or_pointer(
                ASRUtils::expr_type(e))) {
        return nullptr;
    }
    while (true) {
        ASR::expr_t *base = nullptr;
        if (ASR::is_a<ASR::Var_t>(*e)) {
            if (ASRUtils::is_array(ASRUtils::expr_type(e))) return nullptr;
            return ASR::down_cast<ASR::Var_t>(e)->m_v;
        } else if (ASR::is_a<ASR::StructInstanceMember_t>(*e)) {
            base = ASR::down_cast<ASR::StructInstanceMember_t>(e)->m_v;
        } else if (ASR::is_a<ASR::ArrayItem_t>(*e)) {
            base = ASR::down_cast<ASR::ArrayItem_t>(e)->m_v;
        } else if (ASR::is_a<ASR::ArraySection_t>(*e)) {
            base = ASR::down_cast<ASR::ArraySection_t>(e)->m_v;
        } else {
            return nullptr;
        }
        // A part of what an allocatable or a pointer designates is not
        // stored in the variable.
        if (!ASR::is_a<ASR::Var_t>(*base) &&
                ASRUtils::is_allocatable_or_pointer(
                    ASRUtils::expr_type(base))) {
            return nullptr;
        }
        if (ASR::is_a<ASR::Var_t>(*base) && ASRUtils::is_array(
                ASRUtils::expr_type(base))) {
            return nullptr;
        }
        e = base;
    }
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
