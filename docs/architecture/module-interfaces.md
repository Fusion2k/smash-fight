# Module interfaces

**Status: accepted architecture in [#8](https://github.com/Fusion2k/smash-fight/issues/8), confirmed by the user on 2026-11-15; Resources/catalog implemented in #15; Character movement/native intervals and Arena implemented in #16.** The accepted design covers GDScript, GodotPhysics2D, scene/module ownership, Resource authoring with an Inspector JSON picker, simulation-owned timing, local hit pause, fixed rectangular combat shapes, native interval prediction/commit and chronological contact groups. [Movement evidence](../evidence/16-native-movement.md) verifies the movement portion of this contract through production Character methods. Match/combat chronology is implemented and checked in #17 ([evidence](../evidence/17-chronological-combat.md)); stock/flow software is implemented in #18; performance and physical hardware acceptance remain #10/#18 onward.

## Ownership and interfaces

| Module / proposed path | Owns and hides | Interface and invariants |
| --- | --- | --- |
| Application flow / `app/app.gd` | Active view, player slots, selections/readiness, controller assignment and replacement | Join/select/ready/pause/resume commands; supplies a match setup containing slot IDs and chosen character definitions. Controller IDs never become character identity. |
| Input / `input/player_input.gd` | Device-specific reads, analog thresholds, fresh-down detection | Produces one input frame per slot: horizontal amount, attack direction, held jump and fresh action presses. Gamepad, keyboard and stationary opponent produce this same shape. No combat rules here. |
| Character catalog / `characters/character_catalog.gd` | JSON reading, schema and editor-content validation, useful aggregated diagnostics | `prepare_match(definitions)` returns `{ok, characters, errors}` with fresh PreparedCharacter snapshots or aggregated file/field diagnostics; [concrete methods](character-authoring.md#implemented-authoring-interface-15). Invalid selections cannot start. Retry rereads JSON; a running match retains its prepared settings. |
| Match / `match/match.gd` | Character composition, stocks, respawn scheduling, explicit simulation order, pause gate and final result | `start(setup)`, `step(input_frames)`, `set_paused(value)`, `clear_inputs()`; publishes a read-only view and events for presentation. Owns the only gameplay physics callback. |
| Character / `characters/character.gd` | Independent velocity, damage, action phase, hitstun, hit pause, airborne resources, input buffer and per-attack target history | `prepare_step(input)`, `predict_interval(until)`, `commit_interval(plan, until)`, `apply_event_group(results)`, `finish_step()`, `respawn(position)`. Prediction returns motion/geometry and the next native surface event without changing state; commit advances only the agreed prefix. Plans carry a state revision and become invalid after state changes. Match coordinates interval advancement; preparation/finalization occur once per whole step. No autonomous physics callback. Integrated prediction/commit equivalence must be verified through this interface. |
| Hit detection / `combat/hit_detection.gd` | Relative-translation shape checks, contact times, eligibility and once-per-target filtering | Proposed `next_contacts(motion_segments)` returns the earliest contact-time group without mutating characters. Explicit native shapes replace assumptions about Area polling freshness. #11 verifies collision booleans, not this contact-time extension. |
| Hit resolution / `combat/hit_resolution.gd` | Chronological damage, knockback, hitstun and trade calculations | Proposed `resolve(contact_group, before_contact_state)` returns per-character results/events for one contact time. Simultaneous incoming hits add damage and sum launch vectors; distinct times resolve in order. All results within a true tie are calculated before interruption. Formula coefficients remain provisional shared rules. |
| Arena / `arenas/first_arena.tscn` | Solid surfaces, one-way platforms, start/respawn markers, ring-out limits and fixed camera | Exposes markers and `is_out(position)` to Match. Character movement uses surface collisions; characters do not physically block each other. |
| Presentation / match HUD and character visuals | Damage/stock labels, player markers, poses, hit flash, launch feedback and menus | Consumes match views/events and character phase progress. Cannot apply hits, consume stocks, advance attack phases or change controller ownership. |

Input buffers belong to each character because action eligibility, hit interruption, and resource restrictions are character rules. App/input own physical press edges. Resuming clears character buffers and stale press edges; held buttons must not become synthetic new presses.

The character module may use internal movement/action helpers as needed. These are not separate public modules by default. Match's phase interface earns its ordering constraints by coordinating movement and preserving simultaneous outcomes. It must not accumulate movement, attack or content-validation implementation. The interval interface below specifies advancement; a single whole-step move followed by whole-step batch resolution cannot implement the newly clarified within-step ordering faithfully.

Application creates the catalog and input modules and supplies prepared settings and input frames to Match. Match directly calls its character and combat modules in the prescribed order. View updates and presentation events may use signals, but gameplay ordering must not depend on signal-listener order. These modules do not require autoload singletons or a global event bus. The application and flow overlays continue processing while the match step is gated off.

## Accepted editor authoring

`CharacterDefinition` is a custom Resource with identity, display name, character scene, seven `MoveDefinition` resources and an Inspector-visible `@export_file("*.json")` physics/damage path. The character scene contains its `CharacterBody2D`, surface collision, editor-authored hurtboxes and visuals. Moves contain editor-authored hitbox shapes/offsets, startup/active/recovery lengths, launch direction/strength and presentation references. JSON contains only the fields accepted in [#7](character-authoring.md).

At match start the catalog validates the JSON and editor data together, then creates a private prepared definition. Resource caching and shallow scene duplication are not the isolation mechanism: prepared data is treated as read-only, mutable shape data is copied, and each character receives fresh runtime state and hit history. The match never changes authored Resources. Loading a second Zip does not reset or change the first Zip.

Integer simulation steps own attack phase and active-window timing. Visual animation follows the current move and phase progress. Animation tracks cannot enable hitboxes or apply damage; display frame rate cannot change a one-step active window. Hit pause holds the corresponding visual pose. The prototype does not establish the production animation implementation.

## Accepted step order

Use chronological contact groups. One simulation step is not automatically one simultaneous-hit group. Attack phase durations remain integer steps; collision contacts may occur at different fractions within a step. The following is a accepted production design informed by #11/#13; its integrated checks belong in #10.

```mermaid
flowchart TB
    Input["Read input and handle pause / controller loss"] --> Gate{"Gameplay enabled?"}
    Gate -->|No| UI["Update only flow / overlay"]
    Gate -->|Yes| Prepare["Prepare all characters: buffers, action eligibility, phase for this step"]
    Prepare --> Motion["Describe eligible motion / geometry for remaining interval"]
    Motion --> Contact{"Next surface / combat / ring-out event?"}
    Contact -->|Yes| Advance["Commit all characters to earliest time; gather ties"]
    Advance --> Resolve["Resolve surface eligibility and combat under accepted tie rule"]
    Resolve --> Apply["Apply group; update history; invalidate changed future contacts"]
    Apply --> Motion
    Contact -->|No| Finish["Advance remaining interval"]
    Finish --> Stocks["Collect ring-outs; update stocks / respawns; decide result"]
    Stocks --> End["Complete step counters; publish view and feedback events"]
```

The measured #11 baseline starts a newly active attack at its current endpoint, avoiding a sweep through startup. The contact-time extension must instead represent the actual eligible interval: never include startup or inactive time, but retain movement that occurs after activation, including the first active step. This is additional coverage, not a reinterpretation of the old measurements. Target history is keyed by a match-local attack instance ID and target slot ID, survives overlap, and resets for a new attack instance. A respawn replaces the old pose history so it cannot create a sweep across the arena.

During preparation, action commitment and hitstun gate drop-through eligibility. An eligible fresh down press on a supporting one-way platform removes that support before selecting an attack, so down-plus-attack starts an aerial down attack as required by #4. Holding down does not drop through the next platform. Landing ends an aerial attack and applies landing delay from its contact time; retain valid combat contacts before landing and reject attack contacts after it. Landing does not end hitstun early. Arena contacts must produce piecewise motion intervals rather than assuming one straight chord between whole-step endpoints. These integrated transitions require the #10 checks.

Relative translation uses attack movement minus target movement with explicit shape snapshots; it does not depend on the physics world's query-update timing. Collection before interruption preserves trades within a true contact-time tie. Distinct later contacts must be rechecked after an earlier hit changes motion, action eligibility or hit pause. A later precomputed overlap is not proof the second hit still connects. Beginning an attack removes respawn protection before that interval's hits. Newly imposed hit pause/hitstun is not decremented in the hit step. Only accepted hits update per-attack target history and emit hit feedback.

Ring-outs are collected throughout the step and applied together before a winner/draw is emitted, preserving #2's same-step final-stock draw rule even when contact times differ. Crossing a ring-out limit removes that character from later collision intervals. A character with zero stocks stays out; a surviving slot respawns after the agreed delay at 0% with fresh airborne resources and protection. Stocks and respawn scheduling belong to Match; damage and action state belong to Character.

### Accepted clock rules and proposed counter convention

- Pause or controller loss stops the entire match step, including every gameplay timer. Flow owns countdown time and continues accepting replacement/pause UI input.
- Hit pause freezes the involved characters' movement, action phase, hitstun and character-local gameplay timers; other characters continue. Paused attack shapes cannot generate new hits during those frozen steps. Newly arriving valid hits from other characters may still strike a frozen vulnerable character.
- Action presses may buffer during hit pause, with buffer expiry frozen; only the latest press remains under #2's priority rules. Being hit clears the buffer. Resume clears all buffers and stale press edges.
- Proposed counter convention: define timers as remaining whole steps; decrement existing counters once at step completion. Set counters for newly entered states without consuming their first step immediately. Match owns respawn-delay counters; Character owns protection counters, including their hit-pause freeze. Both stop during full match pause.

### Accepted geometry scope and verification limits

The verified #11 baseline covers constant-size, axis-aligned rectangles translating linearly. The user accepted first-playable combat geometry with rectangular hit/hurt shapes at fixed size and offsets during each active window. Shapes may differ between moves and be mirrored when facing locks at attack start; animation may rotate artwork independently. Movement-surface collision remains GodotPhysics2D's responsibility.

Rotating, scaling or morphing active shapes require a separate measured detector extension before adoption. Landing, ring-out, respawn or teleport invalidates inappropriate sweep history. Full integration must still check fast surface contacts and trajectories changed by arena collision; the lab's straight-motion fixtures do not establish those cases.

### Chronological hits and true ties

Distinct contact times resolve in chronological order. A true simultaneous contact combines damage and sums knockback vectors, without a player-slot priority. Do not drop a later valid hit or merge every hit found in one simulation step.

For distinct hits, hit 1 applies its damage and changes the target's launch velocity; if hit 2 subsequently connects, it applies its own damage and changes the launch direction again using the updated target damage. Opposing hits can therefore reverse the target's travel. The second hit is not discarded merely because both contacts occurred within one 60 Hz step. Hit pause and interruption can change whether and when that later contact actually occurs, so subsequent collision intervals must use the updated state.

For a true tie against one target, add the accepted attacks' damage together and vector-sum their knockback. Equal right/up and left/up launches cancel horizontally and reinforce upward; unequal horizontal strengths retain a horizontal remainder. There is no strongest-hit selection or slot-order tie-break. Mutual attacks against different targets can still trade, and one attack can still hit several opponents once each.

Proposed numeric convention for a tied group: compute each launch contribution using the same damage after adding that group's damage, then sum the vectors. Compute the resulting hitstun once from the combined launch under the shared tunable rule. Contact-time equality needs a documented numerical tolerance rather than grouping the entire step. The lab exercised provisional post-group scaling and a 1e-7 normalized-step tolerance. These numeric conventions remain provisional; within-step native advancement follows the accepted contract below and still requires integrated verification.

The first playable has two slots, so a target has at most one opponent. Keep contact grouping and resolution behind combat interfaces that can support four slots. Four-player content and physical acceptance remain later work. The #11 constant-rectangle boolean sweeps do not establish chronological contact detection, near-tie discrimination, combined-force launches or re-simulation after an earlier hit.

The resolved [#13 experiment](contact-chronology-evidence.md) records these contact-time cases in fifteen analytic fixtures executed in Godot, plus separate native wall/floor probes. Its human reaction supports the gameplay interpretation. #16 implements native surface intervals; the integrated combat contract is now exercised by #17 production Match checks.

## Ordinary changes

| Change | Location and verification seam |
| --- | --- |
| Tune Zip's mass or damage | Zip JSON; prepare a new match; active match's prepared settings stay stable. |
| Add Bramble | Its JSON, CharacterDefinition, MoveDefinitions and scene; shared Character and Match code stays unchanged for the agreed kit. |
| Select Zip twice | Two Character instances with independent state; observe damage, jumps, attacks and respawn separately. |
| Change reach or attack timing | Editor-authored MoveDefinition; phase and geometry validation catches unsupported data. |
| Replace the arena | Arena scene and exposed markers/limits; Match and character movement rules remain unchanged. |
| Replace a controller | Application's missing-slot assignment; same slot and character state persist. |
| Grow to four | Configure slot/character collections and UI layout; no fixed P1/P2 combat fields or pair-only detector. Chronological hits, true ties, combined-force balance, content and physical-controller acceptance still need validation. |

Verification through these interfaces and human game-feel checks will be specified in #10. No gameplay, performance, controller or Steam Deck acceptance is claimed by this architecture.

## Native interval contract

Match owns a normalized cursor in [0,1] for one fixed step. Character preparation samples input and applies movement acceleration/gravity once, producing a velocity that is constant until a collision or state transition changes it. Re-predicting after an event must not apply acceleration again. Attack phase and other whole-step counters advance only in finalization, subject to their freeze rules; phase age finalized in the previous step determines the next step's eligible interval.

`predict_interval(until)` returns a value record: slot ID, state revision, start time/transform, velocity, fixed hit/hurt rectangles, attack instance ID, eligibility, and the next surface contact. Match calculates ring-out time from that safe motion prefix and Arena limits. Surface prediction uses native GodotPhysics2D motion testing against the static arena from the committed pose. It stops at the first surface event rather than predicting a chord through a wall or landing. One-way eligibility/drop-through filtering belongs inside Character movement. Frozen characters supply stationary vulnerable hurtboxes and no attacking hitboxes. No character-body collision is queried against another character.

Match asks every live Character for a plan, takes the earliest surface/ring-out horizon, and asks hit detection for combat contacts only within that common interval. It commits every Character to the earliest resulting event time, resolves that group, then discards all plans and queries again from committed state. A surface at an earlier time is therefore applied before looking for contacts beyond it; a hit that changes motion cannot reuse an unperturbed surface fraction. A commit may not advance beyond a predicted event. Any prediction/commit mismatch is a simulation diagnostic, never permission to silently advance along the wrong path.

At a surface event Character removes velocity into the contacted surface, retains permitted tangent motion, and handles landing/resources/action eligibility. Simultaneous surface normals must be handled together, without arbitrary surface enumeration priority. At ring-out Match removes the Character from remaining intervals, records the loss, and retains all other slots' remaining motion before final-stock results are decided. Respawn creates a fresh pose/history. Static surfaces are the agreed arena scope; moving surfaces would require a revised contract.

Hit resolution receives immutable pre-group state and returns one aggregate result per affected slot. Character applies all results only after the whole group has been calculated, preserving trades. Incoming hits replace that target's previous pending launch with the newly resolved launch; simultaneous contributions are summed within the group. During local hit pause the pending launch is stored separately from zero positional motion. A later valid hit updates it from the target's new damage, clears the buffer and restarts the pause. On release it becomes movement velocity without an extra hit or attack restart. This makes the accepted local-pause and later-valid-hit rules concrete; balance values remain provisional.

Zero-time contacts cannot cause an infinite loop: accepted attacks enter target history, ring-outs remove participants, and resolved surfaces must permit separating/tangent movement without repeatedly reporting the same blocking event. Each event must advance time or change a finite eligibility/contact state. Use a diagnostic iteration budget as a final guard; exceeding it stops the match with a reproducible trace rather than publishing a partial result as a completed step. The budget is an engineering setting to establish through integrated tests and profiling, not the prototype's arbitrary 40 iterations.

The contract deliberately avoids requiring Match to know native motion-query details or collision margins. Character owns prediction/commit agreement and movement; detection owns swept rectangular contact fractions; resolution owns damage/launch formulas. Their implementation may refine private helpers without changing callers. The exercised native/query integration is recorded in #16/#17 evidence; broader hardware and performance claims remain unverified.

## Confirmed event ties and shared understanding

The user confirmed the complete architecture and this exact-tie policy with "yes" on 2026-11-15:

- At an exact landing/surface and combat tie, collect combat eligibility immediately before the surface transition and resolve the simultaneous combat group before ending the landed aerial attack. A hit exactly at landing connects; later attack contacts do not. Then apply surface constraints to the resulting launch, including a pending launch held during local hit pause, so a floor or wall stops launch into it. Landing does not clear hitstun.
- At an exact ring-out/combat tie, ring-out removes that character first; it cannot contribute or receive combat in that group. Retain all other characters' remaining motion and the same-step final-stock draw rule.
- Scene composition, ownership, interval interfaces, explicit ordered calls and simulation-driven visuals are the implementation handoff. Zip/Bramble use the shared lifecycle through data; a future genuinely new mechanic is an explicit Character action extension with its own content and verification contract. #9 decides rendering/setup/export; #10 decides acceptance.

Existing rules imply that later valid hits add damage and update the pending launch during local pause. Stronger resulting launches produce longer capped hitstun; use net summed launch for a true tie, so cancellation reduces launch/hitstun while damage and hit pause remain. Shared post-group damage, target mass scaling, whole-step counter convention and the lab's 1e-7 normalized-step tie tolerance are provisional engineering conventions. Numeric balance remains tunable, with near-tie/coordinate-scale and pause-release checks in implementation. These do not require another gameplay decision round unless review reveals a mismatch.

## Integration checks to carry into #10

### Implemented movement seam (#16)

Both character content scenes attach `characters/character.gd`. Instantiate through a PreparedCharacter, add it to the world, then call `configure(prepared, slot_id)`. `prepare_step(input)` accepts horizontal input plus fresh/held jump, attack, special and down fields. It updates acceleration/gravity once at 60 Hz; repeated predictions and prefix commits never apply them again. Attack presses select the #17 shared action lifecycle after support/drop/facing updates. Recovery includes the same authored attack phases and hitbox lifecycle.

`predict_interval(until = 1.0)` returns `{ok, slot_id, revision, start, until, horizon, from, velocity, motion, surface, geometry, facing, frozen}`. Times are normalized to the current whole step. Each returned interval is linear only up to its first surface horizon. Call `commit_interval(plan, chosen_time)` for the selected prefix, apply its returned surface group through `apply_event_group({surface: contacts})`, then predict again. Commit repeats the native query and rejects stale revisions, changed origins, overlong prefixes or native disagreement. `finish_step()` rejects incomplete intervals; it advances buffer/grace counters once. All methods return structured errors with slot, revision, cursor, position, velocity and details. A failed step must stop its caller; respawn resets the state for a new lifecycle.

Surface queries use `PhysicsServer2D.body_test_motion` from the committed pose with a 0.01-unit margin. The raw cast fraction is quantized by the engine's short internal search; 26 bounded native collision-predicate bisections refine each horizon. This preserves prefix agreement to the selected 0.002-unit positional check in the exercised fixtures. It is not an analytic surface world or a guarantee beyond native float32 precision. Normal groups use the provisional `1e-7` normalized-step tolerance. Native corner fixtures calibrate two independently measured axis horizons and distinguish a 0.02-unit offset; nominally equal decimal world distances need not yield exact native ties.

Each query permits 32 body-enumeration attempts (at most 27 native casts each). Returned bodies are excluded successively, then contacts are filtered against the earliest horizon and normals sorted. `Arena.validate_surfaces()` must succeed before a future Match starts: the implemented static scope is one enabled, axis-aligned, unscaled RectangleShape2D per stationary StaticBody2D. Multiple shapes on one body, rotating/scaled shapes, other shapes, moving bodies and conveyors fail explicitly. This restriction allows complete grouped normals despite the native 2D query returning one contact per body. Native-query errors also propagate through support detection. Budget exhaustion leaves the step incomplete and returns a bounded trace; it cannot count as a completed partial move.

`apply_event_group()` accepts aggregate hit results, target-history additions and surface constraints. Character owns phase/history, pause/pending launch, hitstun, landing delay and protection clocks; Match owns contact orchestration and ring-out removal. Surface constraints affect current and pending launch, replenish resources on landing and preserve hitstun. #17 exercises these through the production Match; stock/respawn scheduling remains #18.

Verify through `Match.step` with real Character/Arena scenes: first-active fast crossing; distinct hits and true/near ties in reversed slot enumeration; changed native trajectory after hit and after wall/landing; multiple surface contacts; exact landing/combat and ring-out/combat ties under the selected policy; local pause onset/release/re-hit/pending launch and frozen buffers while a third participant continues; one-way drop-through and down-plus-attack; attack interruption; same-step final-stock draw; respawn history reset; prediction/commit agreement and iteration-budget diagnostics. Inspect single-step traces of time, state revision, eligibility, damage, launch and events. These checks supplement the ordinary-change/isolation checks above. They have not passed in production.


### Implemented Match/combat seam (#17)

Instantiate `match/match.tscn`, add it to the world and call `start({characters: prepared_array})`. Optional `slots`, `positions` and `arena_scene` supply explicit slot IDs, spawn positions and an Arena PackedScene; defaults use sequential slots and authored start markers. Repeated prepared selections are allowed; IDs must be unique and positions sufficient. `automatic: true` enables the sole gameplay physics callback; explicit `step({slot_id: input_frame})` is the deterministic test/developer seam. Input frames add `attack_direction` (`neutral`, `up`, `down`) to the movement fields. External code must not call `step` while automatic stepping is enabled. Failed starts disable automatic simulation and clear old feedback.

`step()` returns `ok` and per-step `events`; failure returns `completed: false`, diagnostics and a trace, and prevents further stepping until restart. `view()` returns independent state containers, events, ringed-out slots, step number and the last interval trace. Traces include normalized times, revisions, action eligibility/history, damage, motion and surface groups. `set_paused()` gates the entire step; `clear_inputs()` clears queued input frames and Character buffers for #18 resume flow. Ring-out removes participants from remaining intervals. Match then collects all stock losses after the completed step, schedules 60-step respawns and calculates one winner/draw result; a result gates further simulation. Its view includes stocks, respawns and result.

`HitDetection.next_contacts(plans, until)` returns the earliest swept rectangular contact-time group within the shared native safe prefix. `HitResolution.resolve(contacts, before)` calculates all results before Character mutation. Attack identity is the pair `(attacker slot, Character-local attack_id)`; target history stays private to that Character. A fresh instance has fresh state and history. No Area update/polling freshness is assumed.

Provisional engineering choices: normalized tie epsilon `1e-7`; Match event budget 128 (the `event_budget` diagnostic setting permits bounded exhaustion fixtures); three whole steps of local hit pause; six-step landing delay; each incoming launch vector is `normalized_direction * move_strength * (1 + post_group_damage/100) / target_mass`, then simultaneous vectors sum; hitstun is `ceil(net_launch_length/30)` clamped to 1..60 steps. Newly imposed pause/stun/delay is not consumed in its entry step. Frozen existing pause counts down once per completed step while other local clocks stay frozen. Phase age starts at zero: startup N consumes N non-active intervals before the first active interval. A hit freezes the remainder of its entry interval plus the next three whole intervals. These are tunable rules, not passed balance/feel claims.

### Application/input and stock seam (#18)

`app/app.tscn` is the normal main scene. `SmashApplication` owns collection-based slots (`id`, assigned `device`, connection status, selection, readiness) and flow. Its `join`, `controller_lost`, `choose`, `ready_slot`, `pause`, `resume`, `return_to_selection` and `start_developer_test` commands are exercised by raw `advance(samples)` fixtures and normal device polling. `automatic = false` selects bounded explicit fixture ticks; normal Match physics calls the app's input provider freshly once per step, including menus/paused phases. App never calls Character simulation intervals or implements stock arithmetic.

`PlayerInput.read_device` reads Godot physical keyboard keys and mapped joypad face positions/left stick; `sample(device, raw)` owns fresh edges and down hysteresis. `synchronize(samples)` suppresses held edges at start/resume/replacement while `Match.clear_inputs()` clears Character buffers. Frames queued directly on Match are single-use; automatic callers should supply `input_provider` for fresh per-step frames. GUI buttons have no focus so Godot's built-in accept action cannot double-handle the custom controls.

Match accepts optional `stocks` (default 3), `respawn_positions` and the earlier setup fields. Explicit `positions` also supplies default respawn positions for native fixtures; otherwise authored Arena respawn markers are used. Match counts respawn delay in completed unpaused steps; Character owns 120 local-step protection through `grant_protection`, so full and local hit pause freeze protection. The first respawn interval counts as a protected interval. Starting an eligible attack clears protection before queries. Restart re-instantiates bodies/Arena and app revalidates fresh JSON plus reloads saved editor Resource dependencies using `CACHE_MODE_REPLACE_DEEP`; saved move timing/scene geometry refresh and active snapshot isolation have actual app fixtures. Failure retains the bounded Match trace in `user://last-match-failure.json` and exposes a simple return-to-selection flow.
