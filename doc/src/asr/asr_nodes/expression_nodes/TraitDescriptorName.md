# TraitDescriptorName

The name of the trait a trait descriptor describes (DI extension E10).

## Declaration

### Syntax

```text
TraitDescriptorName(expr descriptor, bool qualified, ttype type)
```

`descriptor` is an expression of type
[TraitDescriptorType](../type_nodes/TraitDescriptorType.md), in practice the
descriptor dummy of an erased entry. `type` is a deferred-length `String`.
It is `type_name{P}()`, or with `qualified` `type_name{P}(qualified=.true.)`,
of a trait parameter `P` in the erased entry of a generic message: template
instantiation replaces the [DeferredTypeName](DeferredTypeName.md) of `P`
with it where `P` is erased, and with a character constant in a static
instance. The value is read from the descriptor at run time; it is not a
constant expression. In LLVM it is the address of the descriptor's string
descriptor, as for a character constant.

See the [traits guide](../../traits.md).
