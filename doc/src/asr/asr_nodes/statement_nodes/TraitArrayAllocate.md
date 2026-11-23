# TraitArrayAllocate

Allocate the elements of a runtime trait array owner (TD-46).

## Declaration

### Syntax

```text
TraitArrayAllocate(expr target, dimension* dims, expr? source, symbol? witness)
```

`target` is a variable or component of a deferred-shape allocatable runtime
trait array type, `Allocatable(Array(TraitObjectType))`, and `dims` gives the lower bound
(1 when absent) and the extent of each of its dimensions. `witness` is the
witness of the instantiable concrete type of every element, conforming to the
target's exact contract. Without a `source` the allocation was typed and
default-initializes each element; with one, `source` is a nonpolymorphic
scalar of that concrete type, which initialize-copies each element, as
`allocate(arr(n), source=x)` does. Without a `witness`, `source` is a scalar
view (`TraitObjectType`) of the target's contract, a borrowed owner, a view or
an element of a trait array: the elements take its dynamic type and witness,
as `allocate(arr(n), source=item)` with `class(ITrait) :: item` does, also in
generic code where `item` is `class(P)` of a trait parameter.

The operation requires an unallocated target. It creates a component's
descriptor if the component has none yet, allocates contiguous storage
for the elements, records their size and byte strides in the descriptor,
stores the witness's view without a payload after the dimensions, and
initializes each element through the witness's lifecycle. A view source
gives its own header instead, and the element size is read from the type
information of its dynamic type. Deallocating the
owner destroys each element through the same lifecycle before freeing the
storage. Verification checks the target, the bounds, the witness's contract
and concrete type, and the source's type; without a witness, that the source
is a view of the target's contract.
