# Benchmarks Game n-body: initial measurements

This directory tracks LFortran against the fastest solutions to the
[Benchmarks Game n-body benchmark](https://benchmarksgame-team.pages.debian.net/benchmarksgame/performance/nbody.html).
The program simulates the Jovian planets for N steps, N = 50,000,000 in the
official runs, and prints the initial and final energy.

The C++ solution (`nbody.gpp-0.cpp`, g++ #0) is the fastest on this machine
and is the target. The Fortran solution (`nbody.ifx-5.f90`, Intel Fortran #5)
is compiled with LFortran, Flang and GFortran.

## Sources

| File | Origin |
|---|---|
| `nbody.gpp-0.cpp` | C++ g++ #0, contributed by Miles for C and ported to C++ by François-David Collin (3-Clause BSD) |
| `nbody.ifx-5.f90` | Intel Fortran #5, contributed by Simon Geard, Brian Taylor and yuankun shi (3-Clause BSD) |

The C gcc #9 and Rust #9 solutions were measured from the pages linked below
but are not committed here:

- C gcc #9: <https://benchmarksgame-team.pages.debian.net/benchmarksgame/program/nbody-gcc-9.html>
- Rust #9: <https://benchmarksgame-team.pages.debian.net/benchmarksgame/program/nbody-rust-9.html>

## Setup

- AMD Ryzen 9 9955HX (Zen 5), one pinned core (`taskset -c 17`), shared
  machine (load average around 12 during the runs).
- N = 50,000,000, best of 5 interleaved runs.
- Every binary targets the host (`-march=native` / `-C target-cpu=native`);
  the Fortran builds use fast math.
- Compilers: gcc/g++ 15.3.0, rustc 1.99.1, flang 23.1.4, gfortran 16.2.0,
  LFortran `--fast` (LLVM 11.1.0).
- Every binary prints the same two energies: `-0.169075164` and
  `-0.169059907`.

## Initial results

| Solution | Build | secs | ratio | site secs |
|---|---|---:|---:|---:|
| C gcc #9 | `gcc -O3 -fomit-frame-pointer -march=native` | 1.125 | 1.02 | 2.10 |
| **C++ g++ #0** | `g++ -O3 -fomit-frame-pointer -march=native -std=c++17` | **1.098** | **1.00** | 2.15 |
| Rust #9 | `rustc -C opt-level=3 -C target-cpu=native -C codegen-units=1` | 1.132 | 1.03 | 2.19 |
| Flang 23.1.4 | `-O3 -march=native -ffast-math` | 1.740 | 1.58 | 3.39 (ifx #5) |
| LFortran `--fast` | `--fast` | 2.030 | 1.85 | |
| GFortran 16.2 | `-O3 -march=native -ffast-math` | 3.383 | 3.08 | |

The three C-family solutions are effectively tied on this machine (within
3%, which is run-to-run noise). Flang is the fastest Fortran compiler,
LFortran trails it by about 17%, and GFortran is far behind. The site's
absolute times are from different hardware; only the relative ordering is
comparable.

## Reproduce

```bash
g++ -O3 -fomit-frame-pointer -march=native -std=c++17 \
    nbody.gpp-0.cpp -o nbody.gpp0
flang -O3 -march=native -ffast-math nbody.ifx-5.f90 -o nbody.flang
gfortran -O3 -march=native -ffast-math nbody.ifx-5.f90 -o nbody.gfortran
lfortran --fast nbody.ifx-5.f90 -o nbody.lfortran

taskset -c 17 ./nbody.gpp0 50000000
```

## First codegen result

The `do m = 1, N` loop in `advance` was not vectorized: inlining wraps the
`real(d2)` conversion in a BLOCK, and the code generator emitted
`llvm.stacksave`/`llvm.stackrestore` around it. Those calls cannot be crossed
by the vectorizer, so the ten pairs stayed scalar while Flang vectorized the
loop to `llvm.sqrt.v4f32`.

Fixed-size BLOCK allocas are now moved to the function entry, and the stack
save/restore is emitted only when a dynamically sized alloca remains. The
loop vectorizes (four `llvm.sqrt.v4f32` calls, no stack save). Same machine
and method as above, in one interleaved run:

| Compiler | secs | vs C++ |
|---|---:|---:|
| **C++ g++ #0** | **1.117** | 1.00 |
| Flang 23.1.4 | 1.710 | 1.53 |
| LFortran `--fast`, before | 1.881 | 1.68 |
| LFortran `--fast`, after | 1.851 | 1.66 |
| GFortran 16.2 | 3.224 | 2.89 |

LFortran was now about 8% behind Flang instead of 17%. The remaining
difference turned out to be the CPU model, not the loop shape: with LLVM 11,
`--mcpu=native` reports `generic` for Zen 5, and the generic cost model
prefers 512-bit vectors, while the known models use 256-bit vectors, which
are faster for this small loop. `--fast` now maps an unrecognized AVX-512
host to `skylake-avx512` and an AVX2 host to `haswell`, keeping the detected
features.

Final result with plain `--fast` (quiet machine, best of 6 interleaved runs):

| Compiler | secs | vs C++ |
|---|---:|---:|
| **C++ g++ #0** | **0.956** | 1.00 |
| LFortran `--fast` | 1.413 | 1.48 |
| Flang 23.1.4 | 1.456 | 1.52 |
| GFortran 16.2 | 2.763 | 2.89 |

LFortran now beats Flang by about 3% on the unchanged source. The CPU model
also explains the other measurements: `--mcpu=znver2` gives 1.408 s, while
the old generic-resolved build took 1.6 to 1.7 s.

## Matching the C++ source

`nbody_opt.f90` restructures the Intel Fortran source after the C++ g++ #0
solution: the ten pairs are four-element vectors in `r(4, PAIRS)`, the five
bodies are four-element vectors in `x(4, NB)` and `v(4, NB)`, the pair
indices are compile-time constants so the ten pairs unroll, and each
component loop runs over the four slots, which maps to one 256-bit
operation. Same batch, best of 8:

| Compiler / source | secs | vs C++ |
|---|---:|---:|
| **C++ g++ #0** | **1.013** | 1.00 |
| LFortran `--fast`, `nbody_opt.f90` | 1.084 | 1.07 |
| LFortran `--fast`, exact ifx source | 1.523 | 1.50 |
| Flang, exact ifx source | 1.566 | 1.55 |

The remaining gap is LLVM 11's code generation, not the CPU model: the same
C++ built with `-march=skylake-avx512` is still 0.959 s, so GCC's register
allocation and horizontal reduction are better than LLVM's. GCC keeps the
body and pair vectors in `ymm` registers and reduces with `vhaddpd`; LLVM 11
vectorizes the flat loops with `vpermt2pd`/`vunpck*` and keeps part of the
state in memory (145 vs 120 instructions per step). The quietest batch
measures C++ 0.959 s against `nbody_opt.f90` 1.018 s, 6% behind.

LLVM 23 is not an alternative here: its new pass manager does not vectorize
these small loops at all, and the same source takes about 2.0 s.

## Next

1. Teach the vectorizer to form a four-wide load with a horizontal
   reduction (`llvm.vector.reduce.fadd`) for small unrolled pair loops, and
   keep the body/pair arrays in registers, to match GCC's loop.
