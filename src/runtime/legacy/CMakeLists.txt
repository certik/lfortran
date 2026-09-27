set(SRC
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../src/libasr/runtime/lfortran_intrinsics.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../src/libasr/runtime/lcompilers_init.c
)

# One object file for each WebAssembly runtime, which the driver links as is.
# It includes the runtime sources, so it is rebuilt when any of them or the
# headers they share change.
set(WASM_SRC
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../src/libasr/runtime/lfortran_runtime_wasm.c
)
set(WASM_DEPENDS
    ${WASM_SRC}
    ${SRC}
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../src/libasr/runtime/lfortran_intrinsics.h
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../src/libasr/runtime/lcompilers_init.h
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../src/libasr/runtime/lcompilers_init_abi.h
)

if(WIN32)
  set(MATH_LIBRARIES "" CACHE STRING "math library")
else()
  set(MATH_LIBRARIES "m" CACHE STRING "math library")
endif()
mark_as_advanced( MATH_LIBRARIES )

add_library(lfortran_runtime SHARED ${SRC})
target_include_directories(lfortran_runtime BEFORE PUBLIC ${libasr_SOURCE_DIR}/..)
target_include_directories(lfortran_runtime BEFORE PUBLIC ${libasr_BINARY_DIR}/..)
target_link_libraries(lfortran_runtime PRIVATE ${MATH_LIBRARIES} ${CMAKE_DL_LIBS})
if (HAVE_INTERNAL_ALLOC_CHECK)
    target_compile_definitions(lfortran_runtime PRIVATE LFORTRAN_INTERNAL_ALLOC_CHECK)
endif()
set_target_properties(lfortran_runtime PROPERTIES
  VERSION ${PROJECT_VERSION}
  SOVERSION ${PROJECT_VERSION_MAJOR})
set_target_properties(lfortran_runtime PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY ..)

add_library(lfortran_runtime_static STATIC ${SRC})
target_include_directories(lfortran_runtime_static BEFORE PUBLIC ${libasr_SOURCE_DIR}/..)
target_include_directories(lfortran_runtime_static BEFORE PUBLIC ${libasr_BINARY_DIR}/..)
target_link_libraries(lfortran_runtime_static PRIVATE ${MATH_LIBRARIES} ${CMAKE_DL_LIBS})
if (HAVE_INTERNAL_ALLOC_CHECK)
    target_compile_definitions(lfortran_runtime_static PRIVATE LFORTRAN_INTERNAL_ALLOC_CHECK)
endif()
set_target_properties(lfortran_runtime_static PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ..)

if(WITH_TARGET_WASM)

    if ((NOT (DEFINED ENV{EMSDK_PATH})) AND (NOT (DEFINED ENV{WASI_SDK_PATH})))
        message(FATAL_ERROR "Atleast one of `EMSDK_PATH` or `WASI_SDK_PATH` must be available to target `WASM`")
    endif()

    if (DEFINED ENV{EMSDK_PATH})
        add_custom_command(OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_emcc.o
            COMMAND $ENV{EMSDK_PATH}/upstream/emscripten/emcc -I${libasr_SOURCE_DIR}/.. -I${libasr_BINARY_DIR}/.. -DCOMPILE_TO_WASM
                -c --target=wasm32-unknown-emscripten ${WASM_SRC} -o ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_emcc.o
            COMMENT "Cross compiling the runtime to ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_emcc.o"
            DEPENDS ${WASM_DEPENDS})
        add_custom_target(lfortran_runtime_wasm_emcc ALL DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_emcc.o)
        install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_emcc.o
            DESTINATION ${CMAKE_INSTALL_LIBDIR})
        install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_emcc.o
            DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/..)
    endif()

    if (DEFINED ENV{WASI_SDK_PATH})
        add_custom_command(OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_wasi.o
            COMMAND $ENV{WASI_SDK_PATH}/bin/clang -I${libasr_SOURCE_DIR}/.. -I${libasr_BINARY_DIR}/.. -DCOMPILE_TO_WASM
                -D_WASI_EMULATED_PROCESS_CLOCKS -c --target=wasm32-wasi ${WASM_SRC} -o ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_wasi.o
            COMMENT "Cross compiling the runtime to ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_wasi.o"
            DEPENDS ${WASM_DEPENDS})
        add_custom_target(lfortran_runtime_wasm_wasi ALL DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_wasi.o)
        install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_wasi.o
            DESTINATION ${CMAKE_INSTALL_LIBDIR})
        install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_wasi.o
            DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/..)
    endif()
endif()

install(TARGETS lfortran_runtime_static
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

install(TARGETS lfortran_runtime
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# Install the header
install(
    FILES ../../../src/libasr/runtime/lfortran_intrinsics.h
        ../../../src/libasr/runtime/lcompilers_init.h
        ../../../src/libasr/runtime/lcompilers_init_abi.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/lfortran/impure
)

install(
    FILES ../../../src/libasr/runtime/ISO_Fortran_binding.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/lfortran
)
