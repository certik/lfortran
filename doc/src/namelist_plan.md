# Namelist End-to-End Plan (ASR -> LLVM -> Runtime)

## Goals
- Support Fortran namelist I/O end-to-end in the LLVM backend.
- Reuse existing ASR (Namelist symbol, FileRead/FileWrite with `nml`).
- Implement a small, explicit, and robust runtime API to read/write namelist groups.
- Add comprehensive integration tests that exercise read + write paths.

## Non-goals (initial scope)
- Unformatted namelist I/O (namelist is formatted by standard).
- Derived-type components in namelists (defer until scalar/array intrinsic types work).
- Complex user-defined formatting or locale features.

## Current State (quick inventory)
- ASR has `Namelist` symbols and `FileRead`/`FileWrite` include `nml` field.
- No lowering in `src/libasr/codegen/asr_to_llvm.cpp` for `m_nml`.
- Runtime is in `src/libasr/runtime/lfortran_intrinsics.{h,c}` with formatted read/write utilities.
- Integration test `integration_tests/namelist_02.f90` only produces ASR.

## Runtime API Design

### Types
Introduce a small, explicit descriptor for namelist items and groups:

```c
// src/libasr/runtime/lfortran_intrinsics.h

typedef enum {
    LFORTRAN_NML_INT1,
    LFORTRAN_NML_INT2,
    LFORTRAN_NML_INT4,
    LFORTRAN_NML_INT8,
    LFORTRAN_NML_REAL4,
    LFORTRAN_NML_REAL8,
    LFORTRAN_NML_LOGICAL1,
    LFORTRAN_NML_LOGICAL2,
    LFORTRAN_NML_LOGICAL4,
    LFORTRAN_NML_LOGICAL8,
    LFORTRAN_NML_COMPLEX4,
    LFORTRAN_NML_COMPLEX8,
    LFORTRAN_NML_CHAR
} lfortran_nml_type_t;

typedef struct {
    const char *name;          // lower-case, null-terminated
    lfortran_nml_type_t type;
    int32_t rank;              // 0 for scalar
    int64_t elem_len;          // for character (len), else 0
    void *data;                // scalar ptr or base address of array
    const int64_t *shape;      // rank-sized array of extents (Fortran order)
} lfortran_nml_item_t;

typedef struct {
    const char *group_name;    // lower-case, null-terminated
    int32_t n_items;
    lfortran_nml_item_t *items;
} lfortran_nml_group_t;
```

### Functions
Two entrypoints, keeping the interface minimal and consistent with existing I/O APIs:

```c
// src/libasr/runtime/lfortran_intrinsics.h
LFORTRAN_API void _lfortran_namelist_write(
    int32_t unit_num,
    int32_t *iostat,
    const lfortran_nml_group_t *group
);

LFORTRAN_API void _lfortran_namelist_read(
    int32_t unit_num,
    int32_t *iostat,
    lfortran_nml_group_t *group
);
```

### Runtime Behavior (write)
- Emit `&group_name` and `/` (or `&end`) with variables in between.
- Use lower-case names, but accept/emit canonical case.
- Scalars: `name = value`.
- Arrays: `name = v1, v2, v3` in Fortran order.
- Character values are quoted using `'` with escaping for embedded quotes.
- Logical: `.true.`/`.false.`.
- Use existing `_lfortran_file_write` for actual output formatting.

### Runtime Behavior (read)
- Parse namelist input:
  - Accept leading `&group` or `$group` and terminating `/` or `&end`.
  - Ignore whitespace and handle comments (`!`).
  - Case-insensitive for group and variable names.
  - For arrays, accept list values (comma-separated) and assign in Fortran order.
- Use existing `_lfortran_string_read_*` helpers to parse tokens into values.
- Return errors via `iostat` (if non-null) instead of terminating.

### Error Handling
- Unknown group name or variable name -> `iostat` nonzero.
- Missing `&group` or terminator -> `iostat` nonzero.
- Type mismatch or too many values -> `iostat` nonzero.

## LLVM Lowering Plan

### 1) Build namelist descriptors in `asr_to_llvm.cpp`
- In `visit_FileRead` / `visit_FileWrite`, detect `x.m_nml`.
- Resolve the `ASR::Namelist_t` symbol and collect the ordered `var_list`.
- For each variable, emit:
  - Name as global constant string (lower-case).
  - Type code (`lfortran_nml_type_t`).
  - Rank, shape array (for arrays), and element length for `character`.
  - Data pointer (address of variable or array base).
- Emit a `lfortran_nml_item_t[]` constant and a `lfortran_nml_group_t` struct.

### 2) Call runtime entrypoints
- For `FileWrite` with `nml`:
  - Ignore `fmt`, `separator`, `end` (namelist formatting is fixed).
  - Call `_lfortran_namelist_write(unit, iostat, &group)`.
- For `FileRead` with `nml`:
  - Call `_lfortran_namelist_read(unit, iostat, &group)`.

### 3) Internal files (optional, phase 2)
- If `unit` is an internal file expression, define a second API:
  - `_lfortran_namelist_read_str(char *buf, int64_t len, int32_t *iostat, lfortran_nml_group_t *group)`.
- Implement only after external-unit version is stable.

## Tests (Integration)

### Add new end-to-end test
Create `integration_tests/namelist_03.f90` with both write and read:
- Define scalars and arrays of integer/real/logical/character.
- Write a namelist to a file, close, reopen, read into fresh variables.
- Verify values (including arrays and character) and `error stop` on mismatch.
- Register in `integration_tests/CMakeLists.txt` with labels: `gfortran` and `llvm`.

### Example assertions (within the test)
- After read, check:
  - scalar equality
  - array elements
  - trimmed character equality
  - logical value

### Extend existing ASR-only test
- Keep `integration_tests/namelist_02.f90` for ASR coverage.
- Add `namelist_03.f90` for end-to-end runtime coverage.

## Work Breakdown

1) **Runtime API scaffolding**
- Add types and prototypes to `src/libasr/runtime/lfortran_intrinsics.h`.
- Implement in `src/libasr/runtime/lfortran_intrinsics.c`.
- Keep parsing/printing self-contained and reuse string-read helpers.

2) **LLVM codegen**
- Extend `visit_FileRead` / `visit_FileWrite` in `src/libasr/codegen/asr_to_llvm.cpp`.
- Generate `lfortran_nml_item_t`/`lfortran_nml_group_t` structures.
- Ensure correct lowering for scalars, arrays, and characters.

3) **Integration tests**
- Add `integration_tests/namelist_03.f90`.
- Register via `RUN(NAME namelist_03 LABELS gfortran llvm ...)`.

4) **Validation**
- `cd integration_tests && ./run_tests.py -b llvm -t namelist_03`.
- `cd integration_tests && ./run_tests.py -b gfortran -t namelist_03`.

## Questions and Answers
- Should namelist parsing accept list-directed numeric forms already supported by `_lfortran_string_read_*`?
A: Whatever is the easiest for the initial implementation. If it is complex,
we'll do it later.

- How to handle arrays with explicit subscripts in namelist input (e.g., `a(2)=3`)?
A: Let's handle that later.

- Should internal file namelist I/O be implemented in phase 2 or deferred?
A: Deferred.
