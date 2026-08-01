// --- #2 regressions: World creation and spawn ---

///|
test "new World is empty" {
  let w = @ecs.World::new()
  inspect(@ecs.World::len(w), content="0")
  inspect(@ecs.World::is_empty(w), content="true")
}

///|
test "spawn creates live entity and updates counts" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  inspect(@ecs.World::len(w), content="1")
  inspect(@ecs.World::is_empty(w), content="false")
  inspect(@ecs.World::is_alive(w, e), content="true")
}

///|
test "spawned entities are distinct" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  inspect(e1 == e2, content="false")
  inspect(@ecs.World::len(w), content="2")
  inspect(@ecs.World::is_alive(w, e1), content="true")
  inspect(@ecs.World::is_alive(w, e2), content="true")
}

///|
test "empty and non-empty World state transitions" {
  let w = @ecs.World::new()
  inspect(@ecs.World::is_empty(w), content="true")
  let _ = @ecs.World::spawn(w)
  inspect(@ecs.World::is_empty(w), content="false")
  let _ = @ecs.World::spawn(w)
  inspect(@ecs.World::len(w), content="2")
}

///|
test "Entity supports hashing via Map key usage" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  let m : Map[@ecs.Entity, String] = Map([])
  m[e1] = "first"
  m[e2] = "second"
  inspect(m[e1], content="first")
  inspect(m[e2], content="second")
}

// --- #3: Despawn and lifecycle safety ---

///|
test "despawn live entity makes it stale" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  inspect(@ecs.World::len(w), content="1")
  @ecs.World::despawn(w, e)
  inspect(@ecs.World::len(w), content="0")
  inspect(@ecs.World::is_alive(w, e), content="false")
}

///|
test "despawn stale entity raises StaleEntity" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  @ecs.World::despawn(w, e)
  try @ecs.World::despawn(w, e) catch {
    ECSError::StaleEntity => inspect("stale", content="stale")
    _ => fail("expected StaleEntity")
  } noraise {
    _ => fail("expected StaleEntity")
  }
}

///|
test "despawn foreign entity raises ForeignEntity" {
  let w1 = @ecs.World::new()
  let w2 = @ecs.World::new()
  let e = @ecs.World::spawn(w1)
  try @ecs.World::despawn(w2, e) catch {
    ECSError::ForeignEntity => inspect("foreign", content="foreign")
    _ => fail("expected ForeignEntity")
  } noraise {
    _ => fail("expected ForeignEntity")
  }
}

///|
test "is_alive returns false for foreign entity" {
  let w1 = @ecs.World::new()
  let w2 = @ecs.World::new()
  let e = @ecs.World::spawn(w1)
  inspect(@ecs.World::is_alive(w2, e), content="false")
  inspect(@ecs.World::is_alive(w1, e), content="true")
}

///|
test "slot reuse produces distinct entities" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  @ecs.World::despawn(w, e1)
  let e2 = @ecs.World::spawn(w)
  // e2 reuses e1's slot but must compare unequal
  inspect(
    e1 == e2,
    content=(
      #|false
    ),
  )
  inspect(@ecs.World::len(w), content="1")
  inspect(@ecs.World::is_alive(w, e2), content="true")
  inspect(
    @ecs.World::is_alive(w, e1),
    content=(
      #|false
    ),
  )
}

///|
test "spawn-despawn-spawn cycles maintain correct counts" {
  let w = @ecs.World::new()
  for _ in 0..<5 {
    ignore(@ecs.World::spawn(w))
  }
  inspect(@ecs.World::len(w), content="5")
  let es : Array[@ecs.Entity] = []
  for _ in 0..<3 {
    let e = @ecs.World::spawn(w)
    es.push(e)
  }
  inspect(@ecs.World::len(w), content="8")
  for i in 0..<3 {
    @ecs.World::despawn(w, es[i])
  }
  inspect(@ecs.World::len(w), content="5")
}

// --- #4: Register and access the first typed Component Slot ---

///|
test "register returns a ComponentKey with distinct ComponentID" {
  let w = @ecs.World::new()
  let k1 : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k2 : @ecs.ComponentKey[String] = @ecs.World::register(w)
  let id1 = @ecs.ComponentKey::id(k1)
  let id2 = @ecs.ComponentKey::id(k2)
  inspect(id1 == id2, content="false")
}

