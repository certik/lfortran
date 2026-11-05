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

## Next

1. Match Flang with the unchanged Fortran source, by comparing the generated
   code of `advance`.
2. Then change the Fortran source, within the rules of the benchmark, to
   reach the C++ time.
