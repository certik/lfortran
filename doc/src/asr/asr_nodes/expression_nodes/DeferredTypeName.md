# DeferredTypeName

The `type_name` of a generic parameter, inside a generic definition.

## Declaration

### Syntax

```text
DeferredTypeName(ttype type_argument, bool qualified, ttype type)
```

### Arguments

| Argument | Description |
| --- | --- |
| `type_argument` | The `TypeParameter` of the generic parameter `P` of `type_name{P}()`, a type parameter or a trait parameter. |
| `qualified` | `true` for `type_name{P}(qualified=.true.)`, which prefixes the scoping units that contain the declaration. |
| `type` | A deferred-length `String` of kind 1. |

### Return values

The name, a character value.

## Description

`type_name{P}()` is a character constant wherever `P` is known: a
`StringConstant` holding the `qualified_name` of the derived type or trait
(see [Struct](../symbol_nodes/Struct.md) and
[Trait](../symbol_nodes/Trait.md)), qualified or not, or the name of an
intrinsic type with its kind, such as `real(8)`. Inside a generic, where `P`
is a parameter, it is a **DeferredTypeName**. The generic body is checked
once and copied as ASR when it is instantiated; the template instantiator
replaces the node with the `StringConstant` naming the type or trait bound to
`P`. Forwarded to another generic's binder, the copy is again a
**DeferredTypeName** of that binder. In an erased entry (DI extension E10),
where `P` is a trait parameter passed as a trait descriptor, it becomes a
[TraitDescriptorName](TraitDescriptorName.md) of the entry's descriptor dummy,
which reads the name at run time.

The node exists only in generic definitions; code generation never sees it in
a static instance.

## See Also

[traits guide](../../traits.md)
