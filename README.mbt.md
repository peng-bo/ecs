# ECS Core

A sparse-set ECS Core for MoonBit — type-safe, backend-portable, single-threaded.

## Quick Start

```mbt check
///|
test "world and entity lifecycle" {
  let w = @ecs.World::new()
  inspect(@ecs.World::len(w), content="0")
  inspect(@ecs.World::is_empty(w), content="true")

  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  inspect(@ecs.World::len(w), content="2")
  inspect(@ecs.World::is_alive(w, e1), content="true")
  inspect(e1 == e2, content="false")

  @ecs.World::despawn(w, e1)
  inspect(@ecs.World::is_alive(w, e1), content="false")
  inspect(@ecs.World::len(w), content="1")
}

///|
test "two same-type component slots" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let pos : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let tgt : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let id1 = @ecs.ComponentKey::id(pos)
  let id2 = @ecs.ComponentKey::id(tgt)
  inspect(id1 == id2, content="false")

  ignore(@ecs.ComponentKey::set(pos, e, 10))
  ignore(@ecs.ComponentKey::set(tgt, e, 20))
  inspect(@ecs.ComponentKey::get(pos, e), content="Some(10)")
  inspect(@ecs.ComponentKey::get(tgt, e), content="Some(20)")
}

///|
test "set replacement and removal" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)

  ignore(@ecs.ComponentKey::set(k, e, 10))
  inspect(@ecs.ComponentKey::set(k, e, 99), content="Some(10)")
  inspect(@ecs.ComponentKey::len(k), content="1")

  inspect(@ecs.ComponentKey::remove(k, e), content="Some(99)")
  inspect(@ecs.ComponentKey::contains(k, e), content="false")
  inspect(@ecs.ComponentKey::len(k), content="0")
}

///|
test "query with required and excluded slots" {
  let w = @ecs.World::new()
  let health : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let dead : @ecs.ComponentKey[String] = @ecs.World::register(w)
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  ignore(@ecs.ComponentKey::set(health, e1, 100))
  ignore(@ecs.ComponentKey::set(health, e2, 50))
  ignore(@ecs.ComponentKey::set(dead, e2, "yes"))

  let plan = @ecs.World::query(w, health)
  let plan = @ecs.QueryPlan::add_excluded(plan, dead)
  let mut count = 0
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit { count = count + 1 })
  inspect(count, content="1")
}

///|
test "world clear preserves keys" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e, 42))
  @ecs.World::clear(w)
  inspect(@ecs.World::len(w), content="0")

  let e2 = @ecs.World::spawn(w)
  ignore(@ecs.ComponentKey::set(k, e2, 7))
  inspect(@ecs.ComponentKey::get(k, e2), content="Some(7)")
}
```

## Error Handling

```mbt check
///|
test "stale entity" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  @ecs.World::despawn(w, e)
  try @ecs.World::despawn(w, e) catch {
    ECSError::StaleEntity => ()
    _ => fail("expected StaleEntity")
  } noraise {
    _ => fail("expected StaleEntity")
  }
}

///|
test "foreign entity" {
  let w1 = @ecs.World::new()
  let w2 = @ecs.World::new()
  let e = @ecs.World::spawn(w1)
  try @ecs.World::despawn(w2, e) catch {
    ECSError::ForeignEntity => ()
    _ => fail("expected ForeignEntity")
  } noraise {
    _ => fail("expected ForeignEntity")
  }
}

///|
test "structural mutation during query" {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let e = @ecs.World::spawn(w)
  ignore(@ecs.ComponentKey::set(k, e, 1))
  let plan = @ecs.World::query(w, k)
  try
    @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError {
      ignore(@ecs.World::spawn(w))
    })
  catch {
    ECSError::StructuralMutationDuringQuery => ()
    _ => fail("expected StructuralMutationDuringQuery")
  } noraise {
    _ => fail("expected StructuralMutationDuringQuery")
  }
}

///|
test "contradictory query" {
  let w = @ecs.World::new()
  let k1 : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k2 : @ecs.ComponentKey[String] = @ecs.World::register(w)
  let plan = @ecs.World::query(w, k1)
  let plan = @ecs.QueryPlan::add_excluded(plan, k2)
  try @ecs.QueryPlan::add_required(plan, k2) catch {
    ECSError::ContradictoryQuery => ()
    _ => fail("expected ContradictoryQuery")
  } noraise {
    _ => fail("expected ContradictoryQuery")
  }
}

///|
test "payload replacement during query is allowed" {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let e = @ecs.World::spawn(w)
  ignore(@ecs.ComponentKey::set(k, e, 100))
  let plan = @ecs.World::query(w, k)
  @ecs.QueryPlan::each(plan, fn(entity) -> Unit raise ECSError {
    ignore(@ecs.ComponentKey::set(k, entity, 999))
  })
  inspect(@ecs.ComponentKey::get(k, e), content="Some(999)")
}
```

## Core Types

**World** — Lifecycle coordinator. Creates Entities, registers Component Slots, coordinates despawn and clearing.

**Entity** — Opaque handle to a live participant in exactly one World. Permanently stale after despawn. Supports equality, hashing, and debug output without exposing constructors or identity fields.

**ComponentKey[T]** — Unforgeable typed handle for one Component Slot in one World. Provides `set`, `get`, `contains`, `remove`, `clear`, `len`, `is_empty`, and `id`. All entity-accepting operations raise `StaleEntity` or `ForeignEntity` for invalid handles. Set during query is allowed only for replacement (non-structural).

**QueryPlan** — Immutable, reusable description of entity-matching constraints. Created from a required ComponentKey and refined with additional required or excluded keys. Each execution selects the smallest required pool as the driver. Plans are lazy — they observe current World state on each execution.

**ECSError** — Checked errors: `StaleEntity`, `ForeignEntity`, `EntityCapacityExhausted`, `ComponentCapacityExhausted`, `StructuralMutationDuringQuery`, `ForeignComponentKey`, `ContradictoryQuery`.

## Design Notes

- **Query iteration order is unspecified.** The implementation uses swap-remove and dynamic driver selection.
- **Entity identity is World-local.** Cross-World operations raise `ForeignEntity`.
- **Structural mutation is rejected during query.** Spawn, despawn, first insertion, removal, clearing, and registration are structural. Payload replacement and nested read-only queries are allowed.
- **Component Slots cannot be unregistered.** They remain valid across World clearing.
- **No all-Entity or without-only query API.** Every QueryPlan begins with at least one required Component Slot.
- **No type-directed ambiguous access.** All Component operations require a ComponentKey.

## v1 Non-Goals

System scheduling, parallel execution, events/observers, entity hierarchies, serialization, singleton resources, change tracking, standard iterators, cached query results, typed payload projection, type-erased downcasts, deterministic ordering.
