#ifndef LIBASR_PASS_GPU_OFFLOAD_LIVEOUT_H
#define LIBASR_PASS_GPU_OFFLOAD_LIVEOUT_H

#include <set>
#include <string>

#include <libasr/asr.h>

namespace LCompilers {

// The one element of the buffer a scalar whose value is kept after a
// parallel loop is handed to the kernel in, and handed back in.
ASR::expr_t* gpu_liveout_slot(Allocator &al, const Location &loc,
    ASR::symbol_t *buffer, ASR::ttype_t *scalar_type);

// The variables (past use association) that may be referenced once the
// parallel loop `loop` has run: by a statement of the procedure (or main
// program) that holds it -- the statements after it, in the statement list
// that holds it and in each construct around it, and every other statement
// of a loop around it, which can run again -- or by a procedure it
// contains, which a later statement may call, and every variable whose
// address the procedure takes (EQUIVALENCE, pointer association). When a
// GO TO after the loop jumps back to a label before it, which can run the
// loop and whatever follows it again, `everything` is set instead.
std::set<ASR::symbol_t*> gpu_variables_referenced_after_loop(
    const ASR::OMPRegion_t &loop, SymbolTable *scope, bool &everything);

// Whether the value a parallel loop in `scope` gives the variable `sym`
// can be read once the procedure (or main program) holding the loop has
// returned, or by another procedure or through another name: it is a dummy
// argument or the function result, it is saved, it belongs to a module, a
// host procedure or a common block, it is a TARGET or VOLATILE, or it is a
// pointer, whose target any name may read.
bool gpu_visible_outside_procedure(ASR::symbol_t *sym, SymbolTable *scope);

// Whether `name`, of type `type`, is a derived-type variable that the kernel
// cannot hold as a local of its own: its type has allocatable or pointer
// parts and a derived-type component, which that lowering does not handle
// yet. Each thread keeps private copies of parts of it instead, as of a
// variable whose value is kept after the loop.
bool gpu_no_kernel_local_struct(SymbolTable *scope,
    const std::string &name, ASR::ttype_t *type);

} // namespace LCompilers

#endif // LIBASR_PASS_GPU_OFFLOAD_LIVEOUT_H
