# Native Character movement evidence (#16)

Implemented source: the commit containing this report, based on `a4b8da409871081c42c2ffafea1b856555b460e6`. The issue resolution records the final commit and post-commit check run. Date: 2026-11-15. Host: Windows, Windows PowerShell 5.1, Standard Godot `4.7.2.stable.official.ed1daf0bf`, built-in GodotPhysics2D, headless Compatibility configuration, 1280x720 canvas_items/keep/fractional layout. Deterministic authored fixtures; no random seed, controller, GUI or hardware measurement.

Run from the repository root, substituting the local executable path:

```powershell
./tools/dev.ps1 check -GodotBin <local-Godot-4.7.2-console.exe> -TimeoutSeconds 120
```

Expected: bounded import, 7 foundation checks, 96 native movement checks and 60 catalog checks complete; exit 0. Actual: all passed, exit 0, in approximately 8.9 seconds including import/catalog, at `build/logs/20261115-221240-137-7244/`. The post-commit source check is recorded in the issue resolution. The catalog's nonfinite-number fixture intentionally produces `Exponent too high`; no unexpected engine/script error is accepted. Per-process stdout/stderr and `run.json` remain locally under ignored `build/logs/`.

## Delivered behavior and real-interface checks

`checks/movement.gd` instantiates prepared Zip/Bramble scenes, attaches them to a real SceneTree with `arenas/first_arena.tscn` and the native fixture `checks/movement_arena.tscn`, and drives `prepare_step`, `predict_interval`, `commit_interval`, `apply_event_group`, `finish_step` and `respawn`. All surface queries use production `PhysicsServer2D.body_test_motion`; no analytic world or alternate test movement model supplies contact times. The fixture's bounded driver coordinates only these methods; Match chronology remains #17.

| Named check group | Expected and actual result |
| --- | --- |
| Prediction/prefix/revision | Repeated prediction leaves pose/state/revision unchanged; shorter commits agree; old plans fail after prefix/event changes; commits beyond the predicted horizon and premature finish fail |
| Piecewise native surfaces | Fast diagonal motion stops first at floor/wall, continues tangentially and stops the other component later; upward wall tangent, separating motion and ceiling contacts progress |
| Native true/near corner groups | At two independently measured native corner ties both normals are returned, both components stop and zero-time requery progresses; a 0.02-unit floor offset remains a distinct single-normal event |
| Prefix subdivision | At 120, 900 and 4500 units/s, committing 37% of the first horizon then re-querying agrees within 0.002 world units; measured disagreement in the recorded pre-final run was about 0.000032 units for each |
| Ground/air movement | Analog half-speed, one acceleration application, ground braking, facing changes, committed ground speed/facing lock, air acceleration, gravity/fall cap and descending-only fresh-down fast-fall pass; being hit clears fast-fall |
| Downward hit launch | A downward 5000-unit/s hitstun launch advances to 5030 under gravity, rather than being truncated by the ordinary 900-unit/s fall cap |
| Jumps/resources | Early ground-jump release cuts height; air jump has fixed release height and one use; ground/air recovery consumes one use and locks other actions while permitting steering; being hit unlocks without restoring spent resources; landing/respawn restores resources |
| Buffer/grace thresholds | Latest action replaces older buffer; same-frame priority special, attack, jump; buffer on either side of five/six preparations and real-edge grace on either side of four/five preparations behave as specified |
| Native one-way/drop | Rise through stacked platforms, land from above, fresh down ignores only supporting platform; held down lands/stays on next; fresh second down drops again; commitment/hitstun forbid drop and solid ground cannot drop |
| Authored Arena baseline | Both Zip and Bramble reach each elevated platform, recover from both modest side markers, and fail the deeper left marker; start/respawn discovery follows authored Marker2D children; ring-out rectangle edge is inclusive |
| Isolation/pass-through | Four native bodies including duplicate characters have independent runtime state and RIDs; movement of one leaves the other unchanged; identical poses pass through without character body blocking |
| Future pause seam | Frozen prediction/commit stays stationary and buffer expiry freezes; a supplied floor surface constrains pending launch. This does not establish local-pause onset/re-hit/release or timer lifecycle |
| Diagnostics/termination | Rotated Character, unsupported support shape, multiple shapes/body, rotated/scaled arena rectangles, conveyors and moving bodies fail explicitly; native body-query exhaustion returns bounded trace and cannot finish the partial step |

