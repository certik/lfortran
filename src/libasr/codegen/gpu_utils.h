#ifndef LFORTRAN_GPU_UTILS_H
#define LFORTRAN_GPU_UTILS_H

#include <libasr/asr.h>
#include <libasr/asr_utils.h>

#include <string>
#include <vector>

namespace LCompilers {

// Describes one dimension of a VLA workspace buffer.
struct GpuVlaDim {
    bool is_constant;
    int64_t constant_value;
    size_t call_arg_index;
    ASR::expr_t *dim_expr; // original ASR dimension expression
    // When true, size is read from a struct member's allocatable
    // array size, resolved at dispatch time from the struct array's
    // per-element sizes. struct_member_key is "arr_name.member_name".
    bool is_struct_member_size = false;
    std::string struct_member_key;
    // When true, size equals the dimension size of a kernel array
    // argument, resolved at dispatch time from the host-side array
    // descriptor.  source_array_name is the kernel param name,
    // source_dim_index is the 0-based dimension index.
    bool is_array_dim_size = false;
    std::string source_array_name;
    size_t source_dim_index = 0;
};

// Describes a VLA workspace buffer required by a GPU kernel.
struct GpuVlaWorkspace {
    std::string var_name;
    int buffer_index;
    int elem_size; // 0 means struct type, compute at codegen time
    ASR::ttype_t *elem_asr_type = nullptr; // set when elem_size == 0
    std::vector<GpuVlaDim> dims;
};

// Classify kernel arguments into buffer (array/struct) and scalar categories.
// Returns the count of buffer args and scalar args respectively.
// For struct array args with allocatable array members, counts 3 extra
// buffers per member (data, offsets, sizes) as emitted by Metal codegen.
inline std::pair<int, int> classify_gpu_kernel_args(
        const ASR::GpuKernelFunction_t &kernel) {
    int n_buffer = 0, n_scalar = 0;
    for (size_t i = 0; i < kernel.n_args; i++) {
        ASR::Var_t *v = ASR::down_cast<ASR::Var_t>(kernel.m_args[i]);
        ASR::Variable_t *var = ASR::down_cast<ASR::Variable_t>(
            ASRUtils::symbol_get_past_external(v->m_v));
        ASR::ttype_t *type = var->m_type;
        if (ASRUtils::is_array(type) ||
                ASR::is_a<ASR::StructType_t>(
                    *ASRUtils::extract_type(type))) {
            n_buffer++;
            if (ASRUtils::is_array(type) && var->m_type_declaration) {
                ASR::symbol_t *s = ASRUtils::symbol_get_past_external(
                    var->m_type_declaration);
                if (ASR::is_a<ASR::Struct_t>(*s)) {
                    ASR::Struct_t *st = ASR::down_cast<ASR::Struct_t>(s);
                    for (size_t m = 0; m < st->n_members; m++) {
                        ASR::symbol_t *mem =
                            st->m_symtab->get_symbol(st->m_members[m]);
                        if (!mem || !ASR::is_a<ASR::Variable_t>(*mem))
                            continue;
                        ASR::Variable_t *mv =
                            ASR::down_cast<ASR::Variable_t>(mem);
                        if (!ASRUtils::is_allocatable(mv->m_type))
                            continue;
                        ASR::ttype_t *inner =
                            ASRUtils::type_get_past_allocatable(
                                mv->m_type);
                        if (!ASR::is_a<ASR::Array_t>(*inner))
                            continue;
                        n_buffer += 3;
                    }
                }
            }
        } else {
            n_scalar++;
        }
    }
    return {n_buffer, n_scalar};
}

// Helper to recursively find the first Allocate statement for a given
// variable name within a statement list.
inline ASR::Allocate_t* find_allocate_for_var(
        ASR::stmt_t **stmts, size_t n, const std::string &var_name) {
    for (size_t i = 0; i < n; i++) {
        if (ASR::is_a<ASR::Allocate_t>(*stmts[i])) {
            ASR::Allocate_t *alloc =
                ASR::down_cast<ASR::Allocate_t>(stmts[i]);
            for (size_t ai = 0; ai < alloc->n_args; ai++) {
                if (!alloc->m_args[ai].m_a) continue;
                if (!ASR::is_a<ASR::Var_t>(*alloc->m_args[ai].m_a))
                    continue;
                std::string aname = ASRUtils::symbol_name(
                    ASR::down_cast<ASR::Var_t>(
                        alloc->m_args[ai].m_a)->m_v);
                if (aname == var_name) return alloc;
            }
        }
        if (ASR::is_a<ASR::WhileLoop_t>(*stmts[i])) {
            ASR::WhileLoop_t *wl =
                ASR::down_cast<ASR::WhileLoop_t>(stmts[i]);
            auto *r = find_allocate_for_var(wl->m_body, wl->n_body,
                var_name);
            if (r) return r;
        } else if (ASR::is_a<ASR::DoLoop_t>(*stmts[i])) {
            ASR::DoLoop_t *dl =
                ASR::down_cast<ASR::DoLoop_t>(stmts[i]);
            auto *r = find_allocate_for_var(dl->m_body, dl->n_body,
                var_name);
            if (r) return r;
        } else if (ASR::is_a<ASR::If_t>(*stmts[i])) {
            ASR::If_t *if_s =
                ASR::down_cast<ASR::If_t>(stmts[i]);
            auto *r = find_allocate_for_var(if_s->m_body, if_s->n_body,
                var_name);
            if (r) return r;
            r = find_allocate_for_var(if_s->m_orelse, if_s->n_orelse,
                var_name);
            if (r) return r;
        }
    }
    return nullptr;
}

// Try to evaluate an ASR integer expression as a compile-time constant.
inline bool try_eval_int_constant(ASR::expr_t *e, int64_t &val) {
    if (!e) return false;
    if (ASR::is_a<ASR::IntegerConstant_t>(*e)) {
        val = ASR::down_cast<ASR::IntegerConstant_t>(e)->m_n;
        return true;
    }
    ASR::expr_t *v = ASRUtils::expr_value(e);
    if (v && v != e) return try_eval_int_constant(v, val);
    if (ASR::is_a<ASR::Cast_t>(*e)) {
        return try_eval_int_constant(
            ASR::down_cast<ASR::Cast_t>(e)->m_arg, val);
    }
    if (ASR::is_a<ASR::IntegerBinOp_t>(*e)) {
        int64_t l, r;
        auto *op = ASR::down_cast<ASR::IntegerBinOp_t>(e);
        if (!try_eval_int_constant(op->m_left, l)) return false;
        if (!try_eval_int_constant(op->m_right, r)) return false;
        switch (op->m_op) {
            case ASR::binopType::Add: val = l + r; return true;
            case ASR::binopType::Sub: val = l - r; return true;
            case ASR::binopType::Mul: val = l * r; return true;
            case ASR::binopType::Div:
                if (r != 0) { val = l / r; return true; }
                return false;
            default: return false;
        }
    }
    if (ASR::is_a<ASR::IntegerCompare_t>(*e)) {
        int64_t l, r;
        auto *cmp = ASR::down_cast<ASR::IntegerCompare_t>(e);
        if (!try_eval_int_constant(cmp->m_left, l)) return false;
        if (!try_eval_int_constant(cmp->m_right, r)) return false;
        bool result;
        switch (cmp->m_op) {
            case ASR::cmpopType::Eq: result = (l == r); break;
            case ASR::cmpopType::NotEq: result = (l != r); break;
            case ASR::cmpopType::Lt: result = (l < r); break;
            case ASR::cmpopType::LtE: result = (l <= r); break;
            case ASR::cmpopType::Gt: result = (l > r); break;
            case ASR::cmpopType::GtE: result = (l >= r); break;
            default: return false;
        }
        val = result ? 1 : 0;
        return true;
    }
    if (ASR::is_a<ASR::IfExp_t>(*e)) {
        auto *ie = ASR::down_cast<ASR::IfExp_t>(e);
        int64_t cond;
        if (!try_eval_int_constant(ie->m_test, cond)) return false;
        return try_eval_int_constant(
            cond ? ie->m_body : ie->m_orelse, val);
    }
    return false;
}

// Forward declaration for mutual recursion with
// try_resolve_array_size_via_associate.
inline bool try_resolve_alloc_dim_constant(
        ASR::expr_t *dim,
        ASR::stmt_t **body, size_t n_body,
        int64_t &result);

// Try to resolve ArraySize(ptr_var, dim) to a constant by tracing an
// Associate statement back to an ArraySection with constant bounds.
// If no Associate is found, traces through Allocate statements to
// resolve transitively (e.g. ArraySize(temp_merge) → temp_merge is
// allocated with ArraySize(temp_compare) → temp_compare is associated
// with a constant-bounds ArraySection).
inline bool try_resolve_array_size_via_associate(
        ASR::ArraySize_t *as,
        ASR::stmt_t **body, size_t n_body,
        int64_t &result) {
    if (!as->m_v || !ASR::is_a<ASR::Var_t>(*as->m_v)) return false;
    std::string var_name = ASRUtils::symbol_name(
        ASR::down_cast<ASR::Var_t>(as->m_v)->m_v);
    int64_t target_dim = 1;
    if (as->m_dim) {
        if (!try_eval_int_constant(as->m_dim, target_dim)) return false;
    }
    for (size_t i = 0; i < n_body; i++) {
        if (!ASR::is_a<ASR::Associate_t>(*body[i])) continue;
        ASR::Associate_t *assoc =
            ASR::down_cast<ASR::Associate_t>(body[i]);
        if (!ASR::is_a<ASR::Var_t>(*assoc->m_target)) continue;
        std::string tname = ASRUtils::symbol_name(
            ASR::down_cast<ASR::Var_t>(assoc->m_target)->m_v);
        if (tname != var_name) continue;
        if (!ASR::is_a<ASR::ArraySection_t>(*assoc->m_value)) return false;
        ASR::ArraySection_t *sec =
            ASR::down_cast<ASR::ArraySection_t>(assoc->m_value);
        int range_dim = 0;
        for (size_t d = 0; d < sec->n_args; d++) {
            ASR::array_index_t &idx = sec->m_args[d];
            if (idx.m_left == nullptr) continue;
            range_dim++;
            if (range_dim == target_dim) {
                int64_t start_val, end_val, stride_val = 1;
                if (!try_eval_int_constant(idx.m_left, start_val))
                    return false;
                if (!try_eval_int_constant(idx.m_right, end_val))
                    return false;
                if (idx.m_step &&
                        !try_eval_int_constant(idx.m_step, stride_val))
                    return false;
                if (stride_val == 0) return false;
                result = (end_val - start_val) / stride_val + 1;
                if (result < 0) result = 0;
                return true;
            }
        }
        return false;
    }
    // No Associate found — try tracing through an Allocate statement
    // for the same variable.  If its allocation dimension for
    // `target_dim` is itself resolvable to a constant, use that.
    ASR::Allocate_t *alloc = find_allocate_for_var(
        body, n_body, var_name);
    if (alloc) {
        for (size_t ai = 0; ai < alloc->n_args; ai++) {
            if (!alloc->m_args[ai].m_a) continue;
            if (!ASR::is_a<ASR::Var_t>(*alloc->m_args[ai].m_a)) continue;
            std::string aname = ASRUtils::symbol_name(
                ASR::down_cast<ASR::Var_t>(
                    alloc->m_args[ai].m_a)->m_v);
            if (aname != var_name) continue;
            ASR::alloc_arg_t &targ = alloc->m_args[ai];
            if (target_dim < 1 ||
                    (size_t)target_dim > targ.n_dims)
                return false;
            ASR::expr_t *dim_expr =
                targ.m_dims[target_dim - 1].m_length;
            if (!dim_expr) return false;
            return try_resolve_alloc_dim_constant(
                dim_expr, body, n_body, result);
        }
    }
    return false;
}

// Try to resolve an Allocate dimension to a compile-time constant,
// including tracing ArraySize through Associate statements.
inline bool try_resolve_alloc_dim_constant(
        ASR::expr_t *dim,
        ASR::stmt_t **body, size_t n_body,
        int64_t &result) {
    if (try_eval_int_constant(dim, result)) return true;
    if (ASR::is_a<ASR::ArraySize_t>(*dim)) {
        return try_resolve_array_size_via_associate(
            ASR::down_cast<ASR::ArraySize_t>(dim), body, n_body, result);
    }
    return false;
}

// Try to find an ArrayBound expression inside a dimension length
// expression and resolve it to the "__dim_<arr>_<d>" kernel argument.
// The pattern is typically:
//   (ArrayBound(arr, d, UBound) - ArrayBound(arr, d, LBound)) / 1 + 1
// which simplifies to the dim size of `arr` along dimension d.
// Returns true if the dim expression depends on the dimensions of a
// kernel array argument, and populates arr_name/dim_index with the
// source array name and 0-based dimension index.
inline bool try_extract_array_bound_info(ASR::expr_t *expr,
        std::string &arr_name, size_t &dim_index) {
    if (!expr) return false;
    if (ASR::is_a<ASR::ArrayBound_t>(*expr)) {
        ASR::ArrayBound_t *ab =
            ASR::down_cast<ASR::ArrayBound_t>(expr);
        if (ab->m_v && ASR::is_a<ASR::Var_t>(*ab->m_v)) {
            arr_name = ASRUtils::symbol_name(
                ASR::down_cast<ASR::Var_t>(ab->m_v)->m_v);
            dim_index = 0;
            if (ab->m_dim &&
                    ASR::is_a<ASR::IntegerConstant_t>(*ab->m_dim)) {
                dim_index = ASR::down_cast<ASR::IntegerConstant_t>(
                    ab->m_dim)->m_n - 1;
            }
            return true;
        }
    }
    if (ASR::is_a<ASR::IntegerBinOp_t>(*expr)) {
        ASR::IntegerBinOp_t *op =
            ASR::down_cast<ASR::IntegerBinOp_t>(expr);
        if (try_extract_array_bound_info(op->m_left, arr_name,
                dim_index))
            return true;
        return try_extract_array_bound_info(op->m_right, arr_name,
            dim_index);
    }
    if (ASR::is_a<ASR::Cast_t>(*expr)) {
        return try_extract_array_bound_info(
            ASR::down_cast<ASR::Cast_t>(expr)->m_arg,
            arr_name, dim_index);
    }
    return false;
}

// Helper to extract a kernel argument reference from a complex Allocate
// dimension expression.
inline bool find_arg_var_in_expr(ASR::expr_t *expr,
        const std::vector<std::string> &arg_names,
        size_t &arg_index) {
    if (!expr) return false;
    if (ASR::is_a<ASR::Var_t>(*expr)) {
        std::string name = ASRUtils::symbol_name(
            ASR::down_cast<ASR::Var_t>(expr)->m_v);
        for (size_t a = 0; a < arg_names.size(); a++) {
            if (arg_names[a] == name) {
                arg_index = a;
                return true;
            }
        }
        return false;
    }
    if (ASR::is_a<ASR::IntegerBinOp_t>(*expr)) {
        ASR::IntegerBinOp_t *op =
            ASR::down_cast<ASR::IntegerBinOp_t>(expr);
        if (find_arg_var_in_expr(op->m_left, arg_names, arg_index))
            return true;
        return find_arg_var_in_expr(op->m_right, arg_names, arg_index);
    }
    if (ASR::is_a<ASR::IfExp_t>(*expr)) {
        ASR::IfExp_t *ie = ASR::down_cast<ASR::IfExp_t>(expr);
        if (find_arg_var_in_expr(ie->m_body, arg_names, arg_index))
            return true;
        return find_arg_var_in_expr(ie->m_orelse, arg_names, arg_index);
    }
    if (ASR::is_a<ASR::IntegerCompare_t>(*expr)) {
        ASR::IntegerCompare_t *cmp =
            ASR::down_cast<ASR::IntegerCompare_t>(expr);
        if (find_arg_var_in_expr(cmp->m_left, arg_names, arg_index))
            return true;
        return find_arg_var_in_expr(cmp->m_right, arg_names, arg_index);
    }
    if (ASR::is_a<ASR::Cast_t>(*expr)) {
        return find_arg_var_in_expr(
            ASR::down_cast<ASR::Cast_t>(expr)->m_arg,
            arg_names, arg_index);
    }
    return false;
}

// Try to resolve an ArraySize expression through Associate statements
// to find a kernel argument that determines the dimension size.
// Handles the pattern: ArraySize(temp, dim) where temp is associated
// with ArraySection(array_arg, [start:end:step, ...]).
// When start == 1 and step == 1, the section size equals end, and we
// look for a kernel arg reference in end.
inline bool try_resolve_array_size_to_arg_var(
        ASR::expr_t *dim_expr,
        ASR::stmt_t **body, size_t n_body,
        const std::vector<std::string> &arg_names,
        size_t &arg_index) {
    if (!ASR::is_a<ASR::ArraySize_t>(*dim_expr)) return false;
    ASR::ArraySize_t *as = ASR::down_cast<ASR::ArraySize_t>(dim_expr);
    if (!as->m_v || !ASR::is_a<ASR::Var_t>(*as->m_v)) return false;

    std::string var_name = ASRUtils::symbol_name(
        ASR::down_cast<ASR::Var_t>(as->m_v)->m_v);
    int64_t target_dim = 1;
    if (as->m_dim) {
        if (!try_eval_int_constant(as->m_dim, target_dim)) return false;
    }

    for (size_t i = 0; i < n_body; i++) {
        if (!ASR::is_a<ASR::Associate_t>(*body[i])) continue;
        ASR::Associate_t *assoc =
            ASR::down_cast<ASR::Associate_t>(body[i]);
        if (!ASR::is_a<ASR::Var_t>(*assoc->m_target)) continue;
        std::string tname = ASRUtils::symbol_name(
            ASR::down_cast<ASR::Var_t>(assoc->m_target)->m_v);
        if (tname != var_name) continue;
        if (!ASR::is_a<ASR::ArraySection_t>(*assoc->m_value))
            return false;
        ASR::ArraySection_t *sec =
            ASR::down_cast<ASR::ArraySection_t>(assoc->m_value);
        int range_dim = 0;
        for (size_t d = 0; d < sec->n_args; d++) {
            ASR::array_index_t &idx = sec->m_args[d];
            if (idx.m_left == nullptr) continue;
            range_dim++;
            if (range_dim == target_dim) {
                int64_t start_val = 0;
                bool start_is_one =
                    try_eval_int_constant(idx.m_left, start_val)
                    && start_val == 1;
                bool step_is_one = true;
                if (idx.m_step) {
                    int64_t sv;
                    step_is_one =
                        try_eval_int_constant(idx.m_step, sv) && sv == 1;
                }
                if (start_is_one && step_is_one && idx.m_right) {
                    return find_arg_var_in_expr(
                        idx.m_right, arg_names, arg_index);
                }
                // When the section spans a full dimension (e.g.
                // m(lbound(m,1):ubound(m,1):1, ...)), the size
                // equals the array's dimension size.  Look for the
                // __dim_<base>_<d> kernel arg directly.
                if (step_is_one && ASR::is_a<ASR::Var_t>(*sec->m_v)) {
                    std::string base_name = ASRUtils::symbol_name(
                        ASR::down_cast<ASR::Var_t>(sec->m_v)->m_v);
                    std::string dim_arg = "__dim_" + base_name
                        + "_" + std::to_string(d);
                    for (size_t a = 0; a < arg_names.size(); a++) {
                        if (arg_names[a] == dim_arg) {
                            arg_index = a;
                            return true;
                        }
                    }
                }
                return false;
            }
        }
        return false;
    }

    // No Associate found — try tracing through an Allocate whose
    // dimension is itself an ArraySize that can be resolved.
    ASR::Allocate_t *alloc = find_allocate_for_var(
        body, n_body, var_name);
    if (alloc) {
        for (size_t ai = 0; ai < alloc->n_args; ai++) {
            if (!alloc->m_args[ai].m_a) continue;
            if (!ASR::is_a<ASR::Var_t>(*alloc->m_args[ai].m_a))
                continue;
            std::string aname = ASRUtils::symbol_name(
                ASR::down_cast<ASR::Var_t>(
                    alloc->m_args[ai].m_a)->m_v);
            if (aname != var_name) continue;
            ASR::alloc_arg_t &targ = alloc->m_args[ai];
            if (target_dim < 1 || (size_t)target_dim > targ.n_dims)
                return false;
            ASR::expr_t *inner_dim =
                targ.m_dims[target_dim - 1].m_length;
            if (!inner_dim) return false;
            return try_resolve_array_size_to_arg_var(
                inner_dim, body, n_body, arg_names, arg_index);
        }
    }
    return false;
}

// Find the first struct array kernel arg that has an allocatable array
// member.  Returns "arr_name.member_name" or "" if none found.
inline std::string find_struct_alloc_member_key(
        const ASR::GpuKernelFunction_t &kernel) {
    for (size_t ai = 0; ai < kernel.n_args; ai++) {
        ASR::Var_t *av = ASR::down_cast<ASR::Var_t>(kernel.m_args[ai]);
        ASR::Variable_t *avar = ASR::down_cast<ASR::Variable_t>(
            ASRUtils::symbol_get_past_external(av->m_v));
        ASR::ttype_t *atype =
            ASRUtils::type_get_past_allocatable(avar->m_type);
        if (!ASR::is_a<ASR::Array_t>(*atype)) continue;
        ASR::Array_t *arr_t = ASR::down_cast<ASR::Array_t>(atype);
        if (!ASR::is_a<ASR::StructType_t>(*arr_t->m_type)) continue;
        if (!avar->m_type_declaration) continue;
        ASR::symbol_t *decl_sym = ASRUtils::symbol_get_past_external(
            avar->m_type_declaration);
        if (!ASR::is_a<ASR::Struct_t>(*decl_sym)) continue;
        ASR::Struct_t *stype = ASR::down_cast<ASR::Struct_t>(decl_sym);
        for (auto &mem : stype->m_symtab->get_scope()) {
            if (!ASR::is_a<ASR::Variable_t>(*mem.second)) continue;
            ASR::Variable_t *mv =
                ASR::down_cast<ASR::Variable_t>(mem.second);
            if (!ASRUtils::is_allocatable(mv->m_type)) continue;
            ASR::ttype_t *mt =
                ASRUtils::type_get_past_allocatable(mv->m_type);
            if (!ASR::is_a<ASR::Array_t>(*mt)) continue;
            return std::string(avar->m_name)
                + "." + std::string(mv->m_name);
        }
    }
    return "";
}

// Scan kernel-scope Allocatable(Array) variables for VLA workspaces.
inline void scan_kernel_scope_alloc_vlas(
        const ASR::GpuKernelFunction_t &kernel,
        const std::vector<std::string> &arg_names,
        int &buffer_idx,
        std::vector<GpuVlaWorkspace> &result) {
    // Build a set of kernel arg names for quick lookup
    std::set<std::string> arg_set(arg_names.begin(), arg_names.end());
    // Collect already-handled var names from result
    std::set<std::string> handled_names;
    for (auto &ws : result) handled_names.insert(ws.var_name);

    for (auto &item : kernel.m_symtab->get_scope()) {
        if (!ASR::is_a<ASR::Variable_t>(*item.second)) continue;
        ASR::Variable_t *var =
            ASR::down_cast<ASR::Variable_t>(item.second);
        if (!ASRUtils::is_allocatable(var->m_type)) continue;
        ASR::ttype_t *inner =
            ASRUtils::type_get_past_allocatable(var->m_type);
        if (!ASR::is_a<ASR::Array_t>(*inner)) continue;
        std::string vname(var->m_name);
        if (arg_set.count(vname)) continue;
        if (handled_names.count(vname)) continue;
        ASR::Allocate_t *alloc = find_allocate_for_var(
            kernel.m_body, kernel.n_body, vname);
        if (alloc) {
            // Has Allocate: existing logic
            ASR::alloc_arg_t *target_arg = nullptr;
            for (size_t ai = 0; ai < alloc->n_args; ai++) {
                if (!alloc->m_args[ai].m_a) continue;
                if (!ASR::is_a<ASR::Var_t>(*alloc->m_args[ai].m_a))
                    continue;
                std::string aname = ASRUtils::symbol_name(
                    ASR::down_cast<ASR::Var_t>(
                        alloc->m_args[ai].m_a)->m_v);
                if (aname == vname) {
                    target_arg = &alloc->m_args[ai];
                    break;
                }
            }
            if (!target_arg) continue;
            bool has_runtime_dim = false;
            for (size_t d = 0; d < target_arg->n_dims; d++) {
                ASR::dimension_t &dim = target_arg->m_dims[d];
                if (dim.m_length &&
                        !ASR::is_a<ASR::IntegerConstant_t>(
                            *dim.m_length)) {
                    has_runtime_dim = true;
                    break;
                }
            }
            if (!has_runtime_dim) continue;
            ASR::Array_t *arr = ASR::down_cast<ASR::Array_t>(inner);
            GpuVlaWorkspace ws;
            ws.var_name = vname;
            ws.buffer_index = buffer_idx++;
            if (ASR::is_a<ASR::Real_t>(*arr->m_type)) {
                ws.elem_size = ASR::down_cast<ASR::Real_t>(
                    arr->m_type)->m_kind;
            } else if (ASR::is_a<ASR::Integer_t>(*arr->m_type)) {
                ws.elem_size = ASR::down_cast<ASR::Integer_t>(
                    arr->m_type)->m_kind;
            } else {
                ws.elem_size = 4;
            }
            for (size_t d = 0; d < target_arg->n_dims; d++) {
                ASR::expr_t *dim = target_arg->m_dims[d].m_length;
                GpuVlaDim vd;
                vd.dim_expr = dim;
                if (dim && ASR::is_a<ASR::IntegerConstant_t>(*dim)) {
                    vd.is_constant = true;
                    vd.constant_value =
                        ASR::down_cast<ASR::IntegerConstant_t>(
                            dim)->m_n;
                    vd.call_arg_index = 0;
                } else if (dim) {
                    int64_t const_val;
                    if (try_resolve_alloc_dim_constant(
                            dim, kernel.m_body, kernel.n_body,
                            const_val)) {
                        vd.is_constant = true;
                        vd.constant_value = const_val;
                        vd.call_arg_index = 0;
                    } else {
                        vd.is_constant = false;
                        vd.constant_value = 0;
                        vd.call_arg_index = 0;
                        size_t idx = 0;
                        if (find_arg_var_in_expr(dim, arg_names, idx)) {
                            vd.call_arg_index = idx;
                        } else if (try_resolve_array_size_to_arg_var(
                                dim, kernel.m_body, kernel.n_body,
                                arg_names, idx)) {
                            vd.call_arg_index = idx;
                        }
                    }
                } else {
                    vd.is_constant = true;
                    vd.constant_value = 1;
                    vd.call_arg_index = 0;
                }
                ws.dims.push_back(vd);
            }
            result.push_back(std::move(ws));
        } else {
            // No Allocate: this is likely a function-call result temp
            // whose size depends on a struct member's allocatable array.
            // Find the first struct array kernel arg with an allocatable
            // array member to determine the size.
            std::string struct_key;
            for (size_t ai = 0; ai < kernel.n_args; ai++) {
                ASR::Var_t *av = ASR::down_cast<ASR::Var_t>(
                    kernel.m_args[ai]);
                ASR::Variable_t *avar =
                    ASR::down_cast<ASR::Variable_t>(
                        ASRUtils::symbol_get_past_external(
                            av->m_v));
                ASR::ttype_t *atype =
                    ASRUtils::type_get_past_allocatable(avar->m_type);
                if (!ASR::is_a<ASR::Array_t>(*atype)) continue;
                ASR::Array_t *arr_t =
                    ASR::down_cast<ASR::Array_t>(atype);
                if (!ASR::is_a<ASR::StructType_t>(*arr_t->m_type))
                    continue;
                if (!avar->m_type_declaration) continue;
                ASR::symbol_t *decl_sym =
                    ASRUtils::symbol_get_past_external(
                        avar->m_type_declaration);
                if (!ASR::is_a<ASR::Struct_t>(*decl_sym)) continue;
                ASR::Struct_t *stype =
                    ASR::down_cast<ASR::Struct_t>(decl_sym);
                for (auto &mem : stype->m_symtab->get_scope()) {
                    if (!ASR::is_a<ASR::Variable_t>(*mem.second))
                        continue;
                    ASR::Variable_t *mv =
                        ASR::down_cast<ASR::Variable_t>(mem.second);
                    if (!ASRUtils::is_allocatable(mv->m_type)) continue;
                    ASR::ttype_t *mt =
                        ASRUtils::type_get_past_allocatable(mv->m_type);
                    if (!ASR::is_a<ASR::Array_t>(*mt)) continue;
                    struct_key = std::string(avar->m_name)
                        + "." + std::string(mv->m_name);
                    break;
                }
                if (!struct_key.empty()) break;
            }
            if (struct_key.empty()) continue;
            ASR::Array_t *arr = ASR::down_cast<ASR::Array_t>(inner);
            GpuVlaWorkspace ws;
            ws.var_name = vname;
            ws.buffer_index = buffer_idx++;
            if (ASR::is_a<ASR::Real_t>(*arr->m_type)) {
                ws.elem_size = ASR::down_cast<ASR::Real_t>(
                    arr->m_type)->m_kind;
            } else if (ASR::is_a<ASR::Integer_t>(*arr->m_type)) {
                ws.elem_size = ASR::down_cast<ASR::Integer_t>(
                    arr->m_type)->m_kind;
            } else {
                ws.elem_size = 4;
            }
            GpuVlaDim vd;
            vd.dim_expr = nullptr;
            vd.is_constant = false;
            vd.constant_value = 0;
            vd.call_arg_index = 0;
            vd.is_struct_member_size = true;
            vd.struct_member_key = struct_key;
            ws.dims.push_back(vd);
            result.push_back(std::move(ws));
        }
    }
}

// Scan kernel-scope non-allocatable Array variables for VLA workspaces.
// These arise from pass-generated temporaries (e.g. subroutine_from_function)
// whose dimension length depends on runtime values like array bounds.
inline void scan_kernel_scope_nonalloc_vlas(
        const ASR::GpuKernelFunction_t &kernel,
        const std::vector<std::string> &arg_names,
        int &buffer_idx,
        std::vector<GpuVlaWorkspace> &result) {
    std::set<std::string> arg_set(arg_names.begin(), arg_names.end());
    std::set<std::string> handled_names;
    for (auto &ws : result) handled_names.insert(ws.var_name);

    for (auto &item : kernel.m_symtab->get_scope()) {
        if (!ASR::is_a<ASR::Variable_t>(*item.second)) continue;
        ASR::Variable_t *var =
            ASR::down_cast<ASR::Variable_t>(item.second);
        if (ASRUtils::is_allocatable(var->m_type)) continue;
        if (!ASR::is_a<ASR::Array_t>(*var->m_type)) continue;
        std::string vname(var->m_name);
        if (arg_set.count(vname)) continue;
        if (handled_names.count(vname)) continue;
        ASR::Array_t *arr = ASR::down_cast<ASR::Array_t>(var->m_type);
        bool has_runtime_dim = false;
        for (size_t d = 0; d < arr->n_dims; d++) {
            if (arr->m_dims[d].m_length &&
                    !ASR::is_a<ASR::IntegerConstant_t>(
                        *arr->m_dims[d].m_length)) {
                has_runtime_dim = true;
                break;
            }
        }
        if (!has_runtime_dim) continue;
        GpuVlaWorkspace ws;
        ws.var_name = vname;
        ws.buffer_index = buffer_idx++;
        if (ASR::is_a<ASR::Real_t>(*arr->m_type)) {
            ws.elem_size = ASR::down_cast<ASR::Real_t>(
                arr->m_type)->m_kind;
        } else if (ASR::is_a<ASR::Integer_t>(*arr->m_type)) {
            ws.elem_size = ASR::down_cast<ASR::Integer_t>(
                arr->m_type)->m_kind;
        } else if (ASR::is_a<ASR::StructType_t>(*arr->m_type)) {
            ws.elem_size = 0;
            ws.elem_asr_type = arr->m_type;
        } else {
            ws.elem_size = 4;
        }
        for (size_t d = 0; d < arr->n_dims; d++) {
            ASR::expr_t *dim = arr->m_dims[d].m_length;
            GpuVlaDim vd;
            vd.dim_expr = dim;
            if (dim && ASR::is_a<ASR::IntegerConstant_t>(*dim)) {
                vd.is_constant = true;
                vd.constant_value =
                    ASR::down_cast<ASR::IntegerConstant_t>(dim)->m_n;
                vd.call_arg_index = 0;
            } else if (dim) {
                int64_t const_val;
                if (try_eval_int_constant(dim, const_val)) {
                    vd.is_constant = true;
                    vd.constant_value = const_val;
                    vd.call_arg_index = 0;
                } else {
                    vd.is_constant = false;
                    vd.constant_value = 0;
                    vd.call_arg_index = 0;
                    std::string src_arr;
                    size_t src_dim;
                    if (try_extract_array_bound_info(dim, src_arr,
                            src_dim)) {
                        vd.is_array_dim_size = true;
                        vd.source_array_name = src_arr;
                        vd.source_dim_index = src_dim;
                    } else {
                        size_t idx = 0;
                        if (find_arg_var_in_expr(dim, arg_names, idx)) {
                            vd.call_arg_index = idx;
                        }
                    }
                }
            } else {
                vd.is_constant = true;
                vd.constant_value = 1;
                vd.call_arg_index = 0;
            }
            ws.dims.push_back(vd);
        }
        result.push_back(std::move(ws));
    }
}

// Count VLA workspaces in a kernel without assigning buffer indices.
inline int count_gpu_vla_workspaces(const ASR::GpuKernelFunction_t &kernel) {
    int count = 0;
    bool has_struct_alloc_member =
        !find_struct_alloc_member_key(kernel).empty();
    for (size_t i = 0; i < kernel.n_body; i++) {
        if (!ASR::is_a<ASR::BlockCall_t>(*kernel.m_body[i])) continue;
        ASR::BlockCall_t *bc = ASR::down_cast<ASR::BlockCall_t>(
            kernel.m_body[i]);
        if (!ASR::is_a<ASR::Block_t>(*bc->m_m)) continue;
        ASR::Block_t *block = ASR::down_cast<ASR::Block_t>(bc->m_m);
        for (auto &item : block->m_symtab->get_scope()) {
            if (!ASR::is_a<ASR::Variable_t>(*item.second)) continue;
            ASR::Variable_t *var = ASR::down_cast<ASR::Variable_t>(
                item.second);
            if (ASR::is_a<ASR::Array_t>(*var->m_type)) {
                ASR::Array_t *arr = ASR::down_cast<ASR::Array_t>(
                    var->m_type);
                for (size_t d = 0; d < arr->n_dims; d++) {
                    if (arr->m_dims[d].m_length &&
                            !ASR::is_a<ASR::IntegerConstant_t>(
                                *arr->m_dims[d].m_length)) {
                        count++;
                        break;
                    }
                }
            } else if (ASRUtils::is_allocatable(var->m_type)) {
                ASR::ttype_t *inner =
                    ASRUtils::type_get_past_allocatable(var->m_type);
                if (ASR::is_a<ASR::Array_t>(*inner) &&
                        has_struct_alloc_member) {
                    count++;
                }
            }
        }
    }
    // Also count kernel-scope Allocatable(Array) variables with
    // runtime-dependent Allocate dimensions or no Allocate (func temps)
    std::set<std::string> arg_name_set;
    for (size_t i = 0; i < kernel.n_args; i++) {
        ASR::Var_t *v = ASR::down_cast<ASR::Var_t>(kernel.m_args[i]);
        arg_name_set.insert(std::string(ASRUtils::symbol_name(
            ASRUtils::symbol_get_past_external(v->m_v))));
    }
    for (auto &item : kernel.m_symtab->get_scope()) {
        if (!ASR::is_a<ASR::Variable_t>(*item.second)) continue;
        ASR::Variable_t *var =
            ASR::down_cast<ASR::Variable_t>(item.second);
        if (!ASRUtils::is_allocatable(var->m_type)) continue;
        ASR::ttype_t *inner =
            ASRUtils::type_get_past_allocatable(var->m_type);
        if (!ASR::is_a<ASR::Array_t>(*inner)) continue;
        std::string vname(var->m_name);
        if (arg_name_set.count(vname)) continue;
        ASR::Allocate_t *alloc = find_allocate_for_var(
            kernel.m_body, kernel.n_body, vname);
        if (!alloc) {
            if (has_struct_alloc_member) count++;
            continue;
        }
        for (size_t ai = 0; ai < alloc->n_args; ai++) {
            if (!alloc->m_args[ai].m_a) continue;
            if (!ASR::is_a<ASR::Var_t>(*alloc->m_args[ai].m_a))
                continue;
            std::string aname = ASRUtils::symbol_name(
                ASR::down_cast<ASR::Var_t>(
                    alloc->m_args[ai].m_a)->m_v);
            if (aname != std::string(var->m_name)) continue;
            bool has_runtime = false;
            for (size_t d = 0; d < alloc->m_args[ai].n_dims; d++) {
                if (alloc->m_args[ai].m_dims[d].m_length &&
                        !ASR::is_a<ASR::IntegerConstant_t>(
                            *alloc->m_args[ai].m_dims[d].m_length)) {
                    has_runtime = true;
                    break;
                }
            }
            if (has_runtime) count++;
            break;
        }
    }
    // Also count kernel-scope non-allocatable Array variables with
    // runtime-dependent dimensions (e.g. pass-generated temporaries)
    for (auto &item : kernel.m_symtab->get_scope()) {
        if (!ASR::is_a<ASR::Variable_t>(*item.second)) continue;
        ASR::Variable_t *var =
            ASR::down_cast<ASR::Variable_t>(item.second);
        if (ASRUtils::is_allocatable(var->m_type)) continue;
        if (!ASR::is_a<ASR::Array_t>(*var->m_type)) continue;
        std::string vname(var->m_name);
        if (arg_name_set.count(vname)) continue;
        ASR::Array_t *arr = ASR::down_cast<ASR::Array_t>(var->m_type);
        for (size_t d = 0; d < arr->n_dims; d++) {
            if (arr->m_dims[d].m_length &&
                    !ASR::is_a<ASR::IntegerConstant_t>(
                        *arr->m_dims[d].m_length)) {
                count++;
                break;
            }
        }
    }
    return count;
}

static const int MAX_METAL_BUFFERS = 31;
static const int PACKED_BUFFER_ALIGN = 16;

// Determine whether a kernel needs buffer packing because its total
// buffer count exceeds Metal's 31-slot limit.
inline bool gpu_kernel_needs_buffer_packing(
        const ASR::GpuKernelFunction_t &kernel) {
    auto [n_buffer, n_scalar] = classify_gpu_kernel_args(kernel);
    int n_vla = count_gpu_vla_workspaces(kernel);
    int total = n_buffer + (n_scalar > 0 ? 1 : 0) + n_vla;
    return total > MAX_METAL_BUFFERS;
}

// Compute the Metal buffer index where VLA workspace buffers start.
// Normal layout:  [buffer_args...] [scalar_struct?] [vla_workspaces...]
// Packed layout:  [packed_arrays(0)] [scalar_struct(1)] [vla_workspaces...]
inline int gpu_vla_buffer_start(const ASR::GpuKernelFunction_t &kernel) {
    if (gpu_kernel_needs_buffer_packing(kernel)) {
        return 2;
    }
    auto [n_buffer, n_scalar] = classify_gpu_kernel_args(kernel);
    return n_buffer + (n_scalar > 0 ? 1 : 0);
}

// Analyze a GPU kernel function for variable-length arrays in blocks.
// Returns workspace metadata for each VLA found, with buffer indices
// assigned sequentially starting after the kernel's packed arguments.
inline std::vector<GpuVlaWorkspace> analyze_gpu_vla_workspaces(
        const ASR::GpuKernelFunction_t &kernel) {
    // Build the kernel argument name list for mapping dim vars to arg indices
    std::vector<std::string> arg_names;
    for (size_t i = 0; i < kernel.n_args; i++) {
        ASR::Var_t *v = ASR::down_cast<ASR::Var_t>(kernel.m_args[i]);
        ASR::Variable_t *var = ASR::down_cast<ASR::Variable_t>(
            ASRUtils::symbol_get_past_external(v->m_v));
        arg_names.push_back(std::string(var->m_name));
    }

    // Buffer index starts after buffer args + optional scalar struct
    int buffer_idx = gpu_vla_buffer_start(kernel);

    std::vector<GpuVlaWorkspace> result;

    // Scan BlockCall statements in the kernel body for VLAs
    for (size_t i = 0; i < kernel.n_body; i++) {
        if (!ASR::is_a<ASR::BlockCall_t>(*kernel.m_body[i])) continue;
        ASR::BlockCall_t *bc = ASR::down_cast<ASR::BlockCall_t>(
            kernel.m_body[i]);
        if (!ASR::is_a<ASR::Block_t>(*bc->m_m)) continue;
        ASR::Block_t *block = ASR::down_cast<ASR::Block_t>(bc->m_m);

        for (auto &item : block->m_symtab->get_scope()) {
            if (!ASR::is_a<ASR::Variable_t>(*item.second)) continue;
            ASR::Variable_t *var = ASR::down_cast<ASR::Variable_t>(
                item.second);
            if (!ASR::is_a<ASR::Array_t>(*var->m_type)) continue;
            ASR::Array_t *arr = ASR::down_cast<ASR::Array_t>(var->m_type);

            bool has_vla = false;
            for (size_t d = 0; d < arr->n_dims; d++) {
                if (arr->m_dims[d].m_length &&
                        !ASR::is_a<ASR::IntegerConstant_t>(
                            *arr->m_dims[d].m_length)) {
                    has_vla = true;
                    break;
                }
            }
            if (!has_vla) continue;

            GpuVlaWorkspace ws;
            ws.var_name = var->m_name;
            ws.buffer_index = buffer_idx++;

            // Compute element size from the array element type
            if (ASR::is_a<ASR::Real_t>(*arr->m_type)) {
                ws.elem_size = ASR::down_cast<ASR::Real_t>(
                    arr->m_type)->m_kind;
            } else if (ASR::is_a<ASR::Integer_t>(*arr->m_type)) {
                ws.elem_size = ASR::down_cast<ASR::Integer_t>(
                    arr->m_type)->m_kind;
            } else {
                ws.elem_size = 4;
            }

            // Process each dimension
            for (size_t d = 0; d < arr->n_dims; d++) {
                ASR::expr_t *dim = arr->m_dims[d].m_length;
                GpuVlaDim vd;
                vd.dim_expr = dim;
                if (dim && ASR::is_a<ASR::IntegerConstant_t>(*dim)) {
                    vd.is_constant = true;
                    vd.constant_value =
                        ASR::down_cast<ASR::IntegerConstant_t>(dim)->m_n;
                    vd.call_arg_index = 0;
                } else if (dim && ASR::is_a<ASR::Var_t>(*dim)) {
                    std::string dim_name = ASRUtils::symbol_name(
                        ASR::down_cast<ASR::Var_t>(dim)->m_v);
                    vd.is_constant = false;
                    vd.constant_value = 0;
                    vd.call_arg_index = 0;
                    for (size_t a = 0; a < arg_names.size(); a++) {
                        if (arg_names[a] == dim_name) {
                            vd.call_arg_index = a;
                            break;
                        }
                    }
                } else {
                    vd.is_constant = true;
                    vd.constant_value = 1;
                    vd.call_arg_index = 0;
                }
                ws.dims.push_back(vd);
            }
            result.push_back(std::move(ws));
        }

        // Also scan allocatable arrays in block scope (temporaries from
        // subroutine_from_function pass whose size depends on a struct
        // member's allocatable array).
        for (auto &item2 : block->m_symtab->get_scope()) {
            if (!ASR::is_a<ASR::Variable_t>(*item2.second)) continue;
            ASR::Variable_t *var2 = ASR::down_cast<ASR::Variable_t>(
                item2.second);
            if (!ASRUtils::is_allocatable(var2->m_type)) continue;
            ASR::ttype_t *inner =
                ASRUtils::type_get_past_allocatable(var2->m_type);
            if (!ASR::is_a<ASR::Array_t>(*inner)) continue;
            std::string vname(var2->m_name);
            bool already = false;
            for (auto &r : result) {
                if (r.var_name == vname) { already = true; break; }
            }
            if (already) continue;
            std::string struct_key = find_struct_alloc_member_key(kernel);
            if (struct_key.empty()) continue;
            ASR::Array_t *arr2 = ASR::down_cast<ASR::Array_t>(inner);
            GpuVlaWorkspace ws;
            ws.var_name = vname;
            ws.buffer_index = buffer_idx++;
            if (ASR::is_a<ASR::Real_t>(*arr2->m_type)) {
                ws.elem_size = ASR::down_cast<ASR::Real_t>(
                    arr2->m_type)->m_kind;
            } else if (ASR::is_a<ASR::Integer_t>(*arr2->m_type)) {
                ws.elem_size = ASR::down_cast<ASR::Integer_t>(
                    arr2->m_type)->m_kind;
            } else {
                ws.elem_size = 4;
            }
            GpuVlaDim vd;
            vd.dim_expr = nullptr;
            vd.is_constant = false;
            vd.constant_value = 0;
            vd.call_arg_index = 0;
            vd.is_struct_member_size = true;
            vd.struct_member_key = struct_key;
            ws.dims.push_back(vd);
            result.push_back(std::move(ws));
        }
    }

    // Also scan kernel-scope Allocatable(Array) variables whose Allocate
    // statements have runtime-dependent dimensions (e.g. temporaries from
    // subroutine_from_function pass with runtime-sized array sections).
    scan_kernel_scope_alloc_vlas(kernel, arg_names, buffer_idx, result);

    // Also scan kernel-scope non-allocatable Array variables with
    // runtime-dependent dimensions (e.g. subroutine_from_function temps
    // whose size depends on array bounds of kernel arguments).
    scan_kernel_scope_nonalloc_vlas(kernel, arg_names, buffer_idx, result);

    return result;
}

// Scan a kernel body for alloc-assign statements that write a VLA workspace
// array to a struct array member.  Returns a map from
// "struct_name.member_name" to the per-element size (number of elements)
// determined by the VLA workspace dimensions.
// Helper: compute compile-time size of a FixedSizeArray type.
// Returns 0 if the type is not a FixedSizeArray or has non-constant dims.
inline int64_t get_fixed_size_array_size(ASR::ttype_t *t) {
    ASR::ttype_t *past = ASRUtils::type_get_past_allocatable(t);
    if (!ASR::is_a<ASR::Array_t>(*past)) return 0;
    ASR::Array_t *arr = ASR::down_cast<ASR::Array_t>(past);
    if (arr->m_physical_type != ASR::array_physical_typeType::FixedSizeArray)
        return 0;
    int64_t sz = 1;
    for (size_t d = 0; d < arr->n_dims; d++) {
        if (arr->m_dims[d].m_length &&
                ASR::is_a<ASR::IntegerConstant_t>(
                    *arr->m_dims[d].m_length)) {
            sz *= ASR::down_cast<ASR::IntegerConstant_t>(
                arr->m_dims[d].m_length)->m_n;
        } else {
            return 0;
        }
    }
    return sz;
}

// Extract a compile-time integer constant from an ASR expression,
// evaluating simple IntegerBinOp chains recursively.
// Returns INT64_MIN if the expression is not a compile-time constant.
inline int64_t eval_iconst(ASR::expr_t *e) {
    if (!e) return INT64_MIN;
    if (ASR::is_a<ASR::IntegerConstant_t>(*e))
        return ASR::down_cast<ASR::IntegerConstant_t>(e)->m_n;
    if (ASR::is_a<ASR::ArrayBound_t>(*e)) {
        ASR::expr_t *v = ASR::down_cast<ASR::ArrayBound_t>(e)
            ->m_value;
        if (v) return eval_iconst(v);
        return INT64_MIN;
    }
    if (ASR::is_a<ASR::Cast_t>(*e)) {
        ASR::Cast_t *c = ASR::down_cast<ASR::Cast_t>(e);
        if (c->m_value) return eval_iconst(c->m_value);
        return eval_iconst(c->m_arg);
    }
    if (ASR::is_a<ASR::IntegerBinOp_t>(*e)) {
        ASR::IntegerBinOp_t *bo =
            ASR::down_cast<ASR::IntegerBinOp_t>(e);
        if (bo->m_value) return eval_iconst(bo->m_value);
        int64_t lv = eval_iconst(bo->m_left);
        int64_t rv = eval_iconst(bo->m_right);
        if (lv == INT64_MIN || rv == INT64_MIN) return INT64_MIN;
        switch (bo->m_op) {
            case ASR::binopType::Add: return lv + rv;
            case ASR::binopType::Sub: return lv - rv;
            case ASR::binopType::Mul: return lv * rv;
            case ASR::binopType::Div:
                return rv != 0 ? lv / rv : INT64_MIN;
            default: return INT64_MIN;
        }
    }
    return INT64_MIN;
}

// Compute the compile-time element count of an ArraySection.
// Returns 0 if any dimension range has non-constant bounds.
inline int64_t get_array_section_size(ASR::ArraySection_t *as) {
    int64_t total = 1;
    for (size_t d = 0; d < as->n_args; d++) {
        ASR::expr_t *lo = as->m_args[d].m_left;
        ASR::expr_t *hi = as->m_args[d].m_right;
        ASR::expr_t *st = as->m_args[d].m_step;
        if (!lo || !st) continue; // index, not a range
        int64_t lo_v = eval_iconst(lo);
        int64_t hi_v = eval_iconst(hi);
        int64_t st_v = eval_iconst(st);
        if (lo_v == INT64_MIN || hi_v == INT64_MIN ||
                st_v == INT64_MIN || st_v == 0)
            return 0;
        int64_t dim_sz = (hi_v - lo_v) / st_v + 1;
        if (dim_sz <= 0) return 0;
        total *= dim_sz;
    }
    return total;
}

// Unwrap ArrayPhysicalCast to get the inner expression.
inline ASR::expr_t* unwrap_array_physical_cast(ASR::expr_t *e) {
    if (ASR::is_a<ASR::ArrayPhysicalCast_t>(*e))
        return ASR::down_cast<ASR::ArrayPhysicalCast_t>(e)->m_arg;
    return e;
}

// Extract a compile-time integer constant from an ASR expression.
// Handles IntegerConstant directly, ArrayBound nodes whose m_value
// is an IntegerConstant, Cast wrapping a constant, IntegerBinOp
// with constant operands, and any expression whose expr_value()
// is an IntegerConstant.
inline bool extract_const_int(ASR::expr_t *e, int64_t &val) {
    if (!e) return false;
    if (ASR::is_a<ASR::IntegerConstant_t>(*e)) {
        val = ASR::down_cast<ASR::IntegerConstant_t>(e)->m_n;
        return true;
    }
    if (ASR::is_a<ASR::ArrayBound_t>(*e)) {
        ASR::ArrayBound_t *ab = ASR::down_cast<ASR::ArrayBound_t>(e);
        if (ab->m_value &&
                ASR::is_a<ASR::IntegerConstant_t>(*ab->m_value)) {
            val = ASR::down_cast<ASR::IntegerConstant_t>(
                ab->m_value)->m_n;
            return true;
        }
    }
    if (ASR::is_a<ASR::Cast_t>(*e)) {
        return extract_const_int(
            ASR::down_cast<ASR::Cast_t>(e)->m_arg, val);
    }
    if (ASR::is_a<ASR::IntegerBinOp_t>(*e)) {
        ASR::IntegerBinOp_t *bo =
            ASR::down_cast<ASR::IntegerBinOp_t>(e);
        if (bo->m_value) {
            return extract_const_int(bo->m_value, val);
        }
        int64_t lv = 0, rv = 0;
        if (extract_const_int(bo->m_left, lv) &&
                extract_const_int(bo->m_right, rv)) {
            switch (bo->m_op) {
                case ASR::binopType::Add: val = lv + rv; return true;
                case ASR::binopType::Sub: val = lv - rv; return true;
                case ASR::binopType::Mul: val = lv * rv; return true;
                case ASR::binopType::Div:
                    if (rv != 0) { val = lv / rv; return true; }
                    return false;
                default: return false;
            }
        }
    }
    // Try the compile-time evaluated value of the expression
    ASR::expr_t *v = ASRUtils::expr_value(e);
    if (v && v != e && ASR::is_a<ASR::IntegerConstant_t>(*v)) {
        val = ASR::down_cast<ASR::IntegerConstant_t>(v)->m_n;
        return true;
    }
    return false;
}

inline std::map<std::string, int64_t> find_struct_member_vla_write_sizes(
        const ASR::GpuKernelFunction_t &kernel,
        const std::vector<GpuVlaWorkspace> &vla_workspaces) {
    std::map<std::string, int64_t> result;
    std::map<std::string, const GpuVlaWorkspace*> ws_by_name;
    for (auto &ws : vla_workspaces) {
        ws_by_name[ws.var_name] = &ws;
    }
    // Track known member sizes for local struct variables so that
    // sizes can propagate through chains of function calls
    // (e.g., inner writes to temp%vals, outer copies temp to res(i)).
    // Key: "local_var.member", Value: compile-time element count.
    std::map<std::string, int64_t> local_struct_sizes;

    // Build a map from Associate target variable names to their
    // associated expressions (e.g., from subroutine_from_function).
    std::map<std::string, ASR::expr_t*> assoc_map;
    for (size_t si = 0; si < kernel.n_body; si++) {
        if (kernel.m_body[si]->type == ASR::stmtType::Associate) {
            ASR::Associate_t *assoc =
                ASR::down_cast<ASR::Associate_t>(kernel.m_body[si]);
            if (ASR::is_a<ASR::Var_t>(*assoc->m_target)) {
                std::string tname = ASRUtils::symbol_name(
                    ASR::down_cast<ASR::Var_t>(
                        assoc->m_target)->m_v);
                assoc_map[tname] = assoc->m_value;
            }
        }
    }

    for (size_t si = 0; si < kernel.n_body; si++) {
        ASR::stmt_t *stmt = kernel.m_body[si];
        if (stmt->type == ASR::stmtType::Assignment) {
            ASR::Assignment_t *asgn =
                ASR::down_cast<ASR::Assignment_t>(stmt);
            // Case: arr(i) = StructConstructor(t, [arg1, ...])
            // where arg is a VLA workspace variable
            if (ASR::is_a<ASR::ArrayItem_t>(*asgn->m_target) &&
                    ASR::is_a<ASR::StructConstructor_t>(*asgn->m_value)) {
                ASR::ArrayItem_t *ai =
                    ASR::down_cast<ASR::ArrayItem_t>(asgn->m_target);
                if (ASR::is_a<ASR::Var_t>(*ai->m_v)) {
                    std::string arr_name = ASRUtils::symbol_name(
                        ASR::down_cast<ASR::Var_t>(ai->m_v)->m_v);
                    ASR::StructConstructor_t *sc =
                        ASR::down_cast<ASR::StructConstructor_t>(
                            asgn->m_value);
                    ASR::symbol_t *struct_sym =
                        ASRUtils::symbol_get_past_external(sc->m_dt_sym);
                    if (ASR::is_a<ASR::Struct_t>(*struct_sym)) {
                        ASR::Struct_t *st =
                            ASR::down_cast<ASR::Struct_t>(struct_sym);
                        for (size_t mi = 0;
                                mi < st->n_members && mi < sc->n_args;
                                mi++) {
                            if (!sc->m_args[mi].m_value) continue;
                            ASR::symbol_t *mem =
                                st->m_symtab->get_symbol(
                                    st->m_members[mi]);
                            if (!mem ||
                                    !ASR::is_a<ASR::Variable_t>(*mem))
                                continue;
                            ASR::Variable_t *mv =
                                ASR::down_cast<ASR::Variable_t>(mem);
                            if (!ASRUtils::is_allocatable(mv->m_type))
                                continue;
                            ASR::ttype_t *inner =
                                ASRUtils::type_get_past_allocatable(
                                    mv->m_type);
                            if (!ASR::is_a<ASR::Array_t>(*inner))
                                continue;
                            std::string key =
                                arr_name + "." + st->m_members[mi];
                            if (result.count(key)) continue;
                            ASR::expr_t *arg = sc->m_args[mi].m_value;
                            if (ASR::is_a<ASR::Var_t>(*arg)) {
                                std::string val_name =
                                    ASRUtils::symbol_name(
                                        ASR::down_cast<ASR::Var_t>(
                                            arg)->m_v);
                                auto ws_it = ws_by_name.find(val_name);
                                if (ws_it != ws_by_name.end()) {
                                    int64_t per_elem = 1;
                                    bool all_const = true;
                                    for (auto &dim :
                                            ws_it->second->dims) {
                                        if (dim.is_constant) {
                                            per_elem *=
                                                dim.constant_value;
                                        } else {
                                            all_const = false;
                                            break;
                                        }
                                    }
                                    if (all_const && per_elem > 0) {
                                        result[key] = per_elem;
                                    }
                                }
                            } else if (ASR::is_a<ASR::ArraySection_t>(
                                    *arg)) {
                                // ArraySection (e.g., h(:)):
                                // compute size from section bounds
                                ASR::ArraySection_t *as =
                                    ASR::down_cast<ASR::ArraySection_t>(
                                        arg);
                                int64_t total = 1;
                                bool all_const = true;
                                for (size_t d = 0; d < as->n_args;
                                        d++) {
                                    int64_t lb_val = 0, ub_val = 0,
                                            step_val = 1;
                                    if (extract_const_int(
                                            as->m_args[d].m_left,
                                            lb_val) &&
                                            extract_const_int(
                                                as->m_args[d].m_right,
                                                ub_val)) {
                                        if (as->m_args[d].m_step) {
                                            if (!extract_const_int(
                                                    as->m_args[d].m_step,
                                                    step_val) ||
                                                    step_val == 0) {
                                                all_const = false;
                                                break;
                                            }
                                        }
                                        total *= (ub_val - lb_val)
                                            / step_val + 1;
                                    } else {
                                        all_const = false;
                                        break;
                                    }
                                }
                                if (all_const && total > 0) {
                                    result[key] = total;
                                }
                            }
                        }
                    }
                }
            }
            // Case: arr(i) = FunctionCall(f, ...)
            // where f returns a struct with allocatable members.
            // Trace into f's body to find writes to the return
            // variable's allocatable members and determine sizes.
            if (ASR::is_a<ASR::ArrayItem_t>(*asgn->m_target) &&
                    ASR::is_a<ASR::FunctionCall_t>(*asgn->m_value)) {
                ASR::ArrayItem_t *ai =
                    ASR::down_cast<ASR::ArrayItem_t>(asgn->m_target);
                if (ASR::is_a<ASR::Var_t>(*ai->m_v)) {
                    std::string arr_name = ASRUtils::symbol_name(
                        ASR::down_cast<ASR::Var_t>(ai->m_v)->m_v);
                    ASR::FunctionCall_t *fc =
                        ASR::down_cast<ASR::FunctionCall_t>(
                            asgn->m_value);
                    ASR::symbol_t *fn_sym =
                        ASRUtils::symbol_get_past_external(
                            fc->m_name);
                    if (ASR::is_a<ASR::Function_t>(*fn_sym)) {
                        ASR::Function_t *fn =
                            ASR::down_cast<ASR::Function_t>(fn_sym);
                        std::string ret_name;
                        if (fn->m_return_var &&
                                ASR::is_a<ASR::Var_t>(
                                    *fn->m_return_var)) {
                            ret_name = ASRUtils::symbol_name(
                                ASR::down_cast<ASR::Var_t>(
                                    fn->m_return_var)->m_v);
                        }
                        if (!ret_name.empty()) {
                            for (size_t fi = 0;
                                    fi < fn->n_body; fi++) {
                                if (fn->m_body[fi]->type !=
                                        ASR::stmtType::Assignment)
                                    continue;
                                ASR::Assignment_t *fa =
                                    ASR::down_cast<
                                        ASR::Assignment_t>(
                                            fn->m_body[fi]);
                                if (!ASR::is_a<
                                        ASR::StructInstanceMember_t>(
                                            *fa->m_target))
                                    continue;
                                ASR::StructInstanceMember_t *fsm =
                                    ASR::down_cast<
                                        ASR::StructInstanceMember_t>(
                                            fa->m_target);
                                if (!ASR::is_a<ASR::Var_t>(
                                        *fsm->m_v))
                                    continue;
                                std::string tgt_name =
                                    ASRUtils::symbol_name(
                                        ASR::down_cast<ASR::Var_t>(
                                            fsm->m_v)->m_v);
                                if (tgt_name != ret_name) continue;
                                std::string mem_name =
                                    ASRUtils::symbol_name(
                                        ASRUtils::
                                            symbol_get_past_external(
                                                fsm->m_m));
                                std::string key =
                                    arr_name + "." + mem_name;
                                if (result.count(key)) continue;
                                // Check RHS type for fixed size
                                ASR::ttype_t *rhs_type =
                                    ASRUtils::expr_type(
                                        fa->m_value);
                                int64_t fsz =
                                    get_fixed_size_array_size(
                                        rhs_type);
                                if (fsz > 0) {
                                    result[key] = fsz;
                                } else if (ASR::is_a<ASR::Var_t>(
                                        *fa->m_value)) {
                                    std::string rhs_name =
                                        ASRUtils::symbol_name(
                                            ASR::down_cast<
                                                ASR::Var_t>(
                                                    fa->m_value)
                                                ->m_v);
                                    auto ws_it =
                                        ws_by_name.find(rhs_name);
                                    if (ws_it != ws_by_name.end()) {
                                        int64_t per_elem = 1;
                                        bool all_const = true;
                                        for (auto &dim :
                                                ws_it->second
                                                    ->dims) {
                                            if (dim.is_constant) {
                                                per_elem *=
                                                    dim.constant_value;
                                            } else {
                                                all_const = false;
                                                break;
                                            }
                                        }
                                        if (all_const
                                                && per_elem > 0) {
                                            result[key] = per_elem;
                                        }
                                    } else {
                                        // Trace formal param back
                                        // to actual arg at call site
                                        for (size_t pi = 0;
                                                pi < fn->n_args;
                                                pi++) {
                                            ASR::Variable_t *fp =
                                                ASR::down_cast<
                                                    ASR::Variable_t>(
                                                    ASR::down_cast<
                                                        ASR::Var_t>(
                                                        fn->m_args[pi])
                                                        ->m_v);
                                            if (std::string(
                                                    fp->m_name)
                                                    != rhs_name)
                                                continue;
                                            if (pi >= fc->n_args)
                                                break;
                                            ASR::expr_t *actual =
                                                fc->m_args[pi]
                                                    .m_value;
                                            if (!actual) break;
                                            int64_t asz =
                                                get_fixed_size_array_size(
                                                    ASRUtils::expr_type(
                                                        actual));
                                            if (asz > 0) {
                                                result[key] = asz;
                                                break;
                                            }
                                            ASR::expr_t *inner =
                                                unwrap_array_physical_cast(
                                                    actual);
                                            if (ASR::is_a<ASR::
                                                    ArraySection_t>(
                                                        *inner)) {
                                                int64_t ss =
                                                    get_array_section_size(
                                                        ASR::down_cast<
                                                            ASR::ArraySection_t>(
                                                                inner));
                                                if (ss > 0)
                                                    result[key] = ss;
                                            }
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if (!ASR::is_a<ASR::StructInstanceMember_t>(*asgn->m_target))
                continue;
            ASR::StructInstanceMember_t *sm =
                ASR::down_cast<ASR::StructInstanceMember_t>(
                    asgn->m_target);
            std::string mem_name = ASRUtils::symbol_name(
                ASRUtils::symbol_get_past_external(sm->m_m));
            std::string struct_name;
            if (ASR::is_a<ASR::ArrayItem_t>(*sm->m_v)) {
                ASR::ArrayItem_t *ai =
                    ASR::down_cast<ASR::ArrayItem_t>(sm->m_v);
                if (ASR::is_a<ASR::Var_t>(*ai->m_v)) {
                    struct_name = ASRUtils::symbol_name(
                        ASR::down_cast<ASR::Var_t>(ai->m_v)->m_v);
                }
            }
            if (struct_name.empty()) continue;
            std::string key = struct_name + "." + mem_name;
            if (result.count(key)) continue;
            // Try fixed-size RHS first (e.g., ArrayConstant)
            int64_t rhs_fsz = get_fixed_size_array_size(
                ASRUtils::expr_type(asgn->m_value));
            if (rhs_fsz > 0) {
                result[key] = rhs_fsz;
                continue;
            }
            // Fall back to VLA workspace lookup
            if (!ASR::is_a<ASR::Var_t>(*asgn->m_value)) continue;
            std::string val_name = ASRUtils::symbol_name(
                ASR::down_cast<ASR::Var_t>(asgn->m_value)->m_v);
            auto ws_it = ws_by_name.find(val_name);
            if (ws_it != ws_by_name.end()) {
                int64_t per_elem = 1;
                bool all_const = true;
                for (auto &dim : ws_it->second->dims) {
                    if (dim.is_constant) {
                        per_elem *= dim.constant_value;
                    } else {
                        all_const = false;
                        break;
                    }
                }
                if (all_const && per_elem > 0) {
                    result[key] = per_elem;
                }
                continue;
            }
            // Check if the RHS variable is associated with an
            // ArraySection (from lowered StructConstructor).
            auto assoc_it = assoc_map.find(val_name);
            if (assoc_it != assoc_map.end()) {
                ASR::expr_t *assoc_val = assoc_it->second;
                if (ASR::is_a<ASR::ArraySection_t>(*assoc_val)) {
                    ASR::ArraySection_t *as =
                        ASR::down_cast<ASR::ArraySection_t>(
                            assoc_val);
                    int64_t total = 1;
                    bool all_const = true;
                    for (size_t d = 0; d < as->n_args; d++) {
                        int64_t lb_val = 0, ub_val = 0,
                                step_val = 1;
                        bool got_lb = extract_const_int(
                                as->m_args[d].m_left, lb_val);
                        bool got_ub = extract_const_int(
                                as->m_args[d].m_right, ub_val);
                        if (got_lb && got_ub) {
                            if (as->m_args[d].m_step) {
                                if (!extract_const_int(
                                        as->m_args[d].m_step,
                                        step_val) ||
                                        step_val == 0) {
                                    all_const = false;
                                    break;
                                }
                            }
                            total *= (ub_val - lb_val)
                                / step_val + 1;
                        } else {
                            all_const = false;
                            break;
                        }
                    }
                    if (all_const && total > 0) {
                        result[key] = total;
                    }
                }
            }
        } else if (stmt->type == ASR::stmtType::SubroutineCall) {
            // Look through subroutine calls for writes to struct
            // allocatable members (e.g., construct(x, a(i)) where
            // the function body does r%v = x).
            ASR::SubroutineCall_t *sc =
                ASR::down_cast<ASR::SubroutineCall_t>(stmt);
            ASR::symbol_t *fn_sym =
                ASRUtils::symbol_get_past_external(sc->m_name);
            if (!ASR::is_a<ASR::Function_t>(*fn_sym)) continue;
            ASR::Function_t *fn =
                ASR::down_cast<ASR::Function_t>(fn_sym);

            // Phase 1: Track sizes written to local struct vars
            // through function calls (e.g., inner(x(i), temp) where
            // inner body does obj%vals = [x]).
            for (size_t ai = 0; ai < sc->n_args; ai++) {
                if (!sc->m_args[ai].m_value) continue;
                if (!ASR::is_a<ASR::Var_t>(
                        *sc->m_args[ai].m_value)) continue;
                ASR::ttype_t *act_type =
                    ASRUtils::expr_type(sc->m_args[ai].m_value);
                if (!ASR::is_a<ASR::StructType_t>(
                        *ASRUtils::extract_type(act_type)))
                    continue;
                std::string local_name = ASRUtils::symbol_name(
                    ASR::down_cast<ASR::Var_t>(
                        sc->m_args[ai].m_value)->m_v);
                if (ai >= fn->n_args) continue;
                ASR::Variable_t *formal =
                    ASR::down_cast<ASR::Variable_t>(
                        ASR::down_cast<ASR::Var_t>(
                            fn->m_args[ai])->m_v);
                if (formal->m_intent != ASR::intentType::Out
                        && formal->m_intent
                            != ASR::intentType::InOut)
                    continue;
                std::string formal_name(formal->m_name);
                // Scan function body for formal%member = rhs
                for (size_t fi = 0; fi < fn->n_body; fi++) {
                    if (fn->m_body[fi]->type !=
                            ASR::stmtType::Assignment) continue;
                    ASR::Assignment_t *fa =
                        ASR::down_cast<ASR::Assignment_t>(
                            fn->m_body[fi]);
                    if (!ASR::is_a<ASR::StructInstanceMember_t>(
                            *fa->m_target)) continue;
                    ASR::StructInstanceMember_t *fsm =
                        ASR::down_cast<ASR::StructInstanceMember_t>(
                            fa->m_target);
                    if (!ASR::is_a<ASR::Var_t>(*fsm->m_v)) continue;
                    std::string tgt_name = ASRUtils::symbol_name(
                        ASR::down_cast<ASR::Var_t>(
                            fsm->m_v)->m_v);
                    if (tgt_name != formal_name) continue;
                    std::string mem_name = ASRUtils::symbol_name(
                        ASRUtils::symbol_get_past_external(
                            fsm->m_m));
                    std::string lkey =
                        local_name + "." + mem_name;
                    if (local_struct_sizes.count(lkey)) continue;
                    // Check if RHS has a known fixed size from
                    // its type (e.g., ArrayConstructor)
                    int64_t rhs_fsz =
                        get_fixed_size_array_size(
                            ASRUtils::expr_type(fa->m_value));
                    if (rhs_fsz > 0) {
                        local_struct_sizes[lkey] = rhs_fsz;
                    } else if (ASR::is_a<ASR::Var_t>(
                            *fa->m_value)) {
                        ASR::Variable_t *rhs_var =
                            ASR::down_cast<ASR::Variable_t>(
                                ASRUtils::symbol_get_past_external(
                                    ASR::down_cast<ASR::Var_t>(
                                        fa->m_value)->m_v));
                        int64_t fsz =
                            get_fixed_size_array_size(
                                rhs_var->m_type);
                        if (fsz > 0) {
                            local_struct_sizes[lkey] = fsz;
                        }
                    }
                }
            }

            // Phase 2: Find struct array elements (ArrayItem) and
            // trace writes through function bodies.
            for (size_t ai = 0; ai < sc->n_args; ai++) {
                if (!sc->m_args[ai].m_value) continue;
                if (!ASR::is_a<ASR::ArrayItem_t>(
                        *sc->m_args[ai].m_value)) continue;
                ASR::ArrayItem_t *arr_item =
                    ASR::down_cast<ASR::ArrayItem_t>(
                        sc->m_args[ai].m_value);
                ASR::ttype_t *elem_type = arr_item->m_type;
                if (!ASR::is_a<ASR::StructType_t>(
                        *ASRUtils::extract_type(elem_type)))
                    continue;
                if (!ASR::is_a<ASR::Var_t>(*arr_item->m_v)) continue;
                std::string arr_name = ASRUtils::symbol_name(
                    ASR::down_cast<ASR::Var_t>(
                        arr_item->m_v)->m_v);
                // Get the formal parameter name for this arg
                if (ai >= fn->n_args) continue;
                ASR::Variable_t *formal =
                    ASR::down_cast<ASR::Variable_t>(
                        ASR::down_cast<ASR::Var_t>(
                            fn->m_args[ai])->m_v);
                std::string formal_name(formal->m_name);
                // Scan function body for assignments to
                // formal%member = some_array_param
                for (size_t fi = 0; fi < fn->n_body; fi++) {
                    if (fn->m_body[fi]->type !=
                            ASR::stmtType::Assignment) continue;
                    ASR::Assignment_t *fa =
                        ASR::down_cast<ASR::Assignment_t>(
                            fn->m_body[fi]);
                    if (ASR::is_a<ASR::StructInstanceMember_t>(
                            *fa->m_target)) {
                        ASR::StructInstanceMember_t *fsm =
                            ASR::down_cast<
                                ASR::StructInstanceMember_t>(
                                    fa->m_target);
                        // Check target struct var matches the formal
                        if (!ASR::is_a<ASR::Var_t>(*fsm->m_v))
                            continue;
                        std::string tgt_name =
                            ASRUtils::symbol_name(
                                ASR::down_cast<ASR::Var_t>(
                                    fsm->m_v)->m_v);
                        if (tgt_name != formal_name) continue;
                        std::string mem_name =
                            ASRUtils::symbol_name(
                                ASRUtils::symbol_get_past_external(
                                    fsm->m_m));
                        std::string key =
                            arr_name + "." + mem_name;
                        if (result.count(key)) continue;
                        // Check if RHS has a known fixed size
                        // from its type (e.g., ArrayConstructor
                        // with FixedSizeArray dimensions).
                        int64_t rhs_fsz =
                            get_fixed_size_array_size(
                                ASRUtils::expr_type(
                                    fa->m_value));
                        if (rhs_fsz > 0) {
                            result[key] = rhs_fsz;
                            continue;
                        }
                        // RHS is a Var — find its size from the
                        // actual argument at the call site
                        if (!ASR::is_a<ASR::Var_t>(*fa->m_value))
                            continue;
                        std::string rhs_name =
                            ASRUtils::symbol_name(
                                ASR::down_cast<ASR::Var_t>(
                                    fa->m_value)->m_v);
                        // Find which formal param index this is
                        for (size_t pi = 0;
                                pi < fn->n_args; pi++) {
                            ASR::Variable_t *fp =
                                ASR::down_cast<ASR::Variable_t>(
                                    ASR::down_cast<ASR::Var_t>(
                                        fn->m_args[pi])->m_v);
                            if (std::string(fp->m_name) != rhs_name)
                                continue;
                            if (pi >= sc->n_args) break;
                            // Get the actual arg's size
                            ASR::expr_t *actual =
                                sc->m_args[pi].m_value;
                            if (!actual) break;
                            ASR::ttype_t *at =
                                ASRUtils::expr_type(actual);
                            ASR::ttype_t *past =
                                ASRUtils::
                                type_get_past_allocatable_pointer(
                                    at);
                            if (!ASR::is_a<ASR::Array_t>(*past))
                                break;
                            ASR::Array_t *arr =
                                ASR::down_cast<ASR::Array_t>(past);
                            int64_t sz = 1;
                            bool all_c = true;
                            for (size_t d = 0;
                                    d < arr->n_dims; d++) {
                                if (arr->m_dims[d].m_length &&
                                        ASR::is_a<
                                            ASR::IntegerConstant_t>(
                                            *arr->m_dims[d]
                                                .m_length)) {
                                    sz *= ASR::down_cast<
                                        ASR::IntegerConstant_t>(
                                        arr->m_dims[d]
                                            .m_length)->m_n;
                                } else {
                                    all_c = false;
                                    break;
                                }
                            }
                            if (all_c && sz > 0) {
                                result[key] = sz;
                            } else if (!all_c &&
                                    ASR::is_a<ASR::Var_t>(
                                        *actual)) {
                                std::string act_name =
                                    ASRUtils::symbol_name(
                                        ASR::down_cast<ASR::Var_t>(
                                            actual)->m_v);
                                auto ws_it2 =
                                    ws_by_name.find(act_name);
                                if (ws_it2 != ws_by_name.end()) {
                                    int64_t ws_sz = 1;
                                    bool ws_all_c = true;
                                    for (auto &dim :
                                            ws_it2->second->dims) {
                                        if (dim.is_constant) {
                                            ws_sz *=
                                                dim.constant_value;
                                        } else {
                                            ws_all_c = false;
                                            break;
                                        }
                                    }
                                    if (ws_all_c && ws_sz > 0) {
                                        result[key] = ws_sz;
                                    }
                                } else {
                                    // Check if variable is
                                    // associated with an
                                    // ArraySection (from
                                    // subroutine_from_function)
                                    auto ait =
                                        assoc_map.find(act_name);
                                    if (ait != assoc_map.end()) {
                                        ASR::expr_t *ae =
                                            unwrap_array_physical_cast(
                                                ait->second);
                                        if (ASR::is_a<ASR::
                                                ArraySection_t>(
                                                    *ae)) {
                                            int64_t ss =
                                                get_array_section_size(
                                                    ASR::down_cast<
                                                        ASR::ArraySection_t>(
                                                            ae));
                                            if (ss > 0)
                                                result[key] = ss;
                                        }
                                    }
                                }
                            }
                            break;
                        }
                    } else if (ASR::is_a<ASR::Var_t>(
                            *fa->m_target)) {
                        // Full struct assignment: out_formal =
                        // in_formal. Propagate member sizes from
                        // the source struct (which may be a local
                        // var with known member sizes).
                        std::string tgt_name =
                            ASRUtils::symbol_name(
                                ASR::down_cast<ASR::Var_t>(
                                    fa->m_target)->m_v);
                        if (tgt_name != formal_name) continue;
                        if (!ASR::is_a<ASR::Var_t>(*fa->m_value))
                            continue;
                        std::string src_name =
                            ASRUtils::symbol_name(
                                ASR::down_cast<ASR::Var_t>(
                                    fa->m_value)->m_v);
                        // Find the actual arg for the source
                        for (size_t pi = 0;
                                pi < fn->n_args; pi++) {
                            ASR::Variable_t *fp =
                                ASR::down_cast<ASR::Variable_t>(
                                    ASR::down_cast<ASR::Var_t>(
                                        fn->m_args[pi])->m_v);
                            if (std::string(fp->m_name) != src_name)
                                continue;
                            if (pi >= sc->n_args) break;
                            ASR::expr_t *actual =
                                sc->m_args[pi].m_value;
                            if (!actual) break;
                            // Source is a local struct var: look
                            // up its member sizes
                            if (ASR::is_a<ASR::Var_t>(*actual)) {
                                std::string act_name =
                                    ASRUtils::symbol_name(
                                        ASR::down_cast<ASR::Var_t>(
                                            actual)->m_v);
                                for (auto &ls :
                                        local_struct_sizes) {
                                    if (ls.first.compare(
                                            0, act_name.size() + 1,
                                            act_name + ".") == 0) {
                                        std::string mem =
                                            ls.first.substr(
                                                act_name.size() + 1);
                                        std::string key =
                                            arr_name + "." + mem;
                                        if (!result.count(key)) {
                                            result[key] = ls.second;
                                        }
                                    }
                                }
                            }
                            break;
                        }
                    }
                }
            }
        }
    }
    return result;
}

// Find struct member VLA writes whose size is determined at runtime from
// another struct array member (e.g., b(i)%v = x where x comes from a(i)%v).
// Returns a map from target "struct.member" key to source "struct.member" key.
inline std::map<std::string, std::string> find_struct_member_vla_runtime_sources(
        const ASR::GpuKernelFunction_t &kernel) {
    std::map<std::string, std::string> result;
    for (size_t si = 0; si < kernel.n_body; si++) {
        ASR::stmt_t *stmt = kernel.m_body[si];
        if (stmt->type != ASR::stmtType::SubroutineCall) continue;
        ASR::SubroutineCall_t *sc =
            ASR::down_cast<ASR::SubroutineCall_t>(stmt);
        ASR::symbol_t *fn_sym =
            ASRUtils::symbol_get_past_external(sc->m_name);
        if (!ASR::is_a<ASR::Function_t>(*fn_sym)) continue;
        ASR::Function_t *fn =
            ASR::down_cast<ASR::Function_t>(fn_sym);
        // Find which actual args are struct array elements (output)
        for (size_t ai = 0; ai < sc->n_args; ai++) {
            if (!sc->m_args[ai].m_value) continue;
            if (!ASR::is_a<ASR::ArrayItem_t>(
                    *sc->m_args[ai].m_value)) continue;
            ASR::ArrayItem_t *arr_item =
                ASR::down_cast<ASR::ArrayItem_t>(
                    sc->m_args[ai].m_value);
            ASR::ttype_t *elem_type = arr_item->m_type;
            if (!ASR::is_a<ASR::StructType_t>(
                    *ASRUtils::extract_type(elem_type)))
                continue;
            if (!ASR::is_a<ASR::Var_t>(*arr_item->m_v)) continue;
            std::string arr_name = ASRUtils::symbol_name(
                ASR::down_cast<ASR::Var_t>(
                    arr_item->m_v)->m_v);
            if (ai >= fn->n_args) continue;
            ASR::Variable_t *formal =
                ASR::down_cast<ASR::Variable_t>(
                    ASR::down_cast<ASR::Var_t>(
                        fn->m_args[ai])->m_v);
            std::string formal_name(formal->m_name);
            // Scan function body for formal%member = some_param
            for (size_t fi = 0; fi < fn->n_body; fi++) {
                if (fn->m_body[fi]->type !=
                        ASR::stmtType::Assignment) continue;
                ASR::Assignment_t *fa =
                    ASR::down_cast<ASR::Assignment_t>(
                        fn->m_body[fi]);
                if (!ASR::is_a<ASR::StructInstanceMember_t>(
                        *fa->m_target)) continue;
                ASR::StructInstanceMember_t *fsm =
                    ASR::down_cast<ASR::StructInstanceMember_t>(
                        fa->m_target);
                if (!ASR::is_a<ASR::Var_t>(*fsm->m_v)) continue;
                std::string tgt_name = ASRUtils::symbol_name(
                    ASR::down_cast<ASR::Var_t>(
                        fsm->m_v)->m_v);
                if (tgt_name != formal_name) continue;
                std::string mem_name = ASRUtils::symbol_name(
                    ASRUtils::symbol_get_past_external(
                        fsm->m_m));
                std::string tgt_key = arr_name + "." + mem_name;
                if (result.count(tgt_key)) continue;
                // RHS is a Var — find its actual arg
                if (!ASR::is_a<ASR::Var_t>(*fa->m_value))
                    continue;
                std::string rhs_name = ASRUtils::symbol_name(
                    ASR::down_cast<ASR::Var_t>(
                        fa->m_value)->m_v);
                for (size_t pi = 0; pi < fn->n_args; pi++) {
                    ASR::Variable_t *fp =
                        ASR::down_cast<ASR::Variable_t>(
                            ASR::down_cast<ASR::Var_t>(
                                fn->m_args[pi])->m_v);
                    if (std::string(fp->m_name) != rhs_name)
                        continue;
                    if (pi >= sc->n_args) break;
                    ASR::expr_t *actual =
                        sc->m_args[pi].m_value;
                    if (!actual) break;
                    // Check if actual is a StructInstanceMember
                    // of a struct array element (e.g., a(i)%v)
                    if (!ASR::is_a<ASR::StructInstanceMember_t>(
                            *actual)) break;
                    ASR::StructInstanceMember_t *src_sm =
                        ASR::down_cast<ASR::StructInstanceMember_t>(
                            actual);
                    std::string src_mem = ASRUtils::symbol_name(
                        ASRUtils::symbol_get_past_external(
                            src_sm->m_m));
                    if (ASR::is_a<ASR::ArrayItem_t>(
                            *src_sm->m_v)) {
                        ASR::ArrayItem_t *src_ai =
                            ASR::down_cast<ASR::ArrayItem_t>(
                                src_sm->m_v);
                        if (ASR::is_a<ASR::Var_t>(
                                *src_ai->m_v)) {
                            std::string src_arr =
                                ASRUtils::symbol_name(
                                    ASR::down_cast<ASR::Var_t>(
                                        src_ai->m_v)->m_v);
                            result[tgt_key] =
                                src_arr + "." + src_mem;
                        }
                    }
                    break;
                }
            }
        }
    }
    return result;
}

// Information about a struct member whose runtime size comes from an
// array section of a kernel argument (e.g., arr(i) = t(x(:, i))).
struct StructMemberSectionSource {
    std::string source_var;
    std::vector<size_t> section_dims;
};

// Extract section source info from an ArraySection expression.
// Returns true if the section has at least one range dimension whose
// bounds are not compile-time constants (i.e., runtime-sized).
inline bool get_runtime_section_source(ASR::ArraySection_t *as,
        StructMemberSectionSource &out) {
    if (!ASR::is_a<ASR::Var_t>(*as->m_v)) return false;
    out.source_var = ASRUtils::symbol_name(
        ASR::down_cast<ASR::Var_t>(as->m_v)->m_v);
    out.section_dims.clear();
    bool has_runtime_dim = false;
    for (size_t d = 0; d < as->n_args; d++) {
        ASR::expr_t *lo = as->m_args[d].m_left;
        ASR::expr_t *hi = as->m_args[d].m_right;
        ASR::expr_t *st = as->m_args[d].m_step;
        if (!lo || !st) continue;
        out.section_dims.push_back(d);
        int64_t lo_v = eval_iconst(lo);
        int64_t hi_v = eval_iconst(hi);
        if (lo_v == INT64_MIN || hi_v == INT64_MIN)
            has_runtime_dim = true;
    }
    return has_runtime_dim && !out.section_dims.empty();
}

// Find struct member allocatable components whose size is determined at
// runtime from an array section of another kernel argument.
// After passes (e.g., subroutine_from_function), StructConstructor args
// may be Var references resolved through Associate statements.
inline std::map<std::string, StructMemberSectionSource>
find_struct_member_section_sources(
                const ASR::GpuKernelFunction_t &kernel) {
    std::map<std::string, StructMemberSectionSource> result;

    // Build assoc_map: Associate target names -> associated expressions.
    std::map<std::string, ASR::expr_t*> assoc_map;
    for (size_t si = 0; si < kernel.n_body; si++) {
        if (kernel.m_body[si]->type == ASR::stmtType::Associate) {
            ASR::Associate_t *assoc =
                ASR::down_cast<ASR::Associate_t>(kernel.m_body[si]);
            if (ASR::is_a<ASR::Var_t>(*assoc->m_target)) {
                std::string tname = ASRUtils::symbol_name(
                    ASR::down_cast<ASR::Var_t>(
                        assoc->m_target)->m_v);
                assoc_map[tname] = assoc->m_value;
            }
        }
    }

    for (size_t si = 0; si < kernel.n_body; si++) {
        ASR::stmt_t *stmt = kernel.m_body[si];
        if (stmt->type != ASR::stmtType::Assignment) continue;
        ASR::Assignment_t *asgn =
            ASR::down_cast<ASR::Assignment_t>(stmt);

        // Case 1: arr(i) = StructConstructor(t, [arg])
        if (ASR::is_a<ASR::ArrayItem_t>(*asgn->m_target) &&
                ASR::is_a<ASR::StructConstructor_t>(
                    *asgn->m_value)) {
            ASR::ArrayItem_t *ai =
                ASR::down_cast<ASR::ArrayItem_t>(asgn->m_target);
            if (!ASR::is_a<ASR::Var_t>(*ai->m_v)) continue;
            std::string arr_name = ASRUtils::symbol_name(
                ASR::down_cast<ASR::Var_t>(ai->m_v)->m_v);
            ASR::StructConstructor_t *sc =
                ASR::down_cast<ASR::StructConstructor_t>(
                    asgn->m_value);
            ASR::symbol_t *struct_sym =
                ASRUtils::symbol_get_past_external(sc->m_dt_sym);
            if (!ASR::is_a<ASR::Struct_t>(*struct_sym)) continue;
            ASR::Struct_t *st =
                ASR::down_cast<ASR::Struct_t>(struct_sym);
            for (size_t mi = 0;
                    mi < st->n_members && mi < sc->n_args; mi++) {
                if (!sc->m_args[mi].m_value) continue;
                ASR::symbol_t *mem =
                    st->m_symtab->get_symbol(st->m_members[mi]);
                if (!mem || !ASR::is_a<ASR::Variable_t>(*mem))
                    continue;
                ASR::Variable_t *mv =
                    ASR::down_cast<ASR::Variable_t>(mem);
                if (!ASRUtils::is_allocatable(mv->m_type)) continue;
                std::string key =
                    arr_name + "." + st->m_members[mi];
                if (result.count(key)) continue;
                ASR::expr_t *arg = sc->m_args[mi].m_value;
                ASR::expr_t *inner =
                    unwrap_array_physical_cast(arg);
                if (ASR::is_a<ASR::Var_t>(*inner)) {
                    std::string vn = ASRUtils::symbol_name(
                        ASR::down_cast<ASR::Var_t>(inner)
                            ->m_v);
                    auto ait = assoc_map.find(vn);
                    if (ait != assoc_map.end())
                        inner = unwrap_array_physical_cast(
                            ait->second);
                }
                if (ASR::is_a<ASR::ArraySection_t>(*inner)) {
                    StructMemberSectionSource src;
                    if (get_runtime_section_source(
                            ASR::down_cast<ASR::ArraySection_t>(
                                inner), src)) {
                        result[key] = src;
                    }
                }
            }
            continue;
        }

        // Case 2: Lowered StructConstructor pattern:
        //   arr(i)%member = Var (where Var is associated with
        //   an ArraySection)
        if (!ASR::is_a<ASR::StructInstanceMember_t>(
                *asgn->m_target)) continue;
        ASR::StructInstanceMember_t *sim =
            ASR::down_cast<ASR::StructInstanceMember_t>(
                asgn->m_target);
        // Extract member name
        std::string mem_name = ASRUtils::symbol_name(
            ASRUtils::symbol_get_past_external(sim->m_m));
        // Check if the member is allocatable
        if (!ASR::is_a<ASR::Variable_t>(
                *ASRUtils::symbol_get_past_external(sim->m_m)))
            continue;
        ASR::Variable_t *mv = ASR::down_cast<ASR::Variable_t>(
            ASRUtils::symbol_get_past_external(sim->m_m));
        if (!ASRUtils::is_allocatable(mv->m_type)) continue;
        // Extract the array name from the base (arr(i))
        if (!ASR::is_a<ASR::ArrayItem_t>(*sim->m_v)) continue;
        ASR::ArrayItem_t *ai =
            ASR::down_cast<ASR::ArrayItem_t>(sim->m_v);
        if (!ASR::is_a<ASR::Var_t>(*ai->m_v)) continue;
        std::string arr_name = ASRUtils::symbol_name(
            ASR::down_cast<ASR::Var_t>(ai->m_v)->m_v);
        std::string key = arr_name + "." + mem_name;
        if (result.count(key)) continue;
        // Resolve RHS through Associate
        ASR::expr_t *rhs =
            unwrap_array_physical_cast(asgn->m_value);
        if (ASR::is_a<ASR::Var_t>(*rhs)) {
            std::string vn = ASRUtils::symbol_name(
                ASR::down_cast<ASR::Var_t>(rhs)->m_v);
            auto ait = assoc_map.find(vn);
            if (ait != assoc_map.end())
                rhs = unwrap_array_physical_cast(ait->second);
        }
        if (ASR::is_a<ASR::ArraySection_t>(*rhs)) {
            StructMemberSectionSource src;
            if (get_runtime_section_source(
                    ASR::down_cast<ASR::ArraySection_t>(rhs),
                    src)) {
                result[key] = src;
            }
        }
    }
    return result;
}

} // namespace LCompilers

#endif // LFORTRAN_GPU_UTILS_H