///|
test "set on absent entity returns None" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  inspect(@ecs.ComponentKey::set(k, e, 42), content="None")
  inspect(@ecs.ComponentKey::len(k), content="1")
  inspect(@ecs.ComponentKey::is_empty(k), content="false")
}

///|
test "set on present entity returns previous value" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e, 10))
  inspect(@ecs.ComponentKey::set(k, e, 20), content="Some(10)")
  inspect(@ecs.ComponentKey::len(k), content="1")
}

///|
test "get returns None for absent, Some for present" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  inspect(@ecs.ComponentKey::get(k, e), content="None")
  ignore(@ecs.ComponentKey::set(k, e, 7))
  inspect(@ecs.ComponentKey::get(k, e), content="Some(7)")
}

///|
test "contains returns correct membership" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  inspect(@ecs.ComponentKey::contains(k, e), content="false")
  ignore(@ecs.ComponentKey::set(k, e, 1))
  inspect(@ecs.ComponentKey::contains(k, e), content="true")
}

///|
test "len and is_empty track slot population" {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  inspect(@ecs.ComponentKey::len(k), content="0")
  inspect(@ecs.ComponentKey::is_empty(k), content="true")
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  ignore(@ecs.ComponentKey::set(k, e1, 1))
  inspect(@ecs.ComponentKey::len(k), content="1")
  inspect(@ecs.ComponentKey::is_empty(k), content="false")
  ignore(@ecs.ComponentKey::set(k, e2, 2))
  inspect(@ecs.ComponentKey::len(k), content="2")
}

///|
test "stale entity raises StaleEntity on component operations" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  @ecs.World::despawn(w, e)
  try @ecs.ComponentKey::set(k, e, 1) catch {
    ECSError::StaleEntity => inspect("stale", content="stale")
    _ => fail("expected StaleEntity")
  } noraise {
    _ => fail("expected StaleEntity")
  }
}

///|
test "foreign entity raises ForeignEntity on component operations" {
  let w1 = @ecs.World::new()
  let w2 = @ecs.World::new()
  let e = @ecs.World::spawn(w1)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w2)
  try @ecs.ComponentKey::set(k, e, 1) catch {
    ECSError::ForeignEntity => inspect("foreign", content="foreign")
    _ => fail("expected ForeignEntity")
  } noraise {
    _ => fail("expected ForeignEntity")
  }
}

///|
test "foreign takes priority over stale on component operations" {
  let w1 = @ecs.World::new()
  let w2 = @ecs.World::new()
  let e = @ecs.World::spawn(w1)
  @ecs.World::despawn(w1, e) // e is both foreign to w2 and stale
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w2)
  try @ecs.ComponentKey::set(k, e, 1) catch {
    ECSError::ForeignEntity => inspect("foreign first", content="foreign first")
    _ => fail("expected ForeignEntity before StaleEntity")
  } noraise {
    _ => fail("expected ForeignEntity before StaleEntity")
  }
}

///|
test "foreign takes priority over stale on despawn" {
  let w1 = @ecs.World::new()
  let w2 = @ecs.World::new()
  let e = @ecs.World::spawn(w1)
  @ecs.World::despawn(w1, e) // e is both foreign to w2 and stale
  try @ecs.World::despawn(w2, e) catch {
    ECSError::ForeignEntity => inspect("foreign first", content="foreign first")
    _ => fail("expected ForeignEntity before StaleEntity")
  } noraise {
    _ => fail("expected ForeignEntity before StaleEntity")
  }
}

///|
test "arbitrary payload types work without extra trait bounds" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  // String payload
  let ks : @ecs.ComponentKey[String] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(ks, e, "hello"))
  inspect(@ecs.ComponentKey::get(ks, e), content="Some(hello)")
  // Double payload
  let kd : @ecs.ComponentKey[Double] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(kd, e, 3.14))
  inspect(@ecs.ComponentKey::get(kd, e), content="Some(3.14)")
}

///|
test "multiple entities can hold components independently" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e1, 100))
  ignore(@ecs.ComponentKey::set(k, e2, 200))
  inspect(@ecs.ComponentKey::get(k, e1), content="Some(100)")
  inspect(@ecs.ComponentKey::get(k, e2), content="Some(200)")
  inspect(@ecs.ComponentKey::len(k), content="2")
}

