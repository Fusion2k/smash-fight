# Chronological combat implementation (#17)

Verified on 2026-11-15 on Windows with Standard Godot `4.7.2.stable.official.ed1daf0bf`, built-in GodotPhysics2D, headless display and Compatibility project configuration. Source is the commit containing this evidence (implementation base `6ab2c5f3ef686f213e4fd4ff94581928e88d4b5d`); the issue resolution records the pushed commit. No production scene/application entry was replaced.

## Delivered interfaces

`match/match.tscn` and `match/match.gd` compose actual prepared Character instances and Arena, own the only gameplay physics callback, pause gate, global normalized cursor and chronological group loop. `combat/hit_detection.gd` sweeps the actual authored hit/hurt rectangles only through native safe motion prefixes. `combat/hit_resolution.gd` calculates an entire true-tie group before any Character mutation. `characters/character.gd` owns shared action phases, per-attack target history, movement/resources, hitstun, local pause/pending launch, landing delay and local clocks. All seven Zip/Bramble moves use authored Resources and JSON damage.

The scheduler re-predicts every remaining participant after each surface/hit/removal group. It never substitutes a whole-step endpoint chord for native movement. Exact ring-out ties remove participants before combat. Exact surface ties resolve eligible hits before ending landed aerial attacks and constraining current/pending launch. Ring-out events are recorded, with removed participants excluded from later intervals; stocks, respawn timing, winner/draw and application flow are deliberately #18.

The [implemented interface and numeric conventions](../architecture/module-interfaces.md#implemented-matchcombat-seam-17) document configuration, callback ownership, inputs, diagnostics, formula, counters, tie epsilon and budget. Ordinary balance constants remain provisional.

## Verification

Run `./tools/dev.ps1 check -GodotBin <matching-local-engine> -TimeoutSeconds 30`. The final bounded run completed import, 7 foundation checks, 96 native movement checks, **108 integrated combat checks** and 60 catalog checks: **271 total**, all passed, no engine/script errors. The catalog's existing deliberate exponent-overflow fixture emits an expected warning, not a failed check. Original movement fixtures now enter actual attacks, hitstun and hit pause instead of setting placeholder commitment/frozen flags.

Final logs: ignored `build/logs/20261115-223525-344-27252/` retains run manifest, full stdout/stderr and engine/import output. [Tracked assertion transcript](17-combat-checks.txt) retains named expected/actual combat assertions, measured tie differences, completion markers and the complete deliberately exhausted Match trace. Every failing assertion also prints the Match view and interval trace, including time, slot, revision, phase, eligibility/history, damage, velocity/pending launch and surfaces.

| Cases through production Match | Expected and observed result |
| --- | --- |
| Both authored kits, six ordinary directions plus recovery | Correct move/facing selected and locked; commitment prevents jump/attack cancel; held attacks do not repeat; recovery wins simultaneous input priority and keeps resource/action restrictions after its phase ends. |
| Startup, one-step active, attack recovery | Inactive intervals never hit. A fast crossing entirely within the first active interval hits. A startup crossing cannot become a later sweep. Equal-speed parallel motion stays separated. |
| Dedupe/history and four real slots | Duplicate hurtboxes yield one hit; one attack strikes three targets in a true tie; history survives pause/overlap; a fresh attack can hit that target again. Independent same-character state uses the same prepared content. |
| Damage, mass and stun | Damage precedes launch; greater damage increases launch/stun; heavier target reduces launch; stronger launch hits the 60-step stun cap; landing preserves hitstun and prevents steering. |
| True, near and distinct contacts, reversed enumeration | Mutual trades preserve both hits. Equal simultaneous left/up and right/up launches sum upward; unequal contributions retain their vector remainder. Near contacts outside `1e-7` are distinct, both damage and the later replaces launch using updated damage; reversed Character enumeration preserves results. |
| Earlier interruption/native requery | A hit interrupts an attack before its future candidate. A wall blocks a would-be chord hit. Floor and wall produce piecewise native motion; separating corner movement progresses. Pending launch release queries the wall anew and stops against it. |
| Exact landing ties | Fixtures derive combat time from the production native horizon and actual stored coordinates. At `(640,530)`, speed 600, combat connects before aerial action ends, six-step delay remains intact and the target's downward pending launch is floor-constrained. Additional `(600,525)`, speed 900 and `(680,532)`, speed 840 fixtures report zero normalized-time disagreement in the retained run. Contacts 0.001 step earlier connect; 0.001 later are rejected after landing. |
| Ring-out/combat tie | Characters at/outside the limit are removed at time zero before tied combat, generating ring-out events only. No stock/winner claim is inferred. |
| Local pause/re-hit/release | Involved positions/phase/stun and buffer expiry freeze while a third participant moves; a frozen attack cannot hit a newly arriving target. A fourth attacker can strike the frozen vulnerable target, add damage, clear its new buffer, replace pending launch and restart pause. Three full frozen steps retain launch; release applies it once without extra hit, steering or pause restart. |
| Whole Match pause/clear | Whole-step counters and poses remain unchanged while paused. Input clear empties queued Character actions. Protection prevents hits and beginning an attack ends protection before contacts. |
| Drop, landing delay and recovery resources | Fresh down removes one-way support before selecting aerial down; solid ground selects ground down. Landing applies six full delayed steps; buffered jump begins afterward. Actual incoming hit clears recovery lock without replenishing spent jump/special. |
| Diagnostic termination/restart | A one-event fixture budget stops after a real native surface group with `completed:false`, one trace entry and step count zero. Further steps refuse success. An invalid restart clears feedback and disables automatic stepping. |

The existing export-smoke main was separately started with `--headless --path . --quit-after 5 -- --verify-quit`; it reported `EXPORT_SMOKE_PASSED` and loaded Zip/Bramble JSON. Character remains passive until configured/stepped, so smoke content does not start autonomous gameplay. This is a source startup regression check, not a newly exported-package acceptance run.

## Fixture corrections and limits

Initial fixture failures are retained in ignored `build/combat-direct.log` / bounded-run logs where applicable: grounding Bramble at Zip's body height caused overlap diagnostics; a wall fixture placed its target inside the wall; another fixture measured a post-prepare speed above the ordinary fall cap but restarted below that cap. Fixtures now derive body height and use achievable prepared velocities. No gameplay rule was changed to hide those failures. A GDScript fixture type annotation was also corrected before the final run.

Native spatial precision remains distinct from the `1e-7` time-group convention: casts use the existing 0.01 margin, 26 predicate refinements, 0.002 prefix-position tolerance, stationary axis-aligned rectangle scope and finite query budget. These checks establish the exercised native integrations, not arbitrary coordinate precision or performance. The bounded Match trace is diagnostic data, not a promised production telemetry/performance implementation.

A5-A10 combat portions and four-slot combat composition now have production evidence. Full A2/A13 restart/stock lifecycle, A11/A12 and application input/controller ownership remain #18. Visual phase poses/flash, human responsiveness/tuning, all physical controllers, complete sessions, fresh packaged gameplay, cross-PC, Linux/Deck/TV and frame performance remain unverified. #20 stays open for hardware review; #19/#21 retain their human gates.
