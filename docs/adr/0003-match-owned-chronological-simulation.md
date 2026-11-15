---
status: proposed
---

# Coordinate chronological simulation in Match

For [#8](https://github.com/Fusion2k/smash-fight/issues/8), keep one Match-owned gameplay physics callback and explicit ordered calls into Character, hit detection and hit resolution. Characters own mutable movement/combat state and predict/commit only the next interval; Match coordinates the earliest event time and re-queries after changes. This preserves accepted distinct-time ordering, true-tie trades and local hit pause without depending on node/signal iteration order. Autonomous Character callbacks and a whole-step hit batch would be simpler, but cannot reliably express those rules. Presentation follows simulation state rather than controlling attack timing through animation events.

The ownership and simulation-timing direction is accepted; the concrete interval contract and remaining gameplay tie policies await final shared-understanding confirmation in #8. [Native/analytic evidence and its limits](../architecture/contact-chronology-evidence.md) support the direction, not an implemented production scheduler. The [module design](../architecture/module-interfaces.md) assigns native integration verification to #10.
