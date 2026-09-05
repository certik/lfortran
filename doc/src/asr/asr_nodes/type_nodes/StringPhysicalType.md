# string_physical_type

How a string is represented in memory.

## Declaration

### Syntax

```text
string_physical_type = DescriptorString | CChar | HiddenLenString
```

### Values

| Value | Meaning |
|----------|-------------|
| `DescriptorString` | a descriptor, `{char* data, int64 size, int64 capacity}`. The length and the capacity travel with the data, so the value can be reallocated and its length asked for. |
| `CChar` | a bare `char*`, the representation C uses and the one the string runtime functions take. |
| `HiddenLenString` | the classic Fortran external ABI, the one gfortran and flang use for a CHARACTER dummy: the `char*` data pointer at the argument position and the per-element length as a hidden `int64` argument after all positional arguments, one per such dummy in argument order. |

### Return values

None. An enumeration value is not evaluated.

## Description

The physical type is separate from the logical type: both representations hold
the same characters.
[StringPhysicalCast](../expression_nodes/StringPhysicalCast.md) moves between
them, taking the `data` pointer out of a descriptor in one direction and
wrapping a pointer in a descriptor with `size` and `capacity` set to `-1` in
the other, marking a string that must not be extended.

A local variable may not have the `CChar` physical type: the verifier rejects
it, because a local string owns its storage and needs a descriptor to describe
it.

`HiddenLenString` is how a separately compiled external procedure receives a
CHARACTER dummy: its caller and its definition are linked without either
seeing the other's ASR, so both have to use the one ABI neither can negotiate.
The frontend gives it to the CHARACTER dummies of a subprogram defined at the
top level and of an interface body in a plain interface block, and to the
dummies it synthesizes for an implicit interface; an `abstract interface`, a
dummy procedure, a `module` procedure and a `bind(c)` procedure keep their own
conventions. The ABI carries a scalar or a contiguous explicit-shape or
assumed-size array, so the verifier only allows the physical type on a dummy
argument that is not allocatable or a pointer, and on an array only with the
`PointerArray` or `UnboundedPointerArray` array physical type; assumed-shape
and allocatable dummies need an explicit interface and keep the descriptor.
A call passes exactly the string physical type the dummy declares, so the
frontend wraps an actual of another physical type in a
[StringPhysicalCast](../expression_nodes/StringPhysicalCast.md), and the
verifier checks the two agree.

## See Also

[String](String.md), [StringPhysicalCast](../expression_nodes/StringPhysicalCast.md), [array_physical_type](../enum_nodes/array_physical_type.md)
