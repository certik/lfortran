#ifndef LIBASR_PASS_GPU_TIME_SKEW_H
#define LIBASR_PASS_GPU_TIME_SKEW_H

#include <libasr/asr.h>
#include <libasr/utils.h>

namespace LCompilers {

    // Runs the parallel loops assigned to the device inside a sequential
    // (time) loop band by band, a few iterations of the time loop at a
    // time, so that a band stays in the device's cache across them, when
    // the arrays they touch do not fit in it. See gpu_time_skew.cpp.
    void pass_gpu_time_skew(Allocator &al, ASR::TranslationUnit_t &unit,
                            const PassOptions &pass_options);

} // namespace LCompilers

#endif // LIBASR_PASS_GPU_TIME_SKEW_H
