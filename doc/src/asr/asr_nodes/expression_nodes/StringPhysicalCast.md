# StringPhysicalCast

Changes how a string is represented, not what it holds.

## Declaration

### Syntax

```text
StringPhysicalCast(expr arg, string_physical_type old,
    string_physical_type new, ttype type, expr? value)
```

### Arguments

| Argument | Description |
|----------|-------------|
| `arg` | the string expression to re-describe. |
| `old` | its current representation; see [string_physical_type](../type_nodes/StringPhysicalType.md). |
| `new` | the representation to produce. |
| `type` | the type of the result, whose `physical_type` is `new`. |
| `value` | the compile time value of the expression, when the frontend could fold it; `nil` otherwise. |

### Return values

The value of the expression.

## Description

A string is stored as a descriptor, `{char* data, int64 size, int64
capacity}`, as a bare `char*`, or, at the boundary of a separately compiled
external procedure, as a `char*` plus a hidden trailing length; see
[string_physical_type](../type_nodes/StringPhysicalType.md). The logical type
does not change here: only the representation does.

Casting a descriptor to `CChar` hands the runtime the `data` pointer, which is
what the string runtime functions take. Casting the other way wraps a pointer
in a descriptor whose size and capacity are set to `-1`, marking a string that
must not be extended. Casting to `HiddenLenString` is what the frontend wraps
an actual argument in when the dummy uses the classic Fortran external ABI, so
that the call passes the string physical type the dummy declares; a backend
splits the value into its data pointer and length at the call.

The argument may also be an array of strings. Then the result type is an array
with the same dimensions and array physical type, and only the string physical
type of its elements changes.

The verifier requires `old` and `new` to be the physical types of the argument
and of the result, and the result type to have `len_kind=ImplicitLength`,
since the length of the re-described value is not a property of the cast.

## Examples

```clojure
(StringPhysicalCast
  :arg (Var
    :v (SymbolRef 1 "s")
  )
  :old :DescriptorString
  :new :CChar
  :type (String
    :kind 1
    :len nil
    :len_kind :ImplicitLength
    :physical_type :CChar
  )
  :value nil
)
```

It comes from this complete ASR text document:

```{literalinclude} ../../examples/stringphysicalcast.asr
:language: clojure
```

## See Also

StringPhysicalType, [String](../type_nodes/String.md), [Cast](Cast.md), [ArrayPhysicalCast](ArrayPhysicalCast.md)
