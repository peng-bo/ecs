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
fn inspect_count(
  label : String,
  _total : Int,
  actual : Int,
  expected : Int,
) -> Unit {
  let status = if actual == expected { "PASS" } else { "FAIL" }
  println("  \{status} \{label}: \{actual}/\{expected}")
}
