# TraitDescriptor

The trait descriptor of a runtime contract's trait (DI extension E10).

## Declaration

### Syntax

```text
TraitDescriptor(symbol contract, ttype type)
```

`contract` is a visible `TraitRuntimeContract` of a named trait, and `type`
is a [TraitDescriptorType](../type_nodes/TraitDescriptorType.md). It is the
trailing actual argument that a call of a generic message with trait
parameters through a trait object passes for each trait parameter, after
any conformance dictionaries, in the message's binder order: for
`c%resolve{IClient}()` the descriptor of `IClient`.

Within a generic procedure, `contract` may instead be the binder of the
generic's trait parameter `{Trait :: T1}` that the call forwards, as in
`c%resolve{T1}()`. Template instantiation replaces the binder with the
contract of the trait bound to `T1` in a static instance, with the binder
of a still-generic caller that forwards it, and the whole node with the
descriptor dummy of `T1` in an erased entry, which passes on the descriptor
its caller passed.

A descriptor is a constant record `{slot count, name, qualified name}` that
every translation unit naming the trait defines identically (LLVM
`linkonce_odr`, named after the trait's defining scopes); the slot count is
that of the trait's runtime contract and the names are the strings of
`type_name{P}()` and `type_name{P}(qualified=.true.)`. Its merged address is
the identity of the trait in the runtime conformance tables, so
`TraitConforms` and `TraitDiscover` search by it as well. The descriptor is
never copied, stored or compared.

See the [traits guide](../../traits.md).
