#!/usr/bin/env bash

set -e
set -x

export CC=x86_64-conda-linux-gnu-gcc
export CXX=x86_64-conda-linux-gnu-g++

cmake \
    -DCMAKE_BUILD_TYPE=Debug \
    -DWITH_LLVM=yes \
    -DLFORTRAN_BUILD_ALL=yes \
    -DWITH_STACKTRACE=yes \
    -DWITH_RUNTIME_STACKTRACE=yes \
    -DWITH_LSP=no \
    -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH_LFORTRAN;$CONDA_PREFIX" \
    -DCMAKE_INSTALL_LIBDIR=share/lfortran/lib \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=yes \
    -DCMAKE_C_FLAGS="${CFLAGS} -fdiagnostics-color=always" \
    -DCMAKE_CXX_FLAGS="${CXXFLAGS} -fdiagnostics-color=always" \
-G Ninja \
    .
cmake --build .
