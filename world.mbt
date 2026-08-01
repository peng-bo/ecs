// --- World ---

///|
/// An isolated ECS lifecycle boundary that creates and tracks Entities.
pub struct World {
  gens : Array[Int]
  free : Array[Int]
  mut live_count : Int
  world_id : Int
  mut next_slot_index : Int
  erased_pools : Array[ErasedPool]
  mut query_depth : Int
}

// --- World public API ---

///|
/// Creates an empty World with no live Entities.
pub fn World::new() -> World {
  let wid = next_world_id.val
  next_world_id.val = next_world_id.val + 1
  {
    gens: [],
    free: [],
    live_count: 0,
    world_id: wid,
    next_slot_index: 0,
    erased_pools: [],
    query_depth: 0,
  }
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
  self.ensure_structural_mutation_ready()
  let (idx, gen) = if self.free.length() > 0 {
    // Reuse a despawned slot
    let i = self.free[self.free.length() - 1]
    // Generation exhaustion: if incrementing would overflow, retire the
    // slot (it can never be reused) and report the exhausted allocator.
    // The check precedes the pop, so an available slot is never lost to
    // a failed reuse. For an Int generation counter this is practically
    // unreachable, but the check preserves the specified contract.
    if !self.generation_can_advance(i) {
      ignore(self.free.remove(self.free.length() - 1))
      raise ECSError::EntityCapacityExhausted
    }
    ignore(self.free.remove(self.free.length() - 1))
    let next_gen = self.advance_generation(i)
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
  // Unified prologue: validate first (Stale/Foreign even during a query),
  // then the structural guard. advance_generation checks overflow before
  // mutating any state, so a raise leaves the World untouched and the
  // Entity still live. The generation is written before the pool cleanup
  // below — safe because pool cleanup (remove_entity) cannot raise.
  self.ensure_structural_mutation_ready(entity~)
  ignore(self.advance_generation(entity.index))
  // Remove entity from every registered Component Slot
  for i in 0..<self.erased_pools.length() {
    (self.erased_pools[i].remove_entity)(entity)
  }
  self.free.push(entity.index)
  self.live_count = self.live_count - 1
}

///|
/// Raises `ForeignEntity` if the Entity belongs to a different World,
/// `StaleEntity` if the Entity is no longer alive in this World.
/// The single source of truth for Entity liveness in this World.
fn World::ensure_alive(self : World, entity : Entity) -> Unit raise ECSError {
  if entity.world_id != self.world_id {
    raise ECSError::ForeignEntity
  }
  if entity.index >= self.gens.length() ||
    self.gens[entity.index] != entity.generation {
    raise ECSError::StaleEntity
  }
}

///|
/// Returns true if the Entity is alive in this World.
/// An Entity is alive when its generation matches and it has not been despawned.
pub fn World::is_alive(self : World, entity : Entity) -> Bool {
  try {
    self.ensure_alive(entity)
    true
  } catch {
    _ => false
  }
}

///|
/// Clears the World: removes all Entities and Component values from every
/// registered slot. Registered Component Slots, Component IDs, and Component
/// Keys remain valid for reuse. Every Entity issued before the clear becomes
/// permanently stale.
pub fn World::clear(self : World) -> Unit raise ECSError {
  self.ensure_structural_mutation_ready()
  // Generation exhaustion: verify every slot can advance before mutating
  // any state, so a raise leaves the World untouched
  for i in 0..<self.gens.length() {
    if !self.generation_can_advance(i) {
      raise ECSError::EntityCapacityExhausted
    }
  }
  // Clear every registered Component Slot
  for i in 0..<self.erased_pools.length() {
    (self.erased_pools[i].clear_all)()
  }
  // Invalidate all entity slots by advancing their generations
  for i in 0..<self.gens.length() {
    ignore(self.advance_generation(i))
  }
  // Reset allocator state
  while self.free.length() > 0 {
    ignore(self.free.remove(self.free.length() - 1))
  }
  self.live_count = 0
}

// --- Structural mutation guard ---

///|
/// Raises `StructuralMutationDuringQuery` while a query is executing.
/// The single source of truth for the structural mutation guard.
fn World::ensure_no_active_query(self : World) -> Unit raise ECSError {
  if self.query_depth > 0 {
    raise ECSError::StructuralMutationDuringQuery
  }
}

///|
/// The unified structural-mutation prologue: validates the optional Entity
/// first (so invalid handles raise Stale/Foreign even during a query),
/// then enforces the no-active-query guard. Run before any structural
/// mutation.
fn World::ensure_structural_mutation_ready(
  self : World,
  entity? : Entity,
) -> Unit raise ECSError {
  match entity {
    Some(e) => self.ensure_alive(e)
    None => ()
  }
  self.ensure_no_active_query()
}

///|
/// Returns true if advancing the generation of slot `index` would not
/// overflow. Read-only — never mutates World state.
fn World::generation_can_advance(self : World, index : Int) -> Bool {
  let gen = self.gens[index]
  gen + 1 >= gen
}

///|
/// Advances the generation of slot `index` and returns the new generation.
/// Raises `EntityCapacityExhausted` before any state change when the
/// increment would overflow.
fn World::advance_generation(self : World, index : Int) -> Int raise ECSError {
  if !self.generation_can_advance(index) {
    raise ECSError::EntityCapacityExhausted
  }
  let next_gen = self.gens[index] + 1
  self.gens[index] = next_gen
  next_gen
}

///|
/// Registers a new Component Slot for payload type `T` and returns a typed
/// ComponentKey that provides access to the slot.
pub fn[T] World::register(self : World) -> ComponentKey[T] raise ECSError {
  self.ensure_structural_mutation_ready()
  let slot = self.next_slot_index
  let next = slot + 1
  if next < slot {
    raise ECSError::ComponentCapacityExhausted
  }
  self.next_slot_index = next
  let id = ComponentID::{ world_id: self.world_id, slot_index: slot }
  let key = ComponentKey::{
    id,
    world: self,
    sparse: [],
    dense_entities: [],
    dense_payloads: [],
  }
  // Register an erased pool so despawn/clear can clean this slot
  let pool = ErasedPool::{
    remove_entity: fn(e : Entity) -> Unit {
      if key.contains_entity(e) {
        ignore(key.remove_entity(e))
      }
    },
    clear_all: fn() -> Unit raise ECSError { key.clear() },
    contains_entity: fn(e : Entity) -> Bool { key.contains_entity(e) },
    dense: fn() -> Array[Entity] { key.dense_entities },
  }
  self.erased_pools.push(pool)
  key
}
