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
  inspect(
    m[e1],
    content=(
      #|first
    ),
  )
  inspect(
    m[e2],
    content=(
      #|second
    ),
  )
}

///|
test "Entity supports debug output" {
  let w = @ecs.World::new()
  let e = @ecs.World::spawn(w)
  // Entity derives Debug — verify it renders without panicking
  debug_inspect(
    e,
    content=(
      #|{ id: 0 }
    ),
  )
}