// --- #5: Remove and clear Components with sparse-set integrity ---

///|
test "remove present component returns payload" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e, 42))
  inspect(@ecs.ComponentKey::remove(k, e), content="Some(42)")
  inspect(@ecs.ComponentKey::len(k), content="0")
  inspect(@ecs.ComponentKey::contains(k, e), content="false")
}

///|
test "remove absent component returns None" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  inspect(@ecs.ComponentKey::remove(k, e), content="None")
  inspect(@ecs.ComponentKey::len(k), content="0")
}

///|
test "remove stale entity raises StaleEntity" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  @ecs.World::despawn(w, e)
  try @ecs.ComponentKey::remove(k, e) catch {
    ECSError::StaleEntity => inspect("stale", content="stale")
    _ => fail("expected StaleEntity")
  } noraise {
    _ => fail("expected StaleEntity")
  }
}

///|
test "clear empties slot without despawning entities" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e1, 10))
  ignore(@ecs.ComponentKey::set(k, e2, 20))
  @ecs.ComponentKey::clear(k)
  inspect(@ecs.ComponentKey::len(k), content="0")
  inspect(@ecs.ComponentKey::is_empty(k), content="true")
  inspect(@ecs.World::is_alive(w, e1), content="true")
  inspect(@ecs.World::is_alive(w, e2), content="true")
}

///|
test "remove preserves other entities' components" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  let e3 = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e1, 100))
  ignore(@ecs.ComponentKey::set(k, e2, 200))
  ignore(@ecs.ComponentKey::set(k, e3, 300))
  ignore(@ecs.ComponentKey::remove(k, e2))
  inspect(@ecs.ComponentKey::len(k), content="2")
  inspect(@ecs.ComponentKey::get(k, e1), content="Some(100)")
  inspect(@ecs.ComponentKey::get(k, e3), content="Some(300)")
  inspect(@ecs.ComponentKey::contains(k, e2), content="false")
}

///|
test "clear empty slot is idempotent" {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  @ecs.ComponentKey::clear(k)
  inspect(@ecs.ComponentKey::len(k), content="0")
  @ecs.ComponentKey::clear(k)
  inspect(@ecs.ComponentKey::len(k), content="0")
}

// --- #6: Register independent Slots with the same payload type ---

///|
test "same payload type registered twice creates distinct ComponentIDs" {
  let w = @ecs.World::new()
  let k1 : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k2 : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  inspect(
    @ecs.ComponentKey::id(k1) == @ecs.ComponentKey::id(k2),
    content="false",
  )
}

///|
test "same-type slots have independent storage" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k_pos : @ecs.ComponentKey[Int] = @ecs.World::register(w) // current position
  let k_tgt : @ecs.ComponentKey[Int] = @ecs.World::register(w) // target position
  ignore(@ecs.ComponentKey::set(k_pos, e, 10))
  ignore(@ecs.ComponentKey::set(k_tgt, e, 20))
  inspect(@ecs.ComponentKey::get(k_pos, e), content="Some(10)")
  inspect(@ecs.ComponentKey::get(k_tgt, e), content="Some(20)")
  inspect(@ecs.ComponentKey::len(k_pos), content="1")
  inspect(@ecs.ComponentKey::len(k_tgt), content="1")
}

///|
test "removing from one same-type slot does not affect the other" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k1 : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k2 : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k1, e, 100))
  ignore(@ecs.ComponentKey::set(k2, e, 200))
  ignore(@ecs.ComponentKey::remove(k1, e))
  inspect(@ecs.ComponentKey::contains(k1, e), content="false")
  inspect(@ecs.ComponentKey::contains(k2, e), content="true")
  inspect(@ecs.ComponentKey::get(k2, e), content="Some(200)")
}

///|
test "no type-directed ambiguous access exists" {
  let w = @ecs.World::new()
  // Type annotations ensure keys are the only access path — no world.get[T] exists
  let k1 : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k2 : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  // The only way to access Int components is through their specific keys
  let _ : @ecs.ComponentKey[Int] = k1
  let _ : @ecs.ComponentKey[Int] = k2
  inspect(true, content="true")
}

// --- #7: Clean every registered Component Slot on despawn ---

