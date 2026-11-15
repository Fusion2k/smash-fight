# Physics backend evaluation

Research date: **2026-11-15**. Scope: GodotPhysics2D versus Godot Rapier2D for the upcoming [#11 hit-timing experiment](https://github.com/Fusion2k/smash-fight/issues/11). Box2D was investigated briefly and then deferred at the user's request; no further Box2D work is proposed.

## Recommendation

**Keep GodotPhysics2D as the initial #11 baseline; retain Rapier2D as a credible alternative if the experiment reveals a specific collision or query problem.** This is a recommendation inferred from the evidence below, not an architecture decision. Rapier is compatible in principle with the project's Godot version and character requirements, but there is no measured project benefit yet that justifies adding a native extension before the first experiment.

The relevant workload is two characters initially, four later, scripted movement and combat, one-way platforms, and reliable one-step active windows at 60 Hz. Improved rigid-body stacks, fluids, complex joints, and rollback support do not address that workload. The [combat lifecycle](../architecture/combat-lifecycle.md) still requires #11 evidence before [#8](https://github.com/Fusion2k/smash-fight/issues/8) selects an implementation schedule. This research does not select GDScript/.NET, scene structure, or hit-detection architecture.

## Versions and deployment

The installed executable reports `4.7.2.stable.official.ed1daf0bf`. Rapier's latest release checked was **v0.36.1, published 2026-11-08**. Its getting-started guide requires Godot 4.7 or newer. Its versioned extension manifest declares minimum 4.7 and Windows/Linux x86_64 libraries for editor, debug export, and release export. This establishes an available distribution path for Windows development and native Linux deployment; it does **not** establish successful loading in this exact 4.7.2 installation or operation on Steam Deck/SteamOS. [Release](https://github.com/appsinacup/godot-rapier-physics/releases/tag/v0.36.1), [installation guide](https://godot.rapier.rs/docs/intro/), [v0.36.1 manifest](https://github.com/appsinacup/godot-rapier-physics/blob/v0.36.1/bin2d/addons/godot-rapier2d/godot-rapier2d.gdextension).

GodotPhysics2D ships with the selected engine; Rapier adds an addon, native export libraries, and a second version to pin and validate. The backend is selected through `physics/2d/physics_engine`. Current Rapier documentation describes one single-precision build per dimension, with SIMD and enhanced determinism enabled; older advice to choose separate fast versus deterministic variants should not guide this evaluation. The extension source API supports several Godot API versions, while the shipped current addon targets 4.7. [Rapier README](https://github.com/appsinacup/godot-rapier-physics/tree/v0.36.1), [installation guide](https://godot.rapier.rs/docs/intro/).

## Fit for movement and combat

| Concern | GodotPhysics2D | Rapier2D assessment |
| --- | --- | --- |
| Scripted characters | Godot's `CharacterBody2D` supplies script-driven collision movement. | Character bodies are supported; the integration implements `body_test_motion`, so this is a replacement backend behind Godot APIs, not a requirement to use Rapier's upstream controller. |
| One-way platforms | Godot 4.7 exposes direction and collision margin. | v0.36.1 motion code reads per-shape direction/margin and tests one-way contact rejection. Exact landing/drop-through behavior still needs project tests. |
| Hit candidates | Areas and direct-space queries are available. | Areas, shape intersections, ray queries, and motion casts are listed as implemented. Their availability alone does not prove one-step hit timing. |

Sources: [Godot CharacterBody2D](https://docs.godotengine.org/en/4.7/classes/class_characterbody2d.html), [Godot CollisionShape2D](https://docs.godotengine.org/en/4.7/classes/class_collisionshape2d.html), [Rapier feature list, updated August 2026](https://godot.rapier.rs/docs/progress/), [v0.36.1 server implementation](https://github.com/appsinacup/godot-rapier-physics/blob/v0.36.1/src/servers/rapier_physics_server_impl.rs), [v0.36.1 motion/one-way implementation](https://github.com/appsinacup/godot-rapier-physics/blob/v0.36.1/src/spaces/rapier_space_body_helper.rs).

Variable jump height, air jumps, knockback, hitstun, hit pause, down-only drop-through eligibility, per-attack target history, and simultaneous trades remain game rules under either backend. A better rigid-body solver does not implement these rules. Godot documents character bodies as unaffected by engine gravity/friction unless the script supplies movement. This supports scripted control without establishing the final node design. [Godot character-body guide](https://docs.godotengine.org/en/4.7/tutorials/physics/using_character_body_2d.html).

Rapier documents a collision-filtering limitation: asymmetric body collisions are unsupported, using `(A.layer & B.mask) != 0 || (B.layer & A.mask) != 0`. Therefore, verify both characters' body filters allow mutual pass-through; do not assume a one-sided mask creates that behavior. Hit detection filters also need explicit tests. The README separately documents a 2D point-query difference involving `input_pickable`; shape queries avoid relying on that particular exception. [Rapier limitations](https://github.com/appsinacup/godot-rapier-physics/tree/v0.36.1#limitations).

## Timing is the meaningful uncertainty

Godot's Area overlap lists update during the physics schedule, rather than immediately after movement. Rapier's own documentation also distinguishes cached scene-node state from current physics-server state. Switching backends therefore does not establish immediate Area signals or fresh overlap lists when an attack shape activates for just one simulation step. [Godot Area2D](https://docs.godotengine.org/en/4.7/classes/class_area2d.html), [Rapier state/timing explanation](https://godot.rapier.rs/docs/documentation/determinism/).

Rapier v0.36.1 adds a potentially useful, backend-specific API: `RapierPhysicsServer2D.space_update_queries(space)`. The merged change says direct queries otherwise see the previous step after body/area/shape changes. This call updates modified colliders and broad-phase bounds without stepping. Kinematic targets still wait for the step; it is not an immediate Area-signal/cache refresh. Each call scans the space's colliders, and the first call after a step copies the broad phase. #11 should distinguish ordinary Godot-API behavior from a separate Rapier-specific refresh experiment. [PR #652, merged 2026-10-14](https://github.com/appsinacup/godot-rapier-physics/pull/652).

CCD also does not establish combat correctness. Rapier's upstream CCD documentation describes clamping dynamic rigid-body motion at impacts, with qualifications even for two CCD-enabled bodies. It does not promise swept detection for our Area-based or scripted attack windows. Godot's `cast_motion` ignores shapes already overlapping the cast shape, so a sweep approach must also consider initial overlaps. These are reasons to test fast crossings and stationary overlaps separately. [Rapier CCD](https://rapier.rs/docs/user_guides/rust/rigid_bodies/#continuous-collision-detection), [Godot direct-space queries](https://docs.godotengine.org/en/4.7/classes/class_physicsdirectspacestate2d.html).

## Benefits and limits

Rapier advertises stability, ghost-collision improvements, serialization, and optimized simulation. Its published performance results concern piles, thousands of bodies, joints, and query storms on an M1 with rendering excluded. Those results neither measure this game nor establish Steam Deck frame time. Smoother contact at arena seams or faster relevant queries would be useful **if reproduced here**; large-stack throughput is presently weak evidence for changing this project. [Rapier features](https://godot.rapier.rs/), [benchmark conditions/results](https://godot.rapier.rs/docs/documentation/performance/).

Current releases are maintained, but compatibility is not perfect by definition: v0.36.1 includes fixes for character bodies losing their floor near many bodies, shared Shape2D resources, and Area overrides. These fixes are encouraging maintenance evidence and reasons to pin the tested release. They are not evidence those failures persist in v0.36.1. [Versioned changelog](https://github.com/appsinacup/godot-rapier-physics/blob/v0.36.1/CHANGELOG.md).

Determinism is not a deciding requirement for this local game. Rapier's physics-server determinism does not make input, script logic, scene caches, or callbacks deterministic. Upstream guarantees require matching initial state and creation/removal order, supported floating-point behavior, and compatible build features; changing engine/library/compiler versions warrants revalidation. It does not remove the need to collect all valid hits before applying interruptions so that trades survive reversed character iteration. [Integration determinism](https://godot.rapier.rs/docs/documentation/determinism/), [upstream guarantees](https://rapier.rs/docs/user_guides/rust/determinism/).

## Practical evidence for #11

Run the first small experiment on GodotPhysics2D. If it exposes a relevant defect or Rapier comparison is requested, repeat the same scene, inputs, geometry, masks, and 60 Hz schedule with pinned Rapier v0.36.1:

1. Record simulation-step numbers for activation, movement, candidate detection, and deactivation; cover a one-step active window and a new attack while already overlapping.
2. Test fast crossing, initial overlap, multiple targets, and persistent overlap; confirm each attack hits each target once.
3. Reverse character iteration order and require identical simultaneous trades before damage/knockback/hitstun resolves.
4. Test upward passage, resting landings, fast downward landing, platform edges, and down-only drop-through with collision restoration; confirm characters pass through each other.
5. Compare Area signals/cache reads with direct queries. If query freshness differs, log transform changes and test Rapier's refresh API as a separately labelled case.
6. Verify the active backend actually loaded in editor and exported Windows/Linux builds. Measure physics and total frame time for two-player first-playable acceptance, then verify native Steam Deck play at 1080p60 and record human reaction. Four-character measurements are a growth smoke check for later support, not a requirement to ship four-player content now.

**Verified:** documentation, release metadata, native-library declarations, and relevant integration source. **Untested:** addon loading, actual collision/timing behavior, performance, exported builds, and Steam Deck operation. No addon was installed, project setting changed, or gameplay experiment run by this research.
