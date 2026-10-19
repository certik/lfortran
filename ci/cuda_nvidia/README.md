# Running LFortran's CUDA backend on NVIDIA hardware

This directory holds the recipe used to validate `--gpu=cuda` on a real NVIDIA
GPU: LFortran's own GPU integration tests, and the BerkeleyLab
[Formal](https://github.com/BerkeleyLab/formal) library and its 2D
advection-diffusion example. `run_formal_cuda.sh` performs every step below and
prints a summary; the sections explain what it does and how to run the pieces
by hand.

Validated on: NVIDIA RTX PRO 6000 Blackwell Server Edition (compute capability
12.0, `sm_120`), driver 610.43.02, CUDA 13.3 (`/usr/local/cuda`), Ubuntu 24.04,
Pixi `llvm11` environment (LLVM 11.1.0, conda-forge GCC 15.3 as nvcc's host
compiler).

## Prerequisites

- An NVIDIA driver and a CUDA toolkit with `nvcc` on `PATH`
  (`export PATH=/usr/local/cuda/bin:$PATH`). `cuobjdump`, `nsys` and
  `compute-sanitizer` from the same toolkit are used for evidence when present.
- Git and [Pixi](https://pixi.sh). Everything else (LLVM 11, the host C/C++
  compilers, FPM, GFortran 16) comes from Pixi environments.
- If `pixi shell` does not work in your shell, prefix commands with
  `eval "$(pixi shell-hook -e llvm11)"` or use `pixi run -e llvm11 ...`.

## 1. Build LFortran

From the root of this checkout:

```bash
CMAKE_BUILD_PARALLEL_LEVEL=16 pixi run -e llvm11 build \
    '-DCMAKE_CXX_FLAGS_DEBUG=-g -O2' '-DCMAKE_C_FLAGS_DEBUG=-g -O2' > build.log 2>&1
pixi run -e llvm11 bash -c 'command -v lfortran; lfortran --version; command -v nvcc'
```

`lfortran` must resolve to `build/llvm11/src/bin/lfortran` of this checkout.

## 2. Quick check

```bash
cat > saxpy.f90 <<'EOF'
program saxpy
implicit none
integer, parameter :: n = 10000000
real, allocatable :: x(:), y(:)
real :: a
integer :: i
allocate(x(n), y(n))
a = 2.0; x = 1.0; y = 3.0
do concurrent (i = 1:n)
    y(i) = a*x(i) + y(i)
end do
if (abs(y(1) - 5.0) > 1e-6 .or. abs(y(n) - 5.0) > 1e-6) error stop "wrong result"
print *, "OK"
end program
EOF
pixi run -e llvm11 lfortran --gpu=cuda saxpy.f90 -o saxpy_gpu
CUDA_DISABLE_PTX_JIT=1 ./saxpy_gpu          # prints OK
cuobjdump --list-elf --list-ptx saxpy_gpu   # sm_120 cubins on this GPU
```

GPU options:

- `--gpu=cuda` compiles the device code with nvcc and runs it on the GPU.
  `--gpu=cuda_cpu` compiles the same device code as host C++ and runs it on
  the CPU (no GPU needed; this is what CI runs).
- `--gpu-arch=<arch>` selects the GPU architecture, e.g. `sm_120`. The default
  is `native`, the GPUs of the compiling machine. On a machine without a GPU
  nvcc then falls back to its oldest default architecture with a warning, so
  pass an explicit architecture when cross-compiling.
- `--device-compiler=<path>` selects nvcc (or, for `cuda_cpu`, the host C++
  compiler).
- `--show-gpu-kernel-source` prints the generated `.cu` source.
- `CUDA_DISABLE_PTX_JIT=1` at run time makes a binary built for the wrong
  architecture fail instead of being JIT compiled by the driver.

## 3. LFortran GPU integration tests on the GPU

```bash
CUDA_DISABLE_PTX_JIT=1 pixi run -e llvm11 integration_tests -b cuda -j16 > cuda.log 2>&1
grep 'tests passed' cuda.log
```

Every test labeled `cuda_cpu` that passes on a real GPU also carries the `cuda`
label (485 tests on this branch). CI has no NVIDIA GPU and runs only
`-b cuda_cpu`, so run this on GPU machines after changing GPU code.

## 4. Formal

```bash
ci/cuda_nvidia/run_formal_cuda.sh /path/to/work-dir > formal.log 2>&1
tail -40 formal.log
```

The script clones Formal at the validated revision (`FORMAL_REF`, the head of
BerkeleyLab/formal#71, which contains #70), then, with logs in
`<work-dir>/logs` and data in `<work-dir>/validation`:

1. Builds and runs Formal's FPM test suite and both solvers with
   `--gpu=cuda_cpu` (expect 32/32 tests, 0 skipped).
2. The same with native `--gpu=cuda --gpu-arch=native` and
   `CUDA_DISABLE_PTX_JIT=1`, in a separate build directory.
3. Builds three executables of the example: native GPU, ordinary host LLVM,
   and GFortran 16 as an independent oracle.
4. Compares full fields from a shared raw input:
   - a 17x13, 9-step Gaussian case, native against host LLVM, with Formal's
     `validate_2d_advection_workspace.py`;
   - a nonsquare 13x11, 3-step case with nonzero, non-smooth boundaries
     (`make_boundary_input.py`), native against GFortran and host LLVM, with
     Formal's strict `compare_2d_raw_fields.py` (finite fields, evolution,
     unchanged boundaries, default tolerances).
5. Records evidence of native execution: `cuobjdump` of the executable, `nsys`
   kernel/transfer summaries, and `compute-sanitizer` memcheck, racecheck,
   synccheck and initcheck on both solvers.
6. Runs `integration_tests -b cuda` (step 3 above).

Environment overrides: `GPU_ARCH` (e.g. `sm_120`), `JOBS`, `FORMAL_REF`,
`SKIP_PROFILE=1`, `SKIP_LFORTRAN_TESTS=1`.

Notes on the recipe:

- Keep all Fortran flags in a single FPM `--flag` argument.
- `--input` supplies the grid, step count and time step, so Formal rejects it
  together with `--cells`, `--steps` or `--dt`; and only the workspace solver
  accepts `--input`.
- `formal/benchmarks/pixi.toml` only lists `osx-arm64`; `fpm/pixi.toml` here
  pins the same FPM (0.13.0) for Linux.
- Formal needs GFortran 16 (its README asks for 16.3+); conda-forge's 16.2
  builds it with `-fcoarray=single`. `gfortran16/pixi.toml` provides it.
- `nsys` and `compute-sanitizer` need a writable `TMPDIR`; the script uses
  `<work-dir>/tmp` (a shared `/tmp/nvidia` can belong to another user).
- The operators solver cannot read a raw input, so its initial field is
  computed by each build. GPU `sinf`/`expf` and the host math libraries round
  differently (host LLVM and GFortran differ as well), at the 1e-7 level, so
  that path is compared against its own initial state rather than bitwise
  across builds.

## Results on the validation machine

| Check | Result |
|---|---|
| Formal tests, `cuda_cpu` | 32/32, 0 skipped |
| Formal tests, native CUDA, PTX JIT disabled | 32/32, 0 skipped |
| Embedded device code | `sm_120` cubins only |
| Gaussian 17x13/9, native vs host LLVM | max abs 1.2e-10, relative L2 7.9e-11 |
| Boundary 13x11/3, native vs GFortran 16 vs host LLVM | bitwise identical; boundaries fixed; field evolves |
| compute-sanitizer (4 tools x 2 solvers) | 0 errors |
| nsys, workspace solver | all arithmetic in kernels; transfers constant in the step count |
| `integration_tests -b cuda` | all pass |

Known limitation: the operators solver runs every kernel on the GPU, but
LFortran synchronizes at each procedure exit and re-uploads data per launch,
and part of its arithmetic is host array expressions, so most of its time is
host work and transfers. The workspace solver is fully device resident.
