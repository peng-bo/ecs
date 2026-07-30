// --- Global World ID counter ---

///|
let next_world_id : Ref[Int] = { val: 0 }

// --- Error types ---

///|
/// Checked errors for recoverable ECS misuse.
pub(all) suberror ECSError {
  /// The Entity is stale (despawned or never valid).
  StaleEntity
  /// The Entity belongs to a different World.
  ForeignEntity
  /// The Entity allocator has no more capacity.
  EntityCapacityExhausted
} derive(Debug, Eq)

// --- Entity ---

///|
/// An opaque handle to a live Entity in a specific World.
/// Entity supports equality, hashing, and debug output without exposing
/// constructors or identity fields.
pub struct Entity {
  index : Int
  generation : Int
  world_id : Int
} derive(Debug, Eq, Hash)

// --- World ---

///|
/// An isolated ECS lifecycle boundary that creates and tracks Entities.
pub struct World {
  gens : Array[Int]
  free : Array[Int]
  mut live_count : Int
  world_id : Int
  mut next_slot_index : Int
}

// --- World public API ---

///|
/// Creates an empty World with no live Entities.
pub fn World::new() -> World {
  let wid = next_world_id.val
  next_world_id.val = next_world_id.val + 1
  { gens: [], free: [], live_count: 0, world_id: wid, next_slot_index: 0 }
}

///|
/// Returns the number of live Entities in the World.
pub fn World::len(self : World) -> Int {
  self.live_count
}

///|
/// Returns true if the World contains no live Entities.
pub fn World::is_empty(self : World) -> Bool {
  self.live_count == 0
}

///|
/// Spawns a new live Entity and returns an opaque handle to it.
/// Updates World length and emptiness.
///
/// Reuses despawned slots before allocating new ones. Each reuse
/// increments the slot's generation so the new Entity compares
/// unequal to every stale handle that occupied the same slot.
///
/// Raises `EntityCapacityExhausted` when the allocator cannot
/// allocate a new slot (all generation counters exhausted).
pub fn World::spawn(self : World) -> Entity raise ECSError {
  let (idx, gen) = if self.free.length() > 0 {
    // Reuse a despawned slot
    let i = self.free[self.free.length() - 1]
    ignore(self.free.remove(self.free.length() - 1))
    let next_gen = self.gens[i] + 1
    // Generation exhaustion: if incrementing would overflow, the slot
    // is permanently retired. For a 64-bit Int this is practically
    // unreachable, but the check preserves the specified contract.
    if next_gen < self.gens[i] {
      raise ECSError::EntityCapacityExhausted
    }
    self.gens[i] = next_gen
    (i, next_gen)
  } else {
    // Allocate a new slot
    let i = self.gens.length()
    let g = 1
    self.gens.push(g)
    (i, g)
  }
  self.live_count = self.live_count + 1
  Entity::{ index: idx, generation: gen, world_id: self.world_id }
}

///|
/// Despawns a live Entity, removing it from the World.
/// The Entity becomes permanently stale and can never become live again.
///
/// Raises `ForeignEntity` if the Entity belongs to a different World.
/// Raises `StaleEntity` if the Entity is already dead.
pub fn World::despawn(self : World, entity : Entity) -> Unit raise ECSError {
  if entity.world_id != self.world_id {
    raise ECSError::ForeignEntity
  }
  if entity.index >= self.gens.length() ||
    self.gens[entity.index] != entity.generation {
    raise ECSError::StaleEntity
  }
  // Increment generation to invalidate the stale handle
  self.gens[entity.index] = self.gens[entity.index] + 1
  self.free.push(entity.index)
  self.live_count = self.live_count - 1
}

///|
/// Returns true if the Entity is alive in this World.
/// An Entity is alive when its generation matches and it has not been despawned.
pub fn World::is_alive(self : World, entity : Entity) -> Bool {
  entity.world_id == self.world_id &&
  entity.index < self.gens.length() &&
  self.gens[entity.index] == entity.generation
}

///|
/// Registers a new Component Slot for payload type `T` and returns a typed
/// ComponentKey that provides access to the slot.
pub fn[T] World::register(self : World) -> ComponentKey[T] {
  let slot = self.next_slot_index
  self.next_slot_index = self.next_slot_index + 1
  let id = ComponentID::{ world_id: self.world_id, slot_index: slot }
  ComponentKey::{
    id,
    world: self,
    sparse: [],
    dense_entities: [],
    dense_payloads: [],
  }
}

// --- Component ID ---

///|
/// An opaque, World-local identity for a registered Component Slot.
/// Supports equality and debug output.
pub struct ComponentID {
  world_id : Int
  slot_index : Int
} derive(Debug, Eq)

// --- Component Key ---

///|
/// An unforgeable typed handle for one Component Slot in one World.
/// Provides set, get, contains, len, and is_empty operations on that slot.
pub struct ComponentKey[T] {
  id : ComponentID
  world : World
  sparse : Array[Int]
  dense_entities : Array[Entity]
  dense_payloads : Array[T]
}

