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

// --- #5: Sparse-set swap-remove integrity ---

///|
test "remove updates sparse-to-dense mapping correctly" {
  let w = World::new()
  let e0 = World::spawn(w)
  let e1 = World::spawn(w)
  let e2 = World::spawn(w)
  let k : ComponentKey[Int] = World::register(w)
  ignore(k.set(e0, 10))
  ignore(k.set(e1, 20))
  ignore(k.set(e2, 30))
  // Before remove: dense = [10, 20, 30], sparse[e0]=0, sparse[e1]=1, sparse[e2]=2
  inspect(k.sparse_lookup(e0), content="0")
  inspect(k.sparse_lookup(e1), content="1")
  inspect(k.sparse_lookup(e2), content="2")
  // Remove e1 (middle): swap-remove brings e2's dense index to 1
  ignore(k.remove(e1))
  inspect(k.sparse_lookup(e1), content="-1")
  inspect(k.sparse_lookup(e2), content="1")
  inspect(k.dense_entities.length(), content="2")
  inspect(k.dense_payloads[0], content="10")
  inspect(k.dense_payloads[1], content="30")
}

///|
test "remove last element just pops without swap" {
  let w = World::new()
  let e0 = World::spawn(w)
  let e1 = World::spawn(w)
  let k : ComponentKey[Int] = World::register(w)
  ignore(k.set(e0, 10))
  ignore(k.set(e1, 20))
  ignore(k.remove(e1))
  inspect(k.sparse_lookup(e1), content="-1")
  inspect(k.sparse_lookup(e0), content="0")
  inspect(k.dense_entities.length(), content="1")
}

///|
test "clear resets sparse and empties dense arrays" {
  let w = World::new()
  let e0 = World::spawn(w)
  let e1 = World::spawn(w)
  let k : ComponentKey[Int] = World::register(w)
  ignore(k.set(e0, 10))
  ignore(k.set(e1, 20))
  k.clear()
  inspect(k.dense_entities.length(), content="0")
  inspect(k.sparse_lookup(e0), content="-1")
  inspect(k.sparse_lookup(e1), content="-1")
}

///|
test "remove absent entity does not modify slot" {
  let w = World::new()
  let e = World::spawn(w)
  let k : ComponentKey[Int] = World::register(w)
  let pre_len = k.dense_entities.length()
  ignore(k.remove(e))
  inspect(k.dense_entities.length(), content="0")
  inspect(pre_len, content="0")
}

///|
test "erased pool exposes dense entity array" {
  let w = World::new()
  let e0 = World::spawn(w)
  let e1 = World::spawn(w)
  let k : ComponentKey[Int] = World::register(w)
  ignore(k.set(e0, 10))
  ignore(k.set(e1, 20))
  // ErasedPool at slot_index 0 exposes the same dense array as the key
  let dense = (w.erased_pools[0].dense)()
  inspect(dense.length(), content="2")
  inspect(dense[0] == e0, content="true")
  inspect(dense[1] == e1, content="true")
}

///|
test "erased pool dense tracks removals" {
  let w = World::new()
  let e0 = World::spawn(w)
  let e1 = World::spawn(w)
  let k : ComponentKey[Int] = World::register(w)
  ignore(k.set(e0, 10))
  ignore(k.set(e1, 20))
  ignore(k.remove(e0))
  let dense = (w.erased_pools[0].dense)()
  inspect(dense.length(), content="1")
  inspect(dense[0] == e1, content="true")
}
