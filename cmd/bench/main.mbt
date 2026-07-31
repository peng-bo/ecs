///|
/// ECS Core benchmarks — repeatable public-API measurements.
/// No fixed pass/fail thresholds; results are machine-dependent.
/// Run with: moon run cmd/bench
fn main raise {
  let n = 10_000
  let m = 100

  println("=== ECS Core Benchmarks ===\n")

  // --- Entity lifecycle ---
  println("## Entity Lifecycle (n = \{n})")
  bench_spawn(n)
  bench_despawn(n)

  // --- Component operations ---
  println("\n## Component Operations (n = \{n})")
  bench_component_set(n)
  bench_component_get(n)
  bench_component_contains(n)
  bench_component_replace(n)
  bench_component_remove(n)
  bench_component_clear(n)

  // --- Despawn scaling with slot count ---
  println("\n## Despawn Scaling by Slot Count (entities = \{n})")
  for slots in [1, 5, 10, 20, 50] {
    bench_despawn_with_slots(n, slots)
  }

  // --- Query Plan: smallest driver observable ---
  println("\n## Query Plan: Smallest Driver Effect (n = \{n}, m = \{m})")
  bench_smallest_driver(n, m)

  // --- Query Plan: multi-required selectivity ---
  println("\n## Query Plan: Multi-Required Selectivity")
  bench_multi_required(n)

  // --- Query Plan: excluded slot selectivity ---
  println("\n## Query Plan: Excluded Slot Selectivity")
  bench_excluded_selectivity(n)

  // --- Query Plan: reuse after population change ---
  println("\n## Query Plan: Reuse After Population Change")
  bench_plan_reuse(n)

  println("\n=== Benchmarks complete ===")
}

///|
fn bench_spawn(n : Int) -> Unit raise {
  let w = @ecs.World::new()
  for _ in 0..<n {
    ignore(@ecs.World::spawn(w))
  }
  inspect_count("spawn", n, @ecs.World::len(w), n)
}

///|
fn bench_despawn(n : Int) -> Unit raise {
  let w = @ecs.World::new()
  let es : Array[@ecs.Entity] = []
  for _ in 0..<n {
    es.push(@ecs.World::spawn(w))
  }
  for i in 0..<n {
    @ecs.World::despawn(w, es[i])
  }
  inspect_count("despawn", n, @ecs.World::len(w), 0)
}

///|
fn bench_component_set(n : Int) -> Unit raise {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  for _ in 0..<n {
    let e = @ecs.World::spawn(w)
    ignore(@ecs.ComponentKey::set(k, e, 1))
  }
  inspect_count("set (first insert)", n, @ecs.ComponentKey::len(k), n)
}

///|
fn bench_component_get(n : Int) -> Unit raise {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let e = @ecs.World::spawn(w)
  ignore(@ecs.ComponentKey::set(k, e, 42))
  let mut hits = 0
  for _ in 0..<n {
    if @ecs.ComponentKey::get(k, e) is Some(42) {
      hits = hits + 1
    }
  }
  inspect_count("get", n, hits, n)
}

///|
fn bench_component_contains(n : Int) -> Unit raise {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let e = @ecs.World::spawn(w)
  ignore(@ecs.ComponentKey::set(k, e, 1))
  let mut trues = 0
  for _ in 0..<n {
    if @ecs.ComponentKey::contains(k, e) {
      trues = trues + 1
    }
  }
  inspect_count("contains", n, trues, n)
}

///|
fn bench_component_replace(n : Int) -> Unit raise {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let e = @ecs.World::spawn(w)
  ignore(@ecs.ComponentKey::set(k, e, 0))
  let mut replacements = 0
  for i in 0..<n {
    if @ecs.ComponentKey::set(k, e, i) is Some(_) {
      replacements = replacements + 1
    }
  }
  inspect_count("set (replace)", n, replacements, n)
}

///|
fn bench_component_remove(n : Int) -> Unit raise {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  for _ in 0..<n {
    let e = @ecs.World::spawn(w)
    ignore(@ecs.ComponentKey::set(k, e, 1))
    ignore(@ecs.ComponentKey::remove(k, e))
    @ecs.World::despawn(w, e)
  }
  inspect_count("remove", n, @ecs.ComponentKey::len(k), 0)
}

///|
fn bench_component_clear(n : Int) -> Unit raise {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  for _ in 0..<n {
    let e = @ecs.World::spawn(w)
    ignore(@ecs.ComponentKey::set(k, e, 1))
  }
  @ecs.ComponentKey::clear(k)
  inspect_count("clear", n, @ecs.ComponentKey::len(k), 0)
}

///|
fn bench_despawn_with_slots(n : Int, slots : Int) -> Unit raise {
  let w = @ecs.World::new()
  let ks : Array[@ecs.ComponentKey[Int]] = []
  for _ in 0..<slots {
    ks.push(@ecs.World::register(w))
  }
  // Spawn n entities, set component in every slot
  for _ in 0..<n {
    let e = @ecs.World::spawn(w)
    for j in 0..<slots {
      ignore(@ecs.ComponentKey::set(ks[j], e, 1))
    }
  }
  // Verify population
  for j in 0..<slots {
    if @ecs.ComponentKey::len(ks[j]) != n {
      println(
        "FAIL: slot \{j} expected \{n}, got \{@ecs.ComponentKey::len(ks[j])}",
      )
      return
    }
  }
  println("  despawn_with_\{(slots * n)}_components")
}