///|
test "despawn removes entity from all registered slots" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k1 : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k2 : @ecs.ComponentKey[String] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k1, e, 42))
  ignore(@ecs.ComponentKey::set(k2, e, "hello"))
  @ecs.World::despawn(w, e)
  inspect(@ecs.ComponentKey::len(k1), content="0")
  inspect(@ecs.ComponentKey::len(k2), content="0")
}

///|
test "despawn removes entity from same-type slots independently" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k_pos : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k_tgt : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k_pos, e, 10))
  ignore(@ecs.ComponentKey::set(k_tgt, e, 20))
  @ecs.World::despawn(w, e)
  inspect(@ecs.ComponentKey::len(k_pos), content="0")
  inspect(@ecs.ComponentKey::len(k_tgt), content="0")
}

///|
test "despawn leaves other entities' components untouched" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e1, 100))
  ignore(@ecs.ComponentKey::set(k, e2, 200))
  @ecs.World::despawn(w, e1)
  inspect(@ecs.ComponentKey::len(k), content="1")
  inspect(@ecs.ComponentKey::get(k, e2), content="Some(200)")
  // e1 is stale — contains raises StaleEntity (spec: consistent error semantics)
  try @ecs.ComponentKey::contains(k, e1) catch {
    ECSError::StaleEntity =>
      inspect("stale after despawn", content="stale after despawn")
    _ => fail("expected StaleEntity")
  } noraise {
    _ => fail("expected StaleEntity")
  }
}

// --- #8: Clear a World without invalidating Component Keys ---

///|
test "clear empty World stays empty" {
  let w = @ecs.World::new()
  @ecs.World::clear(w)
  inspect(@ecs.World::len(w), content="0")
  inspect(@ecs.World::is_empty(w), content="true")
}

///|
test "clear removes all entities and components" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e1, 10))
  ignore(@ecs.ComponentKey::set(k, e2, 20))
  @ecs.World::clear(w)
  inspect(@ecs.World::len(w), content="0")
  inspect(@ecs.ComponentKey::len(k), content="0")
  inspect(@ecs.World::is_alive(w, e1), content="false")
  inspect(@ecs.World::is_alive(w, e2), content="false")
}

///|
test "after clear existing keys remain valid for reuse" {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let e = @ecs.World::spawn(w)
  ignore(@ecs.ComponentKey::set(k, e, 42))
  @ecs.World::clear(w)
  let e2 = @ecs.World::spawn(w)
  ignore(@ecs.ComponentKey::set(k, e2, 99))
  inspect(@ecs.ComponentKey::get(k, e2), content="Some(99)")
  inspect(@ecs.ComponentKey::len(k), content="1")
}

///|
test "clear preserves ComponentID identity" {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let id_before = @ecs.ComponentKey::id(k)
  @ecs.World::clear(w)
  let id_after = @ecs.ComponentKey::id(k)
  inspect(id_before == id_after, content="true")
}

///|
test "clear resets entity allocator for fresh spawns" {
  let w = @ecs.World::new()
  ignore(@ecs.World::spawn(w))
  ignore(@ecs.World::spawn(w))
  @ecs.World::clear(w)
  let e = @ecs.World::spawn(w)
  inspect(@ecs.World::len(w), content="1")
  inspect(@ecs.World::is_alive(w, e), content="true")
}

// --- #9: Execute a guarded single-Slot Query Plan ---

///|
test "query visits all entities with matching component" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  let e3 = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e1, 1))
  ignore(@ecs.ComponentKey::set(k, e2, 2))
  // e3 has no component — should not appear in query
  let plan = @ecs.World::query(w, k)
  let mut count = 0
  @ecs.QueryPlan::each(plan, fn(e : @ecs.Entity) -> Unit raise ECSError {
    count = count + 1
  })
  inspect(count, content="2")
}

///|
test "query with no matching entities runs body zero times" {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let plan = @ecs.World::query(w, k)
  let mut ran = false
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError { ran = true })
  inspect(ran, content="false")
}

///|
test "query plan is reusable after World changes" {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let plan = @ecs.World::query(w, k)
  let e1 = @ecs.World::spawn(w)
  ignore(@ecs.ComponentKey::set(k, e1, 10))
  let mut c1 = 0
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError { c1 = c1 + 1 })
  inspect(c1, content="1")
  // Add another entity and reuse plan
  let e2 = @ecs.World::spawn(w)
  ignore(@ecs.ComponentKey::set(k, e2, 20))
  let mut c2 = 0
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError { c2 = c2 + 1 })
  inspect(c2, content="2")
}

