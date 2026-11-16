# Animation-timeline moves — PROTOTYPE (throwaway)

This is a throwaway Godot scene on a prototype branch. Nothing here is production code.
The only liftable file is `move_sampler.gd`.

## Question

Can one Godot Animation timeline author a Move's timing, hitbox extent, hurtbox
extent and gameplay state, while the frame-step simulation stays authoritative —
so a designer can drag keys in the editor instead of editing separate `.tres` fields?

## Verdict

**Yes, with conditions.** A real `Animation` resource sampled by integer step works:
`value_track_interpolate(track, step / 60.0)` returned exact keyed values for
Vector2 extents, offsets, an int phase and a bool active flag. Three named markers
(`startup_end`, `active_end`, `move_end`) came back at the correct steps. The sampled
values plugged straight into the production `HitDetection.next_contacts()` sweep with
no detector rewrite beyond accepting a different rectangle size per step.

Observed in the headless trace (`run-prototype.ps1 -Trace`):

- Baseline: contacts on steps **5, 6**.
- Moving the active window one step later (phase, eligibility, geometry, markers):
  contacts move to **6, 7**. Retiming only the phase would leave geometry behind.
- Shrinking the hurtbox extent at step 4 from `(30,46)` to `(10,40)` removes both
  contacts, without touching the authored Resource — `authored_baseline()` still
  reports `(30,46)` and a second instance sampling step 0 is unaffected.

So the editor timeline can own the authored values, and the simulation can still own
the clock, phase counters, hit resolution and pause rules. No `AnimationPlayer` is
played; `callback_mode_process` is set to `MANUAL` only so the timeline can be opened
and dragged in the editor.

## Conditions / things that would need real work

1. **Step-quantized geometry only.** Keys are snapped to `Animation.step = 1/60` and
   sampled only at step boundaries, with `INTERPOLATION_NEAREST` + `UPDATE_DISCRETE`.
   A rectangle may change size between steps, never morph within a step. This is the
   "separate measured detector extension" `docs/architecture/module-interfaces.md:72`
   requires; line 70's "fixed size and offsets during each active window" must be
   revised when this is adopted. The 108 chronological combat checks need new cases.
2. **Float32 key times.** `Animation` stores key times as float32, so
   `FIND_MODE_EXACT` with a float64 step time silently misses keys (this actually
   broke the first retime attempt). Use an epsilon lookup, as `move_sampler.gd` does.
3. **Never mutate the authored shape.** Write sampled extents into the per-step plan,
   as hitbox offset already is. Mutating a shared `RectangleShape2D` would break
   same-character/snapshot isolation (A2).
4. **Hurtbox fallback.** This prototype only overrides hurtboxes while a move is
   active; outside a move the authored scene hurtbox is the baseline. A production
   design must decide whether neutral/idle/hitstun hurtboxes get their own timeline.
5. **Validation.** The catalog currently requires fixed, enabled, unrotated rectangles.
   It would need to validate time-keyed extent tracks (positive size, axis-aligned,
   step-snapped) while the scene supplies the baseline.
6. **No method/call tracks.** Discrete value tracks were sufficient for every state
   toggle tested. Call Method tracks would add event-skipping and ordering hazards.

## Run it

```powershell
.\prototype\animation_moves\run-prototype.ps1          # interactive Godot scene
.\prototype\animation_moves\run-prototype.ps1 -Trace   # headless per-step trace
```

Or double-click `Run Animation Moves Prototype.cmd`. `GODOT_BIN` overrides the engine path.
The runner performs a quick headless editor import first, because `--script` runs do not
register global classes (`Character`, `HitDetection`) on a fresh checkout.

`lab_capture.png` and `lab_contact_capture.png` are real 1280x720 renders from the
interactive scene; the latter was captured by clicking "Run to end" through the UI.

## Files

| File | Role |
| --- | --- |
| `move_sampler.gd` | Pure, liftable sampling of an Animation into per-step combat values |
| `move_library.tres` | Generated 6-track, 3-marker AnimationLibrary (open it in Godot's animation editor) |
| `build_library.gd` | Generates the library resource; re-run if keys need regenerating |
| `animation_moves_lab.tscn` / `.gd` | Throwaway UI shell, free-play buttons and three guided scenarios |
| `combat_sample.gd` | Exported properties so animation track paths resolve in the editor |
| `geometry_view.gd` | Draws sampled hit/hurt rectangles and contact dots |
| `lab_trace.gd` | Headless per-step evidence using the production detector |
| `capture_lab.gd`, `capture_contact.gd` | Graphical captures |