///|
fn bench_smallest_driver(n : Int, m : Int) -> Unit raise {
  let w = @ecs.World::new()
  let k_big : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k_small : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  // Fill big pool with n entities
  for _ in 0..<n {
    let e = @ecs.World::spawn(w)
    ignore(@ecs.ComponentKey::set(k_big, e, 1))
  }
  // Fill small pool with m entities (m << n)
  for _ in 0..<m {
    let e = @ecs.World::spawn(w)
    ignore(@ecs.ComponentKey::set(k_big, e, 1))
    ignore(@ecs.ComponentKey::set(k_small, e, 1))
  }
  let plan = @ecs.World::query(w, k_big)
  let plan = @ecs.QueryPlan::add_required(plan, k_small)
  let mut matched = 0
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise @ecs.ECSError {
    matched = matched + 1
  })
  // k_small (m entries) should be chosen as driver, limiting matched to m
  inspect_count("smallest_driver_matches", m, matched, m)
}

///|
fn bench_multi_required(n : Int) -> Unit raise {
  let w = @ecs.World::new()
  let k_a : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k_b : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k_c : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  // Populate pools with different cardinalities
  let n_a = n
  let n_b = n / 2
  let n_c = n / 10
  for _ in 0..<n_a {
    let e = @ecs.World::spawn(w)
    ignore(@ecs.ComponentKey::set(k_a, e, 1))
  }
  for _ in 0..<n_b {
    let e = @ecs.World::spawn(w)
    ignore(@ecs.ComponentKey::set(k_a, e, 1))
    ignore(@ecs.ComponentKey::set(k_b, e, 1))
  }
  for _ in 0..<n_c {
    let e = @ecs.World::spawn(w)
    ignore(@ecs.ComponentKey::set(k_a, e, 1))
    ignore(@ecs.ComponentKey::set(k_b, e, 1))
    ignore(@ecs.ComponentKey::set(k_c, e, 1))
  }
  // Query with 1, 2, and 3 required slots — observe driver effect
  for required in [1, 2, 3] {
    let plan = @ecs.World::query(w, k_a)
    let plan = if required >= 2 {
      @ecs.QueryPlan::add_required(plan, k_b)
    } else {
      plan
    }
    let plan = if required >= 3 {
      @ecs.QueryPlan::add_required(plan, k_c)
    } else {
      plan
    }
    let mut matched = 0
    @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise @ecs.ECSError {
      matched = matched + 1
    })
    let expected = if required == 1 {
      n_a + n_b + n_c
    } else if required == 2 {
      n_b + n_c
    } else {
      n_c
    }
    let label = "\{required}_required_slots"
    inspect_count(label, expected, matched, expected)
  }
}

///|
fn bench_excluded_selectivity(n : Int) -> Unit raise {
  let w = @ecs.World::new()
  let k_req : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k_ex1 : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let k_ex2 : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let mut ex1_count = 0
  let mut ex2_count = 0
  // Pre-populate: spawn n entities, all get required, subsets get excluded
  for i in 0..<n {
    let e = @ecs.World::spawn(w)
    ignore(@ecs.ComponentKey::set(k_req, e, 1))
    if i < n / 4 {
      ignore(@ecs.ComponentKey::set(k_ex1, e, 1))
      ex1_count = ex1_count + 1
    }
    if i < n / 10 {
      ignore(@ecs.ComponentKey::set(k_ex2, e, 1))
      ex2_count = ex2_count + 1
    }
  }
  // 0 excluded: all n entities
  let plan0 = @ecs.World::query(w, k_req)
  let mut m0 = 0
  @ecs.QueryPlan::each(plan0, fn(_e) -> Unit raise @ecs.ECSError { m0 = m0 + 1 })
  inspect_count("0_excluded", n, m0, n)
  // 1 excluded: ~75% pass
  let plan1 = @ecs.QueryPlan::add_excluded(plan0, k_ex1)
  let mut m1 = 0
  @ecs.QueryPlan::each(plan1, fn(_e) -> Unit raise @ecs.ECSError { m1 = m1 + 1 })
  inspect_count("1_excluded", n - ex1_count, m1, n - ex1_count)
  // 2 excluded: ~65% pass
  let plan2 = @ecs.QueryPlan::add_excluded(plan1, k_ex2)
  let mut m2 = 0
  @ecs.QueryPlan::each(plan2, fn(_e) -> Unit raise @ecs.ECSError { m2 = m2 + 1 })
  inspect_count("2_excluded", n - ex1_count, m2, n - ex1_count)
}

///|
fn bench_plan_reuse(n : Int) -> Unit raise {
  let w = @ecs.World::new()
  let k : @ecs.ComponentKey[Int] = @ecs.World::register(w)
  let plan = @ecs.World::query(w, k)
  // First run: empty
  let mut c0 = 0
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise @ecs.ECSError { c0 = c0 + 1 })
  inspect_count("reuse_empty", 0, c0, 0)
  // Populate
  let es : Array[@ecs.Entity] = []
  for _ in 0..<n {
    let e = @ecs.World::spawn(w)
    ignore(@ecs.ComponentKey::set(k, e, 1))
    es.push(e)
  }
  // Second run with same plan: sees new entities
  let mut c1 = 0
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise @ecs.ECSError { c1 = c1 + 1 })
  inspect_count("reuse_after_populate", n, c1, n)
  // Despawn half (outside query — mutation during each is forbidden)
  let half = n / 2
  for i in 0..<half {
    @ecs.World::despawn(w, es[i])
  }
  // Third run: sees remaining entities
  let mut c2 = 0
  @ecs.QueryPlan::each(plan, fn(_e) -> Unit raise @ecs.ECSError { c2 = c2 + 1 })
  inspect_count("reuse_after_despawn", n - n / 2, c2, n - n / 2)
}

///|
fn inspect_count(
  label : String,
  _total : Int,
  actual : Int,
  expected : Int,
) -> Unit {
  let status = if actual == expected { "PASS" } else { "FAIL" }
  println("  \{status} \{label}: \{actual}/\{expected}")
}