///|
test "foreign ComponentKey raises ForeignComponentKey on query creation" {
  let w1 = @ecs.World::new()
  let w2 = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w1)
  try @ecs.World::query(w2, k) catch {
    ECSError::ForeignComponentKey =>
      inspect("foreign key", content="foreign key")
    _ => fail("expected ForeignComponentKey")
  } noraise {
    _ => fail("expected ForeignComponentKey")
  }
}

///|
test "callback error propagates and allows later operations" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e, 42))
  let plan = @ecs.World::query(w, k)
  try
    @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError {
      raise ECSError::StaleEntity
    })
  catch {
    ECSError::StaleEntity => inspect("propagated", content="propagated")
    _ => fail("expected StaleEntity")
  } noraise {
    _ => fail("expected error")
  }
  // After error, operations still work
  ignore(@ecs.ComponentKey::set(k, e, 99))
  inspect(@ecs.ComponentKey::get(k, e), content="Some(99)")
}

///|
test "structural mutation during query raises StructuralMutationDuringQuery" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e, 1))
  let plan = @ecs.World::query(w, k)
  try
    @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError {
      // Attempting to despawn during query should fail
      @ecs.World::despawn(w, e)
    })
  catch {
    ECSError::StructuralMutationDuringQuery =>
      inspect("blocked", content="blocked")
    _ => fail("expected StructuralMutationDuringQuery")
  } noraise {
    _ => fail("expected StructuralMutationDuringQuery")
  }
}

// --- #10: Compose required Slots and select the smallest driver ---

///|
test "add_required returns new immutable plan" {
  let w = @ecs.World::new()
  let k1 : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k2 : @ecs.ComponentKey[String] = @ecs.World::register(w)
  let plan1 = @ecs.World::query(w, k1)
  let plan2 = @ecs.QueryPlan::add_required(plan1, k2)
  // plan1 and plan2 are different objects (immutability verified by type system)
  let mut c1 = 0
  @ecs.QueryPlan::each(plan1, fn(_e) -> Unit raise ECSError { c1 = c1 + 1 })
  let mut c2 = 0
  @ecs.QueryPlan::each(plan2, fn(_e) -> Unit raise ECSError { c2 = c2 + 1 })
  inspect(c1, content="0")
  inspect(c2, content="0")
}

///|
test "multi-required query matches entities with all components" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  let e3 = @ecs.World::spawn(w)
  let k_i : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k_s : @ecs.ComponentKey[String] = @ecs.World::register(w)
  // e1: both, e2: Int only, e3: neither
  ignore(@ecs.ComponentKey::set(k_i, e1, 1))
  ignore(@ecs.ComponentKey::set(k_s, e1, "a"))
  ignore(@ecs.ComponentKey::set(k_i, e2, 2))
  let plan = @ecs.World::query(w, k_i)
  let plan = @ecs.QueryPlan::add_required(plan, k_s)
  let mut count = 0
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError { count = count + 1 })
  inspect(count, content="1")
}

///|
test "add_required with same key is idempotent" {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let e = @ecs.World::spawn(w)
  ignore(@ecs.ComponentKey::set(k, e, 1))
  let plan1 = @ecs.World::query(w, k)
  let plan2 = @ecs.QueryPlan::add_required(plan1, k)
  let mut c1 = 0
  @ecs.QueryPlan::each(plan1, fn(_e) -> Unit raise ECSError { c1 = c1 + 1 })
  let mut c2 = 0
  @ecs.QueryPlan::each(plan2, fn(_e) -> Unit raise ECSError { c2 = c2 + 1 })
  inspect(c1, content="1")
  inspect(c2, content="1")
}

///|
test "foreign ComponentKey rejected on add_required" {
  let w1 = @ecs.World::new()
  let w2 = @ecs.World::new()
  let k1 : @ecs.ComponentKey[Int] = @ecs.World::register(w1)
  let k2 : @ecs.ComponentKey[Int] = @ecs.World::register(w2)
  let plan = @ecs.World::query(w1, k1)
  try @ecs.QueryPlan::add_required(plan, k2) catch {
    ECSError::ForeignComponentKey => inspect("foreign", content="foreign")
    _ => fail("expected ForeignComponentKey")
  } noraise {
    _ => fail("expected ForeignComponentKey")
  }
}

