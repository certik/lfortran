#ifndef LIBASR_PASS_RECURSION_ANALYSIS_H
#define LIBASR_PASS_RECURSION_ANALYSIS_H

#include <libasr/asr.h>
#include <libasr/utils.h>

namespace LCompilers {

    void pass_recursion_analysis(Allocator &al, ASR::TranslationUnit_t &unit,
                                 const PassOptions &pass_options);

} // namespace LCompilers

#endif // LIBASR_PASS_RECURSION_ANALYSIS_H
