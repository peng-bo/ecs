# ECS

This context defines the vocabulary for the reusable entity-component-system core provided by this library.

## Language

**ECS Core**:
The library boundary responsible for entity identity and component association and querying. It excludes system scheduling, parallel execution, events, hierarchies, serialization, and World-level singleton resources.
_Avoid_: ECS framework, game engine

**Entity**:
An opaque identity for a live participant in exactly one World. After its participant is destroyed, the Entity permanently becomes invalid and must never identify a later participant or a participant in another World.
_Avoid_: Object, component owner

**Invalid Entity**:
An Entity whose lifetime has ended or whose World differs from the World receiving an operation. It is distinct from a valid Entity that simply lacks a particular Component.
_Avoid_: Missing component, unknown entity

**Component**:
A payload value associated with an Entity through one Component Slot. An Entity has at most one Component in each Component Slot, while different slots may use the same payload representation.
_Avoid_: Property, attribute

**Component Slot**:
A World-local registration that defines one kind of Component independently of its payload representation. It remains registered for the lifetime of its World, including across World clearing.
_Avoid_: Component type, runtime type

**Component ID**:
The transient, World-local identity of a Component Slot. It is never reused within its World, has no meaning outside that World, and must not be persisted.
_Avoid_: Type ID, persistent component ID

**Component Key**:
An unforgeable, typed access credential for exactly one Component Slot in exactly one World.
_Avoid_: Type lookup, global component key

**Component Store**:
A typed collection, permanently bound to one Component Slot and its World, that maintains that slot's Components and their Entity associations.
_Avoid_: Dynamic component registry, component bag

**World**:
The lifecycle coordinator that creates Entities and ensures their Component associations are removed when they are despawned. It is not a runtime registry for looking up component types.
_Avoid_: Container, service locator

**Despawn**:
To end an Entity's lifetime and remove all of its Component associations from the World.
_Avoid_: Delete, destroy

**Query Plan**:
A reusable description of the Component-presence constraints that select Entities, anchored by at least one required Component Slot. A Query Plan is evaluated only when it is executed and does not contain a materialized result set.
_Avoid_: Iterator, query result
