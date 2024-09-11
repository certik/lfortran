cmake \
    -DCMAKE_BUILD_TYPE=Debug \
    -DWITH_LLVM=yes \
    -DCMAKE_PREFIX_PATH="$CONDA_PREFIX" \
    .
#cmake --build . -j16
