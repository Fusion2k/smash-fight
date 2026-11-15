# Combat timing lab - throwaway #11 experiment

Question: which collision sampling and hit-resolution approach supports one-step attacks, moving characters, repeat-hit suppression, and simultaneous trades at 60 Hz in Godot 4.7.2?

This branch contains a runnable native Godot experiment, not the first-playable game. The lab measures actual physics behavior at startup, then lets you replay recorded steps at eight steps per second. It does not present fabricated gameplay or preloaded JSON as live simulation. Reopening reruns the measurements.

## Run

On Windows, double-click **Run Combat Timing Lab.cmd** at the repository root. The launcher resolves Godot locally from `-GodotPath`, `GODOT_BIN`, PATH, or common installation directories, and verifies 4.7.2 stable. It contains no developer-specific installation path.

```powershell
.\run-prototype.ps1
# If automatic discovery does not find your installation:
.\run-prototype.ps1 -GodotPath 'D:/YourGodot/Godot_console.exe'
# Reproduce the JSON measurements without a window:
.\run-prototype.ps1 -Measure
```

On another platform, run Godot 4.7.2 with `--path .`, or import the root project and press Run. Native Linux/Steam Deck execution has not been verified here. GDScript and the Compatibility renderer are conveniences for this isolated experiment; they do not settle the production choices in #8/#9.

Click a scenario, then use Replay, Play/pause, or Step. Keyboard: **1-9**, **0** for trades, **-** for the platform fixture; **Space** pauses, **N** steps, **R** replays. Yellow is the attack, blue is a target, gray is the previous attack pose. A translucent yellow region shows world-space attack travel; target trails show target travel. The collision calculation uses relative motion, not just the visible world-space corridor.

The display distinguishes raw observations from accepted hits. Signals are replayed at their recorded engine frame, preserving their later callback timing. Logical attack tick and actual engine frame are both recorded in [observations.json](observations.json).

## Methods and observed counts

Measured on Windows with `4.7.2.stable.official.ed1daf0bf`, 60 physics steps/sec, explicit GodotPhysics2D configuration, and no loaded GDExtensions. The reported `PhysicsServer2D` singleton class name is generic; configuration and absence of custom extensions establish the baseline, not that name alone.

All five methods see the same fixture geometry. Targets move with `CharacterBody2D.move_and_collide`. The Area is repositioned and monitoring enabled/disabled in `_physics_process`; polling happens in that callback. Direct endpoint queries follow target movement in that callback. Pairwise shape checks use explicit previous/current transform snapshots.

| Fixture | Area poll | Area signal | Direct endpoint | Two-motion sweep | Relative sweep | Expected hits |
| --- | --- | --- | --- | --- | --- | --- |
| One-step activation | 0 | 1 | 1 | 1 | 1 | 1 |
| Fast attack crossing | 0 | 0 | 0 | 1 | 1 | 1 |
| Fast target crossing | 0 | 0 | 0 | 1 | 1 | 1 |
| Target enters this step | 0 | 0 | 0 | 1 | 1 | 1 |
| Parallel motion stays separated | 0 | 0 | 0 | 1 | 0 | 0 |
| Multiple targets | 3 | 3 | 3 | 3 | 3 | 3 |
| Persistent overlap / later new attack | 2 | 2 | 2 | 2 | 2 | 2 |
| Startup movement | 0 | 0 | 0 | 0 | 0 | 0 |
| Movement after deactivation | 0 | 0 | 0 | 0 | 0 | 0 |

Each count applies an attack-ID/target ledger. Persistent overlap therefore produces one accepted hit per attack, not damage on every observation. A later attack may hit again.

The one-step signal arrived in engine frame 9, following activation/direct detection in frame 8. It was attributed to the attack active during the preceding physical interval. This does not establish that signal and immediate query paths share the same latency or can be mixed without a lifecycle policy.

Passing both objects' world motions separately to `Shape2D.collide_with_motion` produced a false positive in the parallel-motion negative control. Sweeping attack motion minus target motion against the target's previous stationary pose avoided it. On a newly active tick, start at the current pose instead of sweeping through startup movement. Inactive movement is never eligible.

The two additional fixtures show:

- Immediate hit interruption produces damage `[0, 12]` with A processed first and `[12, 0]` in reverse. Collecting both native query candidates before resolving produces `[12, 12]` in either order.
- Actual character movement passes upward through a one-way platform, lands, drops on a single scripted down action, and lands again after the temporary collision exception is removed. Character collision masks permit passing through each other.

`all_checks_passed` validates the relative-sweep candidate's fixture expectations, batched trade outcomes, and the platform checks. It does not mean every comparison method passes; their failures are the experiment's findings.

## Interpretation and limits

The working candidate is: capture movement snapshots, determine active attack intervals, gather pairwise relative-translation hits using explicit shapes/transforms, deduplicate per attack/target, then apply results together. This is evidence for discussion in #8, not a production module/interface decision. Area polling in this exact schedule is insufficient; immediate direct-space queries also missed the same-step moving-target fixture. These observations do not prove every possible Area/deferred/query schedule fails.

The fixtures use constant-size axis-aligned rectangles and linear horizontal movement. They do not validate rotating/changing attack shapes, curved motion, physics-thread configurations, all arena contacts, gamepad input, recovery feel, hit pause, hitstun tuning, stocks, or complete matches. The platform action is scripted: keyboard/gamepad down-edge detection, stacked-platform behavior, and long-held down are not implemented by this lab. Only one simple platform and modest falling speed are covered. No performance benchmark, native Linux export, Steam Deck test, or Rapier comparison has run.

Human reaction is still required by [#11](https://github.com/Fusion2k/smash-fight/issues/11). Try the fast crossing, parallel-motion negative control, trades, and platform replay; report any expected hit, false hit, or drop/trade result that feels wrong. Do not close #11 as though that feedback were already received.

## Files

- [timing_lab.tscn](timing_lab.tscn): entry scene.
- [timing_lab.gd](timing_lab.gd): scenario controls and recorded replay.
- [measurements.gd](measurements.gd): native physics fixtures and measurement collection.
- [observations.json](observations.json): committed raw results, metadata, and step/event traces.
- [SCENE-MAP.md](SCENE-MAP.md): actual experiment scene hierarchy and responsibilities.

The evolving scene map in the main branch documents this experiment separately from the proposed production scene tree. Preserve this code on `prototype/combat-timing`; do not merge the throwaway lab into the game.
