// --- World lifecycle: spawn, despawn, clear, liveness ---
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
  debug_inspect(@ecs.ComponentKey::get(k, e2), content="Some(200)")
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
  debug_inspect(@ecs.ComponentKey::get(k, e2), content="Some(99)")
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
