///|
/// An opaque handle to a live Entity in a specific World.
/// Entity supports equality, hashing, and debug output without exposing
/// constructors or identity fields.
pub struct Entity {
  id : Int
} derive(Debug, Eq, Hash)

///|
/// An isolated ECS lifecycle boundary that creates and tracks Entities.
pub struct World {
  mut next_id : Int
  mut live_count : Int
}

///|
/// Creates an empty World with no live Entities.
pub fn World::new() -> World {
  { next_id: 0, live_count: 0 }
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
pub fn World::spawn(self : World) -> Entity {
  let entity = Entity::{ id: self.next_id }
  self.next_id = self.next_id + 1
  self.live_count = self.live_count + 1
  entity
}

///|
/// Returns true if the Entity was spawned by this World.
/// Cross-World validation and despawn tracking will be added when
/// the Entity representation gains World provenance and generation counters.
pub fn World::is_alive(self : World, entity : Entity) -> Bool {
  entity.id < self.next_id
}
