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

// --- Public accessors ---

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

// --- Private helpers ---

///|
fn[T] ComponentKey::validate_entity(
  self : ComponentKey[T],
  entity : Entity,
) -> Unit raise ECSError {
  self.world.ensure_alive(entity)
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

// --- Private: erased entity operations (used by ErasedPool closures) ---

///|
fn[T] ComponentKey::remove_entity(
  self : ComponentKey[T],
  entity : Entity,
) -> T? {
  let dense_idx = self.sparse_lookup(entity)
  if dense_idx < 0 {
    None
  } else {
    let last_idx = self.dense_entities.length() - 1
    let removed = self.dense_payloads[dense_idx]
    if dense_idx != last_idx {
      let last_entity = self.dense_entities[last_idx]
      self.dense_entities[dense_idx] = last_entity
      self.dense_payloads[dense_idx] = self.dense_payloads[last_idx]
      self.sparse[last_entity.index] = dense_idx
    }
    ignore(self.dense_entities.remove(last_idx))
    ignore(self.dense_payloads.remove(last_idx))
    self.sparse[entity.index] = -1
    Some(removed)
  }
}

///|
fn[T] ComponentKey::contains_entity(
  self : ComponentKey[T],
  entity : Entity,
) -> Bool {
  self.sparse_lookup(entity) >= 0
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
    // Replacement: allowed even during query (non-structural)
    let old = self.dense_payloads[dense_idx]
    self.dense_payloads[dense_idx] = value
    Some(old)
  } else {
    // First insertion is structural — reject during query
    self.world.ensure_no_active_query()
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
  self.world.ensure_no_active_query()
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
pub fn[T] ComponentKey::clear(self : ComponentKey[T]) -> Unit raise ECSError {
  self.world.ensure_no_active_query()
  for i in 0..<self.dense_entities.length() {
    self.sparse[self.dense_entities[i].index] = -1
  }
  while self.dense_entities.length() > 0 {
    ignore(self.dense_entities.remove(self.dense_entities.length() - 1))
    ignore(self.dense_payloads.remove(self.dense_payloads.length() - 1))
  }
}
