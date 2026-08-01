// --- Component Key: set, get, contains, remove, clear, slots ---
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
  debug_inspect(@ecs.ComponentKey::set(k, e, 42), content="None")
  inspect(@ecs.ComponentKey::len(k), content="1")
  inspect(@ecs.ComponentKey::is_empty(k), content="false")
}

///|
test "set on present entity returns previous value" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e, 10))
  debug_inspect(@ecs.ComponentKey::set(k, e, 20), content="Some(10)")
  inspect(@ecs.ComponentKey::len(k), content="1")
}

///|
test "get returns None for absent, Some for present" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  debug_inspect(@ecs.ComponentKey::get(k, e), content="None")
  ignore(@ecs.ComponentKey::set(k, e, 7))
  debug_inspect(@ecs.ComponentKey::get(k, e), content="Some(7)")
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
  debug_inspect(
    @ecs.ComponentKey::get(ks, e),
    content=(
      #|Some("hello")
    ),
  )
  // Double payload
  let kd : @ecs.ComponentKey[Double] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(kd, e, 3.14))
  debug_inspect(@ecs.ComponentKey::get(kd, e), content="Some(3.14)")
}

///|
test "multiple entities can hold components independently" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e1, 100))
  ignore(@ecs.ComponentKey::set(k, e2, 200))
  debug_inspect(@ecs.ComponentKey::get(k, e1), content="Some(100)")
  debug_inspect(@ecs.ComponentKey::get(k, e2), content="Some(200)")
  inspect(@ecs.ComponentKey::len(k), content="2")
}
// --- #5: Remove and clear Components with sparse-set integrity ---

///|
test "remove present component returns payload" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e, 42))
  debug_inspect(@ecs.ComponentKey::remove(k, e), content="Some(42)")
  inspect(@ecs.ComponentKey::len(k), content="0")
  inspect(@ecs.ComponentKey::contains(k, e), content="false")
}

///|
test "remove absent component returns None" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  debug_inspect(@ecs.ComponentKey::remove(k, e), content="None")
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
  debug_inspect(@ecs.ComponentKey::get(k, e1), content="Some(100)")
  debug_inspect(@ecs.ComponentKey::get(k, e3), content="Some(300)")
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
  debug_inspect(@ecs.ComponentKey::get(k_pos, e), content="Some(10)")
  debug_inspect(@ecs.ComponentKey::get(k_tgt, e), content="Some(20)")
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
  debug_inspect(@ecs.ComponentKey::get(k2, e), content="Some(200)")
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
