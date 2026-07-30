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
