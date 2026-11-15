# Combat timing experiment

**Status: native fixture measurements complete; human feedback accepted.** This resolves the focused experiment in [#11](https://github.com/Fusion2k/smash-fight/issues/11), not first-playable acceptance or the final architecture decision.

The runnable artifact is preserved at [prototype/combat-timing, commit 3820f96](https://github.com/Fusion2k/smash-fight/tree/3820f96), outside main. Read its [run instructions and interpretation](https://github.com/Fusion2k/smash-fight/blob/3820f96/prototype/README.md), [raw observations](https://github.com/Fusion2k/smash-fight/blob/3820f96/prototype/observations.json), and [actual scene map](https://github.com/Fusion2k/smash-fight/blob/3820f96/prototype/SCENE-MAP.md). On Windows, double-click **Run Combat Timing Lab.cmd** in that worktree; `run-prototype.ps1 -Measure` regenerates the JSON without a window. The launcher verifies Godot 4.7.2 and discovers the executable locally.

## What ran

The lab measured Godot `4.7.2.stable.official.ed1daf0bf` on Windows at 60 physics steps/sec, with GodotPhysics2D explicitly selected and no loaded GDExtensions. Its replay displays the measured traces at eight steps/sec. Opening the lab reruns physics; replay controls inspect those recorded observations.

Five approaches share constant-size rectangular fixtures: Area overlap polling in the movement callback, Area signals, direct endpoint queries after target movement, passing both world motions to a shape collision check, and a shape check using relative motion against a stationary previous target pose. Targets move using `CharacterBody2D.move_and_collide`. Both world-space and relative-motion sweeps use the engine's `Shape2D.collide_with_motion` method.

## Observed hits

Each count includes the same attack-ID/target ledger. Raw observations and engine-frame timestamps remain available in the JSON.

| Fixture | Poll | Signal | Endpoint | Two motions | Relative | Expected |
| --- | --- | --- | --- | --- | --- | --- |
| One-step activation | 0 | 1 | 1 | 1 | 1 | 1 |
| Fast attack crossing | 0 | 0 | 0 | 1 | 1 | 1 |
| Fast target crossing | 0 | 0 | 0 | 1 | 1 | 1 |
| Target enters this step | 0 | 0 | 0 | 1 | 1 | 1 |
| Parallel motion, staying apart | 0 | 0 | 0 | 1 | 0 | 0 |
| Three targets | 3 | 3 | 3 | 3 | 3 | 3 |
| Persistent overlap and a later new attack | 2 | 2 | 2 | 2 | 2 | 2 |
| Startup crossing | 0 | 0 | 0 | 0 | 0 | 0 |
| Inactive crossing | 0 | 0 | 0 | 0 | 0 | 0 |

For the newly activated one-step overlap, direct/snapshot detection occurred in engine frame 8; the Area signal arrived in frame 9. When the target moved into the attack in that callback, the direct query missed it and the next callback's pre-movement query saw it. Moving all characters before querying is therefore insufficient evidence that direct-space queries are fresh in this schedule.

Passing both motions separately produced a false hit when two separated objects moved equally fast along overlapping swept paths. Using attack motion minus target motion avoided that false positive while retaining fast-crossing hits. Newly active attacks use their current pose, preventing a sweep through startup movement; inactive intervals cannot hit.

Two additional fixtures completed the eleven-scenario run:

- Immediate interruption yielded damage `[0, 12]` with A processed first and `[12, 0]` in reverse. Collecting both native query candidates first yielded `[12, 12]` in either order.
- A character passed upward through a one-way platform, landed, dropped on one scripted down action, and landed again after the temporary collision exception was removed. Separate character masks allowed mutual pass-through.

The relative-translation candidate, batched trade checks, and platform checks passed. This does not mean the comparison methods all passed. The replay's collision, trade, and platform views were rendered and visually inspected; the final graphical runs logged no errors.

## Architecture implications and limits

The candidate to review in [#8](https://github.com/Fusion2k/smash-fight/issues/8) is explicit movement/shape snapshots, eligible active intervals, pairwise relative-translation checks, per-attack target history, and collecting valid hits before applying interruption. These findings support a candidate; they do not settle production module interfaces, node types, or all physics ordering.

The fixtures cover constant axis-aligned rectangles and linear translations. Rotation, changing hitbox shape/size, curved motion, all arena contacts, alternate threading settings, hit pause, hitstun balance, gamepad input, stocks, and complete matches are unverified. The platform fixture uses a scripted down action and one simple surface: physical input edge detection, stacked-platform/held-down behavior, and high-speed landing need later checks. No performance measurement, Linux export, Steam Deck playtest, or Rapier comparison ran.

On 2026-11-15, after receiving the runnable lab, the user reported: "prototype looks good." This records the human reaction required by #11; no changes to the experiment were requested. It does not extend the measured coverage described above. The production scene tree remains proposed in the [scene map](scene-map.md), and #8 will use this evidence to settle the implementation responsibilities and update schedule.
