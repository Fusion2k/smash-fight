---
status: accepted
---

# Keep player slots separate from controller assignments

The [controller and match-flow decision, #4](https://github.com/Fusion2k/smash-fight/issues/4), requires a disconnected player's identity and match state to survive controller loss. Use persistent player slots with explicit controller assignments: an unassigned controller may reclaim a missing slot, while connected players' slots remain protected. Assigning controllers to players afresh by connection order would simplify rejoining, but could change ownership during an interrupted match; preserving ownership earns the extra missing-slot and replacement flow.

This records an accepted design constraint, not an implemented module or a choice of engine device identifiers. Scene composition and the interface that enforces it remain part of [#8](https://github.com/Fusion2k/smash-fight/issues/8).
