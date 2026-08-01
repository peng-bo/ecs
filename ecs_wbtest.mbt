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
test "spawn raises EntityCapacityExhausted when reuse would overflow" {
  let w = World::new()
  w.gens.push(2147483647) // slot 0 at max generation
  w.free.push(0)
  try World::spawn(w) catch {
    ECSError::EntityCapacityExhausted =>
      inspect("exhausted", content="exhausted")
    _ => fail("expected EntityCapacityExhausted")
  } noraise {
    _ => fail("expected EntityCapacityExhausted")
  }
  // The exhausted slot is retired — removed from the free list
  inspect(w.free.length(), content="0")
}

///|
test "despawn raises EntityCapacityExhausted without mutating state" {
  let w = World::new()
  w.gens.push(2147483647) // slot 0 at max generation
  let e = Entity::{ index: 0, generation: 2147483647, world_id: w.world_id }
  try World::despawn(w, e) catch {
    ECSError::EntityCapacityExhausted =>
      inspect("exhausted", content="exhausted")
    _ => fail("expected EntityCapacityExhausted")
  } noraise {
    _ => fail("expected EntityCapacityExhausted")
  }
  // Zero state change: generation untouched, slot not freed, count intact
  inspect(w.gens[0] == 2147483647, content="true")
  inspect(w.free.length(), content="0")
  inspect(w.live_count, content="0")
}

///|
test "clear raises EntityCapacityExhausted without mutating state" {
  let w = World::new()
  w.gens.push(2147483647) // slot 0 at max generation
  let e = Entity::{ index: 0, generation: 2147483647, world_id: w.world_id }
  let k : ComponentKey[Int] = World::register(w)
  ignore(k.set(e, 10))
  try World::clear(w) catch {
    ECSError::EntityCapacityExhausted =>
      inspect("exhausted", content="exhausted")
    _ => fail("expected EntityCapacityExhausted")
  } noraise {
    _ => fail("expected EntityCapacityExhausted")
  }
  // Zero state change: components untouched, generation unchanged
  inspect(k.dense_entities.length(), content="1")
  inspect(w.gens[0] == 2147483647, content="true")
}

// --- #55: unified structural-mutation prologue ---

///|
test "prologue validates entity before guarding during query" {
  let w = World::new()
  let e = World::spawn(w)
  World::despawn(w, e)
  w.query_depth = 1
  // Stale entity wins over the active-query guard (error precedence)
  try w.ensure_structural_mutation_ready(entity=e) catch {
    ECSError::StaleEntity => inspect("stale first", content="stale first")
    _ => fail("expected StaleEntity, not StructuralMutationDuringQuery")
  } noraise {
    _ => fail("expected StaleEntity, not StructuralMutationDuringQuery")
  }
}

///|
test "prologue guards structural mutation during query" {
  let w = World::new()
  let e = World::spawn(w)
  w.query_depth = 1
  try w.ensure_structural_mutation_ready(entity=e) catch {
    ECSError::StructuralMutationDuringQuery =>
      inspect("guarded", content="guarded")
    _ => fail("expected StructuralMutationDuringQuery")
  } noraise {
    _ => fail("expected StructuralMutationDuringQuery")
  }
  // Guard-only path (no entity) also rejects during query
  try w.ensure_structural_mutation_ready() catch {
    ECSError::StructuralMutationDuringQuery =>
      inspect("guarded", content="guarded")
    _ => fail("expected StructuralMutationDuringQuery")
  } noraise {
    _ => fail("expected StructuralMutationDuringQuery")
  }
}

///|
test "prologue passes when idle" {
  let w = World::new()
  let e = World::spawn(w)
  w.ensure_structural_mutation_ready(entity=e)
  w.ensure_structural_mutation_ready()
  inspect("ready", content="ready")
}

// --- #55: unified generation advancement ---

///|
test "advance_generation advances and returns the new generation" {
  let w = World::new()
  w.gens.push(1)
  let next = w.advance_generation(0)
  inspect(next, content="2")
  inspect(w.gens[0], content="2")
}

///|
test "advance_generation raises without mutating on overflow" {
  let w = World::new()
  w.gens.push(2147483647) // slot 0 at max generation
  try w.advance_generation(0) catch {
    ECSError::EntityCapacityExhausted =>
      inspect("exhausted", content="exhausted")
    _ => fail("expected EntityCapacityExhausted")
  } noraise {
    _ => fail("expected EntityCapacityExhausted")
  }
  inspect(w.gens[0] == 2147483647, content="true")
}

///|
test "generation_can_advance reflects overflow risk" {
  let w = World::new()
  w.gens.push(2147483647) // slot 0 at max generation
  w.gens.push(1)
  inspect(w.generation_can_advance(0), content="false")
  inspect(w.generation_can_advance(1), content="true")
}

///|
test "constraint from key mirrors slot state" {
  let w = World::new()
  let e0 = World::spawn(w)
  let e1 = World::spawn(w)
  let k : ComponentKey[Int] = World::register(w)
  ignore(k.set(e0, 10))
  let c = Constraint::from_key(k)
  // Slot identity comes from the key
  inspect(c.slot_index, content="0")
  // Dense view mirrors the pool's dense array
  inspect(c.dense.length(), content="1")
  inspect(c.dense[0] == e0, content="true")
  // Membership check matches slot state
  inspect((c.check)(e0), content="true")
  inspect((c.check)(e1), content="false")
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

// --- #56: ComponentKey owns its own construction ---

///|
test "component key constructor initializes empty storage" {
  let w = World::new()
  let id = ComponentID::{ world_id: w.world_id, slot_index: 3 }
  let k : ComponentKey[Int] = ComponentKey::new(id, w)
  // Identity and World provenance come from the arguments
  inspect(k.id == id, content="true")
  inspect(k.world.world_id == w.world_id, content="true")
  // Storage starts empty — ready for first insertion
  inspect(k.sparse.length(), content="0")
  inspect(k.dense_entities.length(), content="0")
  inspect(k.dense_payloads.length(), content="0")
}

// --- #58: query driver selection strategy ---

///|
test "driver index picks the smallest required pool" {
  let w = World::new()
  let k_a : ComponentKey[Int] = World::register(w)
  let k_b : ComponentKey[Int] = World::register(w)
  // k_a holds more entities than k_b
  for _ in 0..<5 {
    let e = World::spawn(w)
    ignore(k_a.set(e, 1))
  }
  let e_small = World::spawn(w)
  ignore(k_a.set(e_small, 1))
  ignore(k_b.set(e_small, 2))
  let plan = World::query(w, k_a)
  let plan = QueryPlan::add_required(plan, k_b)
  // k_b (1 entry) is smaller than k_a (6 entries)
  inspect(plan.driver_index(), content="1")
}

///|
test "driver index re-selects when pool sizes change" {
  let w = World::new()
  let k_a : ComponentKey[Int] = World::register(w)
  let k_b : ComponentKey[Int] = World::register(w)
  let e1 = World::spawn(w)
  ignore(k_a.set(e1, 1))
  ignore(k_b.set(e1, 2))
  let plan = World::query(w, k_a)
  let plan = QueryPlan::add_required(plan, k_b)
  // Equal sizes: the first required pool wins
  inspect(plan.driver_index(), content="0")
  // Grow k_a: k_b becomes the driver
  let e2 = World::spawn(w)
  ignore(k_a.set(e2, 1))
  inspect(plan.driver_index(), content="1")
}
