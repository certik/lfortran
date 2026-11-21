# TraitConforms

Ask whether the dynamic type of a polymorphic selector conforms to a trait.

## Declaration

### Syntax

```text
TraitConforms(expr selector, symbol contract, symbol* witnesses, ttype type)
```

`selector` is a scalar ordinary polymorphic `class(*)` or `class(T)`
designator; for a trait-object selector it is the `TraitInspect` view of the
selected object. `contract` names the in-scope `TraitRuntimeContract` of the
queried trait. `witnesses` are the `TraitWitness` symbols of the retroactive
conformances to that contract visible where the query is made, at most one per
type. `type` is `Logical`. This expression has no constant value.

Within a generic procedure, `contract` may instead be the binder of a trait
parameter `{Trait :: P}`, for a `CLASS IS (P)` guard, with no witnesses. The
instantiation of the generic replaces it with the contract of the trait bound
to `P` and the retroactive witnesses visible where the generic is defined or
instantiated, or, when `P` is passed on, with the caller's binder. In the
erased entry of a generic message (DI extension E10) it is the entry's
descriptor dummy of `P` (see
[TraitDescriptorType](../type_nodes/TraitDescriptorType.md)), again with no
witnesses: the query searches only the runtime conformance tables, by the
identity the descriptor is, and does not find retroactive conformances
visible only where the message is called.

## Semantics

The result is true when the dynamic type of `selector` conforms to the trait of
`contract`. The runtime conformance table of the dynamic type
(`ASRUtils::trait_conformance_table`) is searched first, by the identity of the
trait. It holds the conformances declared in the type's own scope, including
those an extension inherits, so the query does not depend on which modules the
querying scope uses. Only if the table has no entry are `witnesses` compared
with the exact dynamic type.

Semantics emits this node for a `CLASS IS (ITrait)` guard of SELECT TYPE. The
guards are lowered into the CLASS DEFAULT part of the ordinary `SelectType` as
an IF chain in source order; a guard's condition is its query and the negated
queries of the guards naming traits that extend its trait.

The verifier checks the scalar polymorphic selector, the in-scope runtime
contract, that every witness is a conformance to that contract, and the
logical type. LLVM lowers the table search to the runtime function
`_lfortran_trait_conformance`; other executable backends retain the
runtime-trait capability diagnostic.

## See Also

[Experimental traits](../../traits.md), [TraitDiscover](TraitDiscover.md),
[TraitInspect](TraitInspect.md).
