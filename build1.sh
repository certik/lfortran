cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_LLVM=yes \
    -DWITH_STACKTRACE=no \
    -DCMAKE_PREFIX_PATH="$CONDA_PREFIX" \
    .
cmake --build . --config Release -j16