///|
test "smallest pool chosen as driver" {
  let w = @ecs.World::new()
  let k_a : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k_b : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  // Populate k_a with many entities, k_b with just one
  for _ in 0..<5 {
    let e = @ecs.World::spawn(w)
    ignore(@ecs.ComponentKey::set(k_a, e, 1))
  }
  let e_small = @ecs.World::spawn(w)
  ignore(@ecs.ComponentKey::set(k_a, e_small, 1))
  ignore(@ecs.ComponentKey::set(k_b, e_small, 2))
  let plan = @ecs.World::query(w, k_a)
  let plan = @ecs.QueryPlan::add_required(plan, k_b)
  let mut count = 0
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError { count = count + 1 })
  // Only e_small has both components
  inspect(count, content="1")
}

// --- #11: Add excluded Slots and validate query constraints ---

///|
test "add_excluded returns new immutable plan" {
  let w = @ecs.World::new()
  let k1 : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k2 : @ecs.ComponentKey[String] = @ecs.World::register(w)
  let plan1 = @ecs.World::query(w, k1)
  let plan2 = @ecs.QueryPlan::add_excluded(plan1, k2)
  let mut c1 = 0
  @ecs.QueryPlan::each(plan1, fn(_e) -> Unit raise ECSError { c1 = c1 + 1 })
  let mut c2 = 0
  @ecs.QueryPlan::each(plan2, fn(_e) -> Unit raise ECSError { c2 = c2 + 1 })
  inspect(c1, content="0")
  inspect(c2, content="0")
}

///|
test "excluded slot filters out matching entities" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  let e3 = @ecs.World::spawn(w)
  let k_i : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k_s : @ecs.ComponentKey[String] = @ecs.World::register(w)
  // e1, e2 have Int; e2 also has String (should be excluded)
  ignore(@ecs.ComponentKey::set(k_i, e1, 1))
  ignore(@ecs.ComponentKey::set(k_i, e2, 2))
  ignore(@ecs.ComponentKey::set(k_s, e2, "x"))
  ignore(@ecs.ComponentKey::set(k_i, e3, 3))
  let plan = @ecs.World::query(w, k_i)
  let plan = @ecs.QueryPlan::add_excluded(plan, k_s)
  let mut count = 0
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError { count = count + 1 })
  inspect(count, content="2")
}

///|
test "exclude same key twice is idempotent" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let k_i : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k_s : @ecs.ComponentKey[String] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k_i, e1, 1))
  ignore(@ecs.ComponentKey::set(k_s, e1, "x"))
  let plan1 = @ecs.World::query(w, k_i)
  let plan2 = @ecs.QueryPlan::add_excluded(plan1, k_s)
  let plan3 = @ecs.QueryPlan::add_excluded(plan2, k_s)
  let mut c2 = 0
  @ecs.QueryPlan::each(plan2, fn(_e) -> Unit raise ECSError { c2 = c2 + 1 })
  let mut c3 = 0
  @ecs.QueryPlan::each(plan3, fn(_e) -> Unit raise ECSError { c3 = c3 + 1 })
  inspect(c2, content="0")
  inspect(c3, content="0")
}

///|
test "require then exclude same key raises ContradictoryQuery" {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let plan = @ecs.World::query(w, k)
  try @ecs.QueryPlan::add_excluded(plan, k) catch {
    ECSError::ContradictoryQuery =>
      inspect("contradiction", content="contradiction")
    _ => fail("expected ContradictoryQuery")
  } noraise {
    _ => fail("expected ContradictoryQuery")
  }
}

///|
test "exclude then require same key raises ContradictoryQuery" {
  let w = @ecs.World::new()
  let k1 : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k2 : @ecs.ComponentKey[String] = @ecs.World::register(w)
  let plan = @ecs.World::query(w, k1)
  let plan = @ecs.QueryPlan::add_excluded(plan, k2)
  try @ecs.QueryPlan::add_required(plan, k2) catch {
    ECSError::ContradictoryQuery =>
      inspect("contradiction", content="contradiction")
    _ => fail("expected ContradictoryQuery")
  } noraise {
    _ => fail("expected ContradictoryQuery")
  }
}

