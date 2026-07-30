///|
test "free list reuses despawned indices first" {
  let w = World::new()
  ignore(World::spawn(w))
  let e2 = World::spawn(w)
  ignore(World::spawn(w))
  // Despawn middle entity — its slot should be reused next
  World::despawn(w, e2)
  let e4 = World::spawn(w)
  // e4 should reuse e2's index with incremented generation
  inspect(e4.index, content="1")
  inspect(e4.generation > e2.generation, content="true")
}

///|
test "generation advances on each reuse" {
  let w = World::new()
  let e1 = World::spawn(w)
  inspect(e1.generation, content="1")
  World::despawn(w, e1)
  let e2 = World::spawn(w)
  // despawn increments gen to 2, spawn-reuse increments to 3
  inspect(e2.generation, content="3")
  World::despawn(w, e2)
  let e3 = World::spawn(w)
  // despawn: 3→4, spawn-reuse: 4→5
  inspect(e3.generation, content="5")
}

///|
test "newly allocated slots start at generation 1" {
  let w = World::new()
  let e1 = World::spawn(w)
  inspect(e1.generation, content="1")
  let e2 = World::spawn(w)
  inspect(e2.generation, content="1")
  inspect(e1.index, content="0")
  inspect(e2.index, content="1")
}

///|
test "despawn increments generation to invalidate stale handle" {
  let w = World::new()
  let e = World::spawn(w)
  let idx = e.index
  let old_gen = e.generation
  World::despawn(w, e)
  // Despawn increments the slot generation past the entity's generation
  inspect(w.gens[idx] > old_gen, content="true")
}

///|
test "worlds have distinct world_id" {
  let w1 = World::new()
  let w2 = World::new()
  inspect(w1.world_id != w2.world_id, content="true")
}
