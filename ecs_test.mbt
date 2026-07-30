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