///|
test "foreign key rejected on add_excluded" {
  let w1 = @ecs.World::new()
  let w2 = @ecs.World::new()
  let k1 : @ecs.ComponentKey[Int] = @ecs.World::register(w1)
  let k2 : @ecs.ComponentKey[Int] = @ecs.World::register(w2)
  let plan = @ecs.World::query(w1, k1)
  try @ecs.QueryPlan::add_excluded(plan, k2) catch {
    ECSError::ForeignComponentKey => inspect("foreign", content="foreign")
    _ => fail("expected ForeignComponentKey")
  } noraise {
    _ => fail("expected ForeignComponentKey")
  }
}

///|
test "multiple required and excluded slots combine correctly" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  let e3 = @ecs.World::spawn(w)
  let k_i : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k_s : @ecs.ComponentKey[String] = @ecs.World::register(w)
  let k_d : @ecs.ComponentKey[Double] = @ecs.World::register(w)
  // e1: i+s, e2: i+d, e3: i
  ignore(@ecs.ComponentKey::set(k_i, e1, 1))
  ignore(@ecs.ComponentKey::set(k_s, e1, "a"))
  ignore(@ecs.ComponentKey::set(k_i, e2, 2))
  ignore(@ecs.ComponentKey::set(k_d, e2, 0.5))
  ignore(@ecs.ComponentKey::set(k_i, e3, 3))
  let plan = @ecs.World::query(w, k_i)
  let plan = @ecs.QueryPlan::add_excluded(plan, k_s)
  let plan = @ecs.QueryPlan::add_excluded(plan, k_d)
  let mut count = 0
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError { count = count + 1 })
  // only e3 remains
  inspect(count, content="1")
}

// --- #12: Permit safe nesting and payload replacement in queries ---

///|
test "nested read-only query is allowed" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e, 42))
  let plan = @ecs.World::query(w, k)
  let mut outer = 0
  let mut inner = 0
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError {
    outer = outer + 1
    @ecs.QueryPlan::each(plan, fn(_e2) -> Unit raise ECSError {
      inner = inner + 1
    })
  })
  inspect(outer, content="1")
  inspect(inner, content="1")
}

///|
test "replacing existing payload during query is allowed" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e, 10))
  let plan = @ecs.World::query(w, k)
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError {
    ignore(@ecs.ComponentKey::set(k, e, 99))
  })
  inspect(@ecs.ComponentKey::get(k, e), content="Some(99)")
}

///|
test "setting missing component during query is rejected" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e1, 1))
  let plan = @ecs.World::query(w, k)
  try
    @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError {
      // e2 has no component — first insertion is structural
      ignore(@ecs.ComponentKey::set(k, e2, 2))
    })
  catch {
    ECSError::StructuralMutationDuringQuery =>
      inspect("blocked", content="blocked")
    _ => fail("expected StructuralMutationDuringQuery")
  } noraise {
    _ => fail("expected StructuralMutationDuringQuery")
  }
}

///|
test "spawn during query is rejected" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e, 1))
  let plan = @ecs.World::query(w, k)
  try
    @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError {
      ignore(@ecs.World::spawn(w))
    })
  catch {
    ECSError::StructuralMutationDuringQuery =>
      inspect("blocked", content="blocked")
    _ => fail("expected StructuralMutationDuringQuery")
  } noraise {
    _ => fail("expected StructuralMutationDuringQuery")
  }
}

///|
test "remove during query is rejected" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e, 1))
  let plan = @ecs.World::query(w, k)
  try
    @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError {
      ignore(@ecs.ComponentKey::remove(k, e))
    })
  catch {
    ECSError::StructuralMutationDuringQuery =>
      inspect("blocked", content="blocked")
    _ => fail("expected StructuralMutationDuringQuery")
  } noraise {
    _ => fail("expected StructuralMutationDuringQuery")
  }
}

///|
test "clear slot during query is rejected" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e, 1))
  let plan = @ecs.World::query(w, k)
  try
    @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError {
      @ecs.ComponentKey::clear(k)
    })
  catch {
    ECSError::StructuralMutationDuringQuery =>
      inspect("blocked", content="blocked")
    _ => fail("expected StructuralMutationDuringQuery")
  } noraise {
    _ => fail("expected StructuralMutationDuringQuery")
  }
}

