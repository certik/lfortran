# TraitDescriptorType

A trait descriptor (DI extension E10).

## Declaration

### Syntax

```text
TraitDescriptorType(identifier? parameter)
```

The type of a [TraitDescriptor](../expression_nodes/TraitDescriptor.md). The
erased entry of a generic message with trait parameters, its slot interface
and the witness adapters that fill the slot have one trailing `intent(in)`
dummy of this type per trait parameter, after any conformance dictionary
dummies, named `__descriptor_<parameter>`; such a dummy names the trait
`parameter` it is passed for. The type of a descriptor actual has none. A
[TraitObjectType](TraitObjectType.md) whose contract is such a dummy is a
trait object of the trait the caller passes. Descriptors are only passed,
never stored, assigned or compared, and all descriptor types are equal. In
LLVM a descriptor is the address of its constant record.

See the [traits guide](../../traits.md).
