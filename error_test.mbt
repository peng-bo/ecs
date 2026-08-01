// --- Error semantics: precedence between error kinds ---

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
