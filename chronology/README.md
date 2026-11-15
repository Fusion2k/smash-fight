# Contact chronology — throwaway #13 extension

Question: can fixed rectangular hitboxes/hurtboxes distinguish chronological contacts from true ties, re-evaluate motion after hits, preserve first-active crossings and respect piecewise arena paths?

This extends the native #11 lab without changing its archived code/results. **Not production code.** `prototype/combat-timing` preserves #11; this extension lives on `prototype/contact-chronology`.

## Run

Double-click **Run Contact Chronology Lab.cmd** at the checkout root. Choose a scenario, press **Next event** to advance through its recorded state, and **Restart** to reset. Rectangles and trails show each character; the panel exposes position, velocity, damage, attack eligibility, pause, initial candidates and resolved events.

```powershell
.\run-chronology.ps1
.\run-chronology.ps1 -Measure
# Optional explicit installation:
.\run-chronology.ps1 -GodotPath 'D:/Godot/Godot_console.exe'
```

The portable launcher requires Godot 4.7.2 stable. Native command: `godot --path . res://chronology/lab.tscn`; add `--headless -- --measure` for JSON-only measurement. Opening reruns measurements and writes `chronology/observations.json`. All units are pixels per normalized single 60 Hz step, not tuned game velocities.

## Methods and observations

Executed on Windows with Godot `4.7.2.stable.official.ed1daf0bf`. Fifteen fixtures reached `end_time=1`, `completed=true`. The bounded event loop exposes incomplete runs explicitly after 40 iterations; it is not a production termination strategy.

`model.gd` is an **analytic swept-AABB model running in Godot**, using relative velocity and slab entry/exit intersections. It does not use native shape booleans to infer time. It advances to the earliest group, calculates group results before interruption, updates histories, and recomputes candidates using changed motion/eligibility. Initial candidate times are recorded to show why sorting once is insufficient.

| Fixture | Measured interpretation |
| --- | --- |
| Distinct hits, either enumeration | Contacts 0.4 and 0.580180174; initial second candidate was 0.6. Target ends at 20 damage, launch (-1.2,-1.2); second hit reverses horizontal launch. |
| Distinct hits with pause | Contacts 0.4 and 0.6; frozen vulnerable target still accepts the arriving second attack. |
| True tie, either enumeration | Both contacts 0.4; 20 damage and vector-summed launch (0,-2.4). |
| Near tie | Initial times 0.4/0.400099993 remain separate; second re-evaluates to 0.400090084 after first launch. |
| Parallel/startup/inactive controls | No accepted contacts. |
| First active interval | Eligible range [0.2,0.5) retains contact at 0.4. |
| Early interruption / pause | Mutual hit at 0.4 disables both attacks; initial later candidates at 0.65/0.7 are discarded after re-evaluation. |
| Wall piecewise path | Wall boundary ~0.398437476 then valid contact 0.4. Whole-step endpoint chord would miss this target. |
| Before / after landing | Contact at 0.2 retained before landing ~0.496093702; candidate at 0.6 rejected after landing. |

Two **separate native surface probes** use `CharacterBody2D.move_and_collide(test_only=true, safe_margin=0.00001)` against wall/floor rectangles. Travel is (3.984375,3.984375)/(4.960937,4.960937), normal (-1,0)/(0,-1). These approximate collision-travel fractions are imported into the analytic wall/landing fixtures; they are not exact analytic surface times. The remaining tangent velocity and attack-ending landing transition are model rules.

## Provisional conventions and limits

- Contact equality uses absolute tolerance `1e-7` of a step; the near-tie fixture is about `1e-4` apart. This verifies those cases, not all coordinate scales or floating-point stability. Godot Vector2 is single precision here.
- Tied attacks add damage first, then each contributes `authored_launch * (1 + post_group_damage/100)`; sum their vectors. Distinct groups use newly updated damage. Formula, tolerance and hitstun convention remain decisions for #8; no mass/hitstun calculation is validated here.
- Pause is held for the remainder of this one-step fixture. Launch contributions are recorded in events, while paused motion velocity becomes zero. Release, timer duration, pending-velocity restoration, buffers and later steps are absent.
- Native wall/floor boundaries are fixed probes of an unperturbed initial trajectory. They are **not recomputed after hit changes to arena motion**. Integrated native arena/combat scheduling, multiple surfaces, one-way platforms, exact boundary/contact ties, ring-outs and respawns remain unverified. A production scheduler must invalidate stale surface events as well as combat events.
- All characters use coincident 2x2 attack/hurt rectangles. Fixed offsets, mass, full movement, animation and real character content are outside this fixture. Active eligibility is [start,end), with no event at the final endpoint.
- Windows headless execution and the portable launcher were verified. The graphical process launched, but screenshot capture hung and was aborted; **visual layout and interactive controls have not been verified**. No human reaction to this new experiment has been received. Old #11 feedback does not validate it. No Steam Deck, Linux, performance or gameplay acceptance is claimed.

## Human review needed

Try **Distinct hits**, **True tie: opposing launches**, **Near tie**, and the wall/landing cases. Do sequential reversals and simultaneous upward combination match the intended rule? Report anything surprising and whether the replay is readable. The engineering tolerance/formula are proposals for review, not settled production choices. #13 remains open pending this new feedback and any required integrated-motion evidence.