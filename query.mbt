// --- Erased pool (private, type-erased lifecycle operations) ---

///|
struct ErasedPool {
  remove_entity : (Entity) -> Unit
  clear_all : () -> Unit raise ECSError
  contains_entity : (Entity) -> Bool
  dense : () -> Array[Entity]
}

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
  // Constraint built from the erased pool — never key internals
  let pool = self.erased_pools[key.id.slot_index]
  let required : Array[Constraint] = [
    Constraint::{
      slot_index: key.id.slot_index,
      dense: (pool.dense)(),
      check: pool.contains_entity,
    },
  ]
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
  if key.world.world_id != self.world.world_id {
    raise ECSError::ForeignComponentKey
  }
  let slot = key.id.slot_index
  // Contradiction: key already excluded
  if self.contains_slot(self.excluded, slot) {
    raise ECSError::ContradictoryQuery
  }
  // Idempotency: same slot already required
  if self.contains_slot(self.required, slot) {
    self
  } else {
    let pool = key.world.erased_pools[slot]
    let new_constraint = Constraint::{
      slot_index: slot,
      dense: (pool.dense)(),
      check: pool.contains_entity,
    }
    let new_required : Array[Constraint] = []
    for i in 0..<self.required.length() {
      new_required.push(self.required[i])
    }
    new_required.push(new_constraint)
    QueryPlan::{
      world: self.world,
      required: new_required,
      excluded: self.excluded,
    }
  }
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
  if key.world.world_id != self.world.world_id {
    raise ECSError::ForeignComponentKey
  }
  let slot = key.id.slot_index
  // Contradiction: key already required
  if self.contains_slot(self.required, slot) {
    raise ECSError::ContradictoryQuery
  }
  // Idempotency: same slot already excluded
  if self.contains_slot(self.excluded, slot) {
    self
  } else {
    let pool = key.world.erased_pools[slot]
    let new_constraint = Constraint::{
      slot_index: slot,
      dense: (pool.dense)(),
      check: pool.contains_entity,
    }
    let new_excluded : Array[Constraint] = []
    for i in 0..<self.excluded.length() {
      new_excluded.push(self.excluded[i])
    }
    new_excluded.push(new_constraint)
    QueryPlan::{
      world: self.world,
      required: self.required,
      excluded: new_excluded,
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
  body : (Entity) -> Unit raise ECSError,
) -> Unit raise ECSError {
  self.world.query_depth = self.world.query_depth + 1
  // Select the smallest required pool as the driver
  let mut driver_idx = 0
  let mut best = self.required[0]
  for i in 1..<self.required.length() {
    if self.required[i].dense.length() < best.dense.length() {
      best = self.required[i]
      driver_idx = i
    }
  }
  let driver = best.dense
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
fn QueryPlan::contains_slot(
  self : QueryPlan,
  constraints : Array[Constraint],
  slot : Int,
) -> Bool {
  let mut found = false
  for i in 0..<constraints.length() {
    if constraints[i].slot_index == slot {
      found = true
    }
  }
  found
}