## Native precision and supported geometry

Production surface support is one enabled, stationary, axis-aligned, unscaled RectangleShape2D per StaticBody2D. Validate the Arena before composing a future Match; a native encounter with unsupported geometry also fails diagnostically. This prevents silently omitting a second same-body corner normal. Character surface geometry was validated by #15. Dynamic/moving/conveyor/rotated/scaled/compound surfaces are outside this implemented arena scope.

Native motion casts use margin 0.01, 26 bounded native predicate refinements, 32 body-enumeration attempts, provisional normalized-step tie tolerance `1e-7`, and prefix agreement tolerance 0.002 world units. One-way shapes use native margin 1.0: the earlier 0.01 authored one-way margin did not reliably catch falling bodies. These are engineering precision/tuning values, not guarantees beyond native single-precision coordinates. Resting/contact positions follow native collision/recovery margins rather than exact analytic rectangle boundaries.

The fixture calibrates native horizontal/vertical horizons independently at world distances 10 and 20; it does not label nominal decimal coordinate equality a native tie. Recorded horizons were `0.49998165667057` and `0.49999083578587`, each with both left/up normals. Offset near-corner horizons were approximately `0.49898072` and `0.49949034`, each with only the upward normal. Recalibration is through the same production query and does not replace native collision geometry.

## Retained failure evidence

The last diagnostic regression was observed red before the fix with the real suite at `build/logs/20261115-220723-154-23356/`: `unsupported support fails preparation diagnostically expected=true actual=false { "ok": true }`; the runner exited 1. `_find_support` discarded the native query's error and treated unsupported geometry as no support. It now returns the error to `prepare_step`; the same fixture returns `unsupported_arena_surface`, slot/revision/cursor/pose and the unsupported scene path, while `finish_step` returns `incomplete_step`. The subsequent green run above locks down that behavior.

The initial continuation run at `build/logs/20261115-220618-055-25984/` failed import because the filesystem sandbox prohibited Godot's normal editor-settings write outside the checkout. Rerunning with that access succeeded; this was not a movement-code failure. Previous development also refined raw quantized native horizons and authored one-way margin; the committed regression cases preserve those failure patterns.

The intentional 32-body crowded fixture returns `native_query_budget_exhausted` with slot/revision/time/pose/velocity, query motion, bounded contacts and configured body/refinement limits. The suite prints a compact `TRACE native budget` line and checks the cursor remains zero and finish is rejected. Native corner traces and failed driver steps include normalized time, slot, revision, position, velocity and surface normals. Exhaustion is expected only in this negative fixture, never accepted as successful partial gameplay.

## Limits and handoff

A4 movement/resources and the movement portion of A10 are implemented, with A7/A8 native surface subcases, A2 movement isolation, four-body capacity and an automated H4 reach baseline. Recovery markers are provisional: main surface x=240..1040 at y=560; platforms centered x=440/840 at y=400; modest markers (200,620)/(1080,620), deeper markers (200,880)/(1080,880). Only the deeper left marker is exercised automatically. These deterministic action sequences do not pass H4's human review.

#17 must add attacks, down-plus-attack aerial selection, damage/launch resolution, chronological Match orchestration, exact combat/surface/ring-out ties, local hit-pause lifecycle and combat timers/history. #18 must add stocks, application/input/controller flow and complete restartable matches. Presentation/playtest tuning and all human feel/controller/cross-PC/native Linux/Deck/TV/performance gates remain outstanding. There is no runnable application main scene in this stage, no GUI acceptance claim and no Deck hardware pass. The automated four-body check does not establish four-player shipping support.
