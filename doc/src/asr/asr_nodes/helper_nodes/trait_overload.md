# trait_overload

Overloaded generic messages (DI extension E6): the generic messages of one
name that a universal trait declares.

## Declaration

### Syntax

```text
trait_overload = (identifier name, symbol* members)
```

`name` is the name that the messages declare, and `members` are two or more
generic messages (`Template` members) directly declared in the trait's
symbol table, in declaration order. Their keys in the symbol table are
unique and have no meaning; no other member of the trait is keyed `name`,
and a member is in at most one set. The messages are all functions or all
subroutines, and every two are distinguishable by the rules for the
specifics of a generic interface, with their receivers as passed-object
dummies. The verifier checks the structure and that no two members
correspond (`ASRUtils::trait_messages_correspond`), so each is a requirement
of its own; full distinguishability is checked by the frontend.

The name of every other message is its key. `ASRUtils::trait_message_name`
returns the name that a message declares, and diagnostics use it. Messages
of one name of several traits, combined by a type's adoption, a constraint
or a parent trait, are one requirement when their signatures correspond
(`ASRUtils::trait_messages_correspond`); otherwise they are overloads of
each other. A `TraitConstraint` has a requirement for each overload, and a
`TraitImplementation` binds each to a specific of the type's generic binding
of the name. A trait with overloads has no runtime contract.

See [Trait](../symbol_nodes/Trait.md).
