// --- Query Plan ---

///|
/// One Component-presence constraint on a QueryPlan: the slot identity,
/// its dense Entity array, and the erased membership check.
struct Constraint {
  slot_index : Int
  dense : Array[Entity]
  check : (Entity) -> Bool
}

///|
/// An immutable, reusable description of which Entities to visit.
/// Created from one or more required ComponentKeys and executed via `each`.
pub struct QueryPlan {
  world : World
  required : Array[Constraint]
  excluded : Array[Constraint]
}

///|
/// Builds a Constraint from a ComponentKey: the slot identity, its dense
/// Entity array, and the erased membership check. The slot is located via
/// the key, but the view is built from the erased pool — never key-owned
/// data. Shared by query construction and constraint appending.
fn[T] Constraint::from_key(key : ComponentKey[T]) -> Constraint {
  let slot = key.id.slot_index
  let pool = key.world.erased_pools[slot]
  Constraint::{
    slot_index: slot,
    dense: (pool.dense)(),
    check: pool.contains_entity,
  }
}

// --- Query construction ---

///|
/// Creates a QueryPlan from a required ComponentKey.
/// Raises `ForeignComponentKey` if the key belongs to a different World.
pub fn[T] World::query(
  self : World,
  key : ComponentKey[T],
) -> QueryPlan raise ECSError {
  if key.world.world_id != self.world_id {
    raise ECSError::ForeignComponentKey
  }
  // Constraint built from the erased pool via the shared constructor
  let required : Array[Constraint] = [Constraint::from_key(key)]
  let excluded : Array[Constraint] = []
  QueryPlan::{ world: self, required, excluded }
}

///|
/// Returns a new QueryPlan with an additional required ComponentKey.
/// The source plan remains unchanged. Adding the same key is idempotent.
/// Raises `ForeignComponentKey` if the key belongs to a different World.
/// Raises `ContradictoryQuery` if the key is already excluded.
pub fn[T] QueryPlan::add_required(
  self : QueryPlan,
  key : ComponentKey[T],
) -> QueryPlan raise ECSError {
  self.with_key_appended(key, true)
}

///|
/// Returns a new QueryPlan that excludes Entities having a Component in the
/// given slot. The source plan remains unchanged. Excluding the same key
/// twice is idempotent.
/// Raises `ForeignComponentKey` if the key belongs to a different World.
/// Raises `ContradictoryQuery` if the key is already required.
pub fn[T] QueryPlan::add_excluded(
  self : QueryPlan,
  key : ComponentKey[T],
) -> QueryPlan raise ECSError {
  self.with_key_appended(key, false)
}

///|
/// Returns a new plan with `key` appended to the required or excluded
/// constraint list, applying the foreign-key, contradiction, and
/// idempotency checks. Shared by add_required and add_excluded.
fn[T] QueryPlan::with_key_appended(
  self : QueryPlan,
  key : ComponentKey[T],
  to_required : Bool,
) -> QueryPlan raise ECSError {
  let (own, other) = if to_required {
    (self.required, self.excluded)
  } else {
    (self.excluded, self.required)
  }
  if key.world.world_id != self.world.world_id {
    raise ECSError::ForeignComponentKey
  }
  let slot = key.id.slot_index
  // Contradiction: key already in the other list
  if contains_slot(other, slot) {
    raise ECSError::ContradictoryQuery
  }
  // Idempotency: same slot already in the own list
  if contains_slot(own, slot) {
    self
  } else {
    let new_constraint = Constraint::from_key(key)
    let new_own : Array[Constraint] = []
    for i in 0..<own.length() {
      new_own.push(own[i])
    }
    new_own.push(new_constraint)
    if to_required {
      QueryPlan::{
        world: self.world,
        required: new_own,
        excluded: self.excluded,
      }
    } else {
      QueryPlan::{
        world: self.world,
        required: self.required,
        excluded: new_own,
      }
    }
  }
}

// --- Query execution ---

///|
/// Executes the QueryPlan, calling `body` for each matching live Entity.
/// The smallest required pool is chosen as the driver on each execution.
/// Raises `StructuralMutationDuringQuery` if the callback attempts mutation.
pub fn QueryPlan::each(
  self : QueryPlan,
  body : (Entity) -> Unit raise?,
) -> Unit raise? {
  self.world.query_depth = self.world.query_depth + 1
  // Select the smallest required pool as the driver
  let driver_idx = self.driver_index()
  let driver = self.required[driver_idx].dense
  let mut i = 0
  let n = driver.length()
  while i < n {
    let entity = driver[i]
    if self.world.is_alive(entity) && self.matches_all(entity, driver_idx) {
      body(entity) catch {
        err => {
          self.world.query_depth = self.world.query_depth - 1
          raise err
        }
      }
    }
    i = i + 1
  }
  self.world.query_depth = self.world.query_depth - 1
}

///|
/// Returns the index of the smallest required pool, chosen as the driver
/// for the next execution. Re-selected on every execution so the plan
/// observes current World state (ADR-0002). The driver's own membership
/// is implied by its dense array, so `matches_all` skips it.
fn QueryPlan::driver_index(self : QueryPlan) -> Int {
  let mut driver_idx = 0
  let mut best_len = self.required[0].dense.length()
  for i in 1..<self.required.length() {
    let len = self.required[i].dense.length()
    if len < best_len {
      best_len = len
      driver_idx = i
    }
  }
  driver_idx
}

///|
fn QueryPlan::matches_all(
  self : QueryPlan,
  entity : Entity,
  skip : Int,
) -> Bool {
  let mut ok = true
  let mut j = 0
  while j < self.required.length() {
    if j != skip && !(self.required[j].check)(entity) {
      ok = false
      j = self.required.length()
    } else {
      j = j + 1
    }
  }
  if ok {
    // Every excluded membership must be false
    let mut k = 0
    while k < self.excluded.length() {
      if (self.excluded[k].check)(entity) {
        ok = false
        k = self.excluded.length()
      } else {
        k = k + 1
      }
    }
  }
  ok
}

///|
fn contains_slot(constraints : Array[Constraint], slot : Int) -> Bool {
  let mut found = false
  for i in 0..<constraints.length() {
    if constraints[i].slot_index == slot {
      found = true
    }
  }
  found
}