///|
/// Returns the ComponentID of this slot.
pub fn[T] ComponentKey::id(self : ComponentKey[T]) -> ComponentID {
  self.id
}

///|
/// Returns the number of Entities that have a Component in this slot.
pub fn[T] ComponentKey::len(self : ComponentKey[T]) -> Int {
  self.dense_entities.length()
}

///|
/// Returns true if no Entity has a Component in this slot.
pub fn[T] ComponentKey::is_empty(self : ComponentKey[T]) -> Bool {
  self.dense_entities.length() == 0
}

// --- Private helpers (must be defined before use) ---

///|
fn[T] ComponentKey::validate_entity(
  self : ComponentKey[T],
  entity : Entity,
) -> Unit raise ECSError {
  if entity.world_id != self.world.world_id {
    raise ECSError::ForeignEntity
  }
  if entity.index >= self.world.gens.length() ||
    self.world.gens[entity.index] != entity.generation {
    raise ECSError::StaleEntity
  }
}

///|
fn[T] ComponentKey::grow_sparse(self : ComponentKey[T], index : Int) -> Unit {
  while self.sparse.length() <= index {
    self.sparse.push(-1)
  }
}

///|
fn[T] ComponentKey::sparse_lookup(
  self : ComponentKey[T],
  entity : Entity,
) -> Int {
  if entity.index < self.sparse.length() {
    self.sparse[entity.index]
  } else {
    -1
  }
}

// --- ComponentKey public operations ---

///|
/// Returns true if the Entity has a Component in this slot.
/// Raises `StaleEntity` or `ForeignEntity` for invalid Entities.
pub fn[T] ComponentKey::contains(
  self : ComponentKey[T],
  entity : Entity,
) -> Bool raise ECSError {
  self.validate_entity(entity)
  self.sparse_lookup(entity) >= 0
}

///|
/// Returns the Component value for the Entity, or `None` if absent.
/// Raises `StaleEntity` or `ForeignEntity` for invalid Entities.
pub fn[T] ComponentKey::get(
  self : ComponentKey[T],
  entity : Entity,
) -> T? raise ECSError {
  self.validate_entity(entity)
  let dense_idx = self.sparse_lookup(entity)
  if dense_idx >= 0 {
    Some(self.dense_payloads[dense_idx])
  } else {
    None
  }
}

///|
/// Sets the Component value for the Entity.
/// Returns `None` on first insertion; returns `Some(previous)` on replacement.
/// Raises `StaleEntity` or `ForeignEntity` for invalid Entities.
pub fn[T] ComponentKey::set(
  self : ComponentKey[T],
  entity : Entity,
  value : T,
) -> T? raise ECSError {
  self.validate_entity(entity)
  self.grow_sparse(entity.index)
  let dense_idx = self.sparse[entity.index]
  if dense_idx >= 0 {
    let old = self.dense_payloads[dense_idx]
    self.dense_payloads[dense_idx] = value
    Some(old)
  } else {
    let new_idx = self.dense_entities.length()
    self.sparse[entity.index] = new_idx
    self.dense_entities.push(entity)
    self.dense_payloads.push(value)
    None
  }
}

///|
/// Removes the Entity's Component from this slot and returns its payload.
/// Returns `None` if the Entity had no Component in this slot.
/// Uses swap-remove to keep dense arrays contiguous.
/// Raises `StaleEntity` or `ForeignEntity` for invalid Entities.
pub fn[T] ComponentKey::remove(
  self : ComponentKey[T],
  entity : Entity,
) -> T? raise ECSError {
  self.validate_entity(entity)
  let dense_idx = self.sparse_lookup(entity)
  if dense_idx < 0 {
    None
  } else {
    let last_idx = self.dense_entities.length() - 1
    let removed = self.dense_payloads[dense_idx]
    if dense_idx != last_idx {
      // Swap-remove: move last element into the removed slot
      let last_entity = self.dense_entities[last_idx]
      self.dense_entities[dense_idx] = last_entity
      self.dense_payloads[dense_idx] = self.dense_payloads[last_idx]
      // Repair the moved entity's sparse mapping
      self.sparse[last_entity.index] = dense_idx
    }
    // Pop the last element
    ignore(self.dense_entities.remove(last_idx))
    ignore(self.dense_payloads.remove(last_idx))
    self.sparse[entity.index] = -1
    Some(removed)
  }
}

///|
/// Clears every Component from this slot without despawning any Entity.
/// After clear, the slot is empty and its length reports zero.
pub fn[T] ComponentKey::clear(self : ComponentKey[T]) -> Unit {
  for i in 0..<self.dense_entities.length() {
    self.sparse[self.dense_entities[i].index] = -1
  }
  while self.dense_entities.length() > 0 {
    ignore(self.dense_entities.remove(self.dense_entities.length() - 1))
    ignore(self.dense_payloads.remove(self.dense_payloads.length() - 1))
  }
}