///|
test "world clear during query is rejected" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e, 1))
  let plan = @ecs.World::query(w, k)
  try
    @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError {
      @ecs.World::clear(w)
    })
  catch {
    ECSError::StructuralMutationDuringQuery =>
      inspect("blocked", content="blocked")
    _ => fail("expected StructuralMutationDuringQuery")
  } noraise {
    _ => fail("expected StructuralMutationDuringQuery")
  }
}

///|
test "register during query is rejected" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e, 1))
  let plan = @ecs.World::query(w, k)
  try
    @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError {
      let k2 : @ecs.ComponentKey[Int] = @ecs.World::register(w)
      ignore(k2)
    })
  catch {
    ECSError::StructuralMutationDuringQuery =>
      inspect("blocked", content="blocked")
    _ => fail("expected StructuralMutationDuringQuery")
  } noraise {
    _ => fail("expected StructuralMutationDuringQuery")
  }
}

///|
test "remove stale entity during query raises StaleEntity" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e1, 1))
  let e2 = @ecs.World::spawn(w)
  @ecs.World::despawn(w, e2) // e2 is stale but not in the driver pool
  let plan = @ecs.World::query(w, k)
  try
    @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError {
      ignore(@ecs.ComponentKey::remove(k, e2))
    })
  catch {
    ECSError::StaleEntity => inspect("stale", content="stale")
    _ => fail("expected StaleEntity, not StructuralMutationDuringQuery")
  } noraise {
    _ => fail("expected StaleEntity, not StructuralMutationDuringQuery")
  }
}

///|
test "remove foreign entity during query raises ForeignEntity" {
  let w1 = @ecs.World::new()
  let w2 = @ecs.World::new()
  let e1 = @ecs.World::spawn(w1)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w1)
  ignore(@ecs.ComponentKey::set(k, e1, 1))
  let e_foreign = @ecs.World::spawn(w2)
  let plan = @ecs.World::query(w1, k)
  try
    @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError {
      ignore(@ecs.ComponentKey::remove(k, e_foreign))
    })
  catch {
    ECSError::ForeignEntity => inspect("foreign", content="foreign")
    _ => fail("expected ForeignEntity, not StructuralMutationDuringQuery")
  } noraise {
    _ => fail("expected ForeignEntity, not StructuralMutationDuringQuery")
  }
}

///|
test "despawn stale entity during query raises StaleEntity" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e1, 1))
  let e2 = @ecs.World::spawn(w)
  @ecs.World::despawn(w, e2) // e2 is stale but not in the driver pool
  let plan = @ecs.World::query(w, k)
  try
    @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError {
      @ecs.World::despawn(w, e2)
    })
  catch {
    ECSError::StaleEntity => inspect("stale", content="stale")
    _ => fail("expected StaleEntity, not StructuralMutationDuringQuery")
  } noraise {
    _ => fail("expected StaleEntity, not StructuralMutationDuringQuery")
  }
}

///|
test "despawn foreign entity during query raises ForeignEntity" {
  let w1 = @ecs.World::new()
  let w2 = @ecs.World::new()
  let e1 = @ecs.World::spawn(w1)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w1)
  ignore(@ecs.ComponentKey::set(k, e1, 1))
  let e_foreign = @ecs.World::spawn(w2)
  let plan = @ecs.World::query(w1, k)
  try
    @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError {
      @ecs.World::despawn(w1, e_foreign)
    })
  catch {
    ECSError::ForeignEntity => inspect("foreign", content="foreign")
    _ => fail("expected ForeignEntity, not StructuralMutationDuringQuery")
  } noraise {
    _ => fail("expected ForeignEntity, not StructuralMutationDuringQuery")
  }
}

///|
test "query guard restored after callback error" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e, 10))
  let plan = @ecs.World::query(w, k)
  try
    @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise ECSError {
      raise ECSError::StaleEntity
    })
  catch {
    ECSError::StaleEntity => ()
    _ => fail("expected StaleEntity")
  } noraise {
    _ => fail("expected error")
  }
  // After error, operations work normally — guard was restored
  inspect(@ecs.World::len(w), content="1")
  ignore(@ecs.ComponentKey::set(k, e, 99))
  inspect(@ecs.ComponentKey::get(k, e), content="Some(99)")
}
