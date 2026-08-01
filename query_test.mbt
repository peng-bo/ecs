// --- Query Plan: construction, execution, mutation guards ---
// --- #9: Execute a guarded single-Slot Query Plan ---

///|
test "query visits all entities with matching component" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  let _e3 = @ecs.World::spawn(w)
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  ignore(@ecs.ComponentKey::set(k, e1, 1))
  ignore(@ecs.ComponentKey::set(k, e2, 2))
  // e3 has no component — should not appear in query
  let plan = @ecs.World::query(w, k)
  let mut count = 0
  @ecs.QueryPlan::each(plan, fn(_e : @ecs.Entity) -> Unit { count = count + 1 })
  inspect(count, content="2")
}

///|
test "query with no matching entities runs body zero times" {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let plan = @ecs.World::query(w, k)
  let mut ran = false
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit { ran = true })
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
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit { c1 = c1 + 1 })
  inspect(c1, content="1")
  // Add another entity and reuse plan
  let e2 = @ecs.World::spawn(w)
  ignore(@ecs.ComponentKey::set(k, e2, 20))
  let mut c2 = 0
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit { c2 = c2 + 1 })
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
  debug_inspect(@ecs.ComponentKey::get(k, e), content="Some(99)")
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
  @ecs.QueryPlan::each(plan1, fn(_e) -> Unit { c1 = c1 + 1 })
  let mut c2 = 0
  @ecs.QueryPlan::each(plan2, fn(_e) -> Unit { c2 = c2 + 1 })
  inspect(c1, content="0")
  inspect(c2, content="0")
}

///|
test "multi-required query matches entities with all components" {
  let w = @ecs.World::new()
  let e1 = @ecs.World::spawn(w)
  let e2 = @ecs.World::spawn(w)
  let _e3 = @ecs.World::spawn(w)
  let k_i : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k_s : @ecs.ComponentKey[String] = @ecs.World::register(w)
  // e1: both, e2: Int only, e3: neither
  ignore(@ecs.ComponentKey::set(k_i, e1, 1))
  ignore(@ecs.ComponentKey::set(k_s, e1, "a"))
  ignore(@ecs.ComponentKey::set(k_i, e2, 2))
  let plan = @ecs.World::query(w, k_i)
  let plan = @ecs.QueryPlan::add_required(plan, k_s)
  let mut count = 0
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit { count = count + 1 })
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
  @ecs.QueryPlan::each(plan1, fn(_e) -> Unit { c1 = c1 + 1 })
  let mut c2 = 0
  @ecs.QueryPlan::each(plan2, fn(_e) -> Unit { c2 = c2 + 1 })
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
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit { count = count + 1 })
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
  @ecs.QueryPlan::each(plan1, fn(_e) -> Unit { c1 = c1 + 1 })
  let mut c2 = 0
  @ecs.QueryPlan::each(plan2, fn(_e) -> Unit { c2 = c2 + 1 })
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
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit { count = count + 1 })
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
  @ecs.QueryPlan::each(plan2, fn(_e) -> Unit { c2 = c2 + 1 })
  let mut c3 = 0
  @ecs.QueryPlan::each(plan3, fn(_e) -> Unit { c3 = c3 + 1 })
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
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit { count = count + 1 })
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
  @ecs.QueryPlan::each(plan, _e => {
    outer = outer + 1
    @ecs.QueryPlan::each(plan, _e2 => inner = inner + 1)
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
  debug_inspect(@ecs.ComponentKey::get(k, e), content="Some(99)")
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
  debug_inspect(@ecs.ComponentKey::get(k, e), content="Some(99)")
}
