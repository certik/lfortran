cmake \
    -DCMAKE_BUILD_TYPE=Debug \
    -DWITH_LLVM=yes \
    -DWITH_STACKTRACE=no \
    -DCMAKE_PREFIX_PATH="$CONDA_PREFIX" \
    .
cmake --build . -j16
