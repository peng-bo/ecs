# Erase pool types only for lifecycle and membership

The ECS Core keeps Component values statically typed behind `ComponentKey[T]` and `SparseSet[T]`, while the World and Query Plans use an object-safe `&ErasedPool` for type-independent lifecycle operations and Entity membership checks such as removal, clearing, length, containment, and dense Entity access. No erased method returns a Component value or converts an `&ErasedPool` back into `SparseSet[T]`; registration produces the typed key and erased membership view together, avoiding `Any`, `TypeId`, string type names, and unsafe downcasts.
