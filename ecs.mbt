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
}

// --- World public API ---

///|
/// Creates an empty World with no live Entities.
pub fn World::new() -> World {
  let wid = next_world_id.val
  next_world_id.val = next_world_id.val + 1
  { gens: [], free: [], live_count: 0, world_id: wid }
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
