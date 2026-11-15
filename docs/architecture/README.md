# Architecture

These documents explain the evolving design of Smash Fight. GitHub Issues remain the source of truth for requirements and their resolutions; these diagrams provide views of those decisions and link back to them.

The main working tree currently contains the starter Godot project, without gameplay scenes or a configured main scene. A runnable timing lab is preserved separately on `prototype/combat-timing`. An agreed requirement is not evidence of implemented behavior. Each document distinguishes agreed rules, proposed structure, and work awaiting verification.

## Views

| Document | Purpose | Current status |
| --- | --- | --- |
| [Scene map](scene-map.md) | Godot scene composition, scene responsibilities, and implementation status | Proposed production tree plus implemented timing-lab tree |
| [Match flow](match-flow.md) | Joining, selection, match results, pause, and controller replacement | Agreed behavior from #2 and #4; not implemented |
| [Combat lifecycle](combat-lifecycle.md) | Attack phases, hit response, and timing constraints | Agreed rules from #2; #11 evidence accepted for architecture review |
| [Combat timing evidence](combat-timing-evidence.md) | Reproducible fixture results, limitations, and candidate approach | Eleven scenarios measured; user reported "prototype looks good" |
| [State and content](state-and-content.md) | Player identity, character definitions, independent match state, and content requirements | JSON physics/damage and editor-authored graphics/move data agreed |
| [Character authoring](character-authoring.md) | Concrete JSON fields, units, editor reference, validation, and editing walkthroughs | Accepted specification from #7; loader/editor implementation pending |
| [Player-slot decision](../adr/0001-player-slots-and-controller-assignment.md) | Persistent player identity and replaceable controllers | Accepted in #4 |
| [Character-authoring decision](../adr/0002-physics-json-and-editor-authored-geometry.md) | Physics/damage JSON separated from editor-authored graphics/move data | Accepted in #7, with schema and validation contract |

## Decision sources

| Issue | What it establishes |
| --- | --- |
| [#1: Planning map](https://github.com/Fusion2k/smash-fight/issues/1) | Scope, platform targets, decision order, and completed evidence |
| [#2: Movement and combat](https://github.com/Fusion2k/smash-fight/issues/2) | Agreed actions, attack/hit/stock rules, and provisional timing |
| [#3: Characters and arena](https://github.com/Fusion2k/smash-fight/issues/3) | Agreed Zip/Bramble move kits, recovery differences, arena topology, and placeholder presentation |
| [#4: Controllers and match flow](https://github.com/Fusion2k/smash-fight/issues/4) | Agreed player slots, controls, lifecycle, and developer test path |
| [#7: Character files](https://github.com/Fusion2k/smash-fight/issues/7) | Resolved: JSON physics/attack damage, editor-authored geometry/timing/launch parameters, Godot reference, schema, validation, and edit boundaries |
| [#8: Architecture](https://github.com/Fusion2k/smash-fight/issues/8) | Pending scene/module responsibilities, interfaces, language, and state ownership |
| [#9: Development workflow](https://github.com/Fusion2k/smash-fight/issues/9) | Pending portable launcher, renderer/scaling, and delivery workflow |
| [#10: Acceptance](https://github.com/Fusion2k/smash-fight/issues/10) | Pending automated/manual checks and Steam Deck/TV validation policy |
| [#11: Timing prototype](https://github.com/Fusion2k/smash-fight/issues/11) | Resolved: native timing lab measured and human feedback recorded; production design remains #8 |
| [#12: Physics backend research](https://github.com/Fusion2k/smash-fight/issues/12) | Completed source evaluation: GodotPhysics2D baseline recommended, Rapier v0.36.1 a credible alternative; Rapier runtime untested and Box2D deferred |

The cited [physics-backend evaluation](https://github.com/Fusion2k/smash-fight/blob/1fb7589/docs/research/physics-backend-evaluation.md) is preserved on the research-only `research/physics-backends` branch, following the repository's research convention. It recommends a first-experiment baseline; it does not settle the production backend or replace #11's measurements.

## Keeping the views current

When a decision changes scene composition, update the scene map and its status table in the same change. When scenes are implemented, replace proposed labels with actual repository paths and document their small interfaces. Update flow and ownership views when their behavior changes, and link the deciding issue or ADR.

Use ADRs for consequential architectural trade-offs, rather than every tuning or content choice. Keep domain definitions in the root [glossary](../../GLOSSARY.md). Do not present proposed scene names, untested timing behavior, or target-platform performance as established results.
