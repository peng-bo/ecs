# Carry World provenance in Entity identities

Every Entity carries enough private provenance for the ECS Core to reject its use with a different World. This costs additional identity storage compared with a bare index and generation, but prevents entities from different Worlds with matching slots from silently aliasing; the concrete encoding remains private so it can be optimized without changing the public contract.
