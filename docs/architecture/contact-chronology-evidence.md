# Contact chronology evidence

Status: [#13](https://github.com/Fusion2k/smash-fight/issues/13) remains open for new human feedback and review. This is additional evidence for #8, not a finalized production scheduler. The accepted gameplay distinction remains chronological distinct hits versus vector-summed true ties.

The throwaway [native runnable extension](https://github.com/Fusion2k/smash-fight/blob/f7a36da/chronology/README.md) and [raw measurements](https://github.com/Fusion2k/smash-fight/blob/f7a36da/chronology/observations.json) are preserved on `prototype/contact-chronology`. The original #11 lab remains unchanged at `3820f96` on `prototype/combat-timing`. Main contains no throwaway implementation.

On Windows, double-click **Run Contact Chronology Lab.cmd** in that checkout, or run `./run-chronology.ps1`. `./run-chronology.ps1 -Measure` reproduces JSON headlessly. The launcher discovers a local Godot 4.7.2 stable installation without a developer-specific path.

## Observed results

Godot `4.7.2.stable.official.ed1daf0bf` executed fifteen fixtures; every run reports `completed=true`, `end_time=1`. These are an **analytic swept-rectangle model executed in Godot**, plus two separately measured native surface probes. They do not measure a complete native gameplay simulation.

| Case | Observation |
| --- | --- |
| Distinct hits, reversed enumeration too | Hits at normalized fractions 0.4 and 0.580180174. Second pre-hit candidate was 0.6; re-evaluation changes it. Damage becomes 20, and the second launch reverses horizontal direction to (-1.2,-1.2). |
| True tie, reversed enumeration too | Both contacts at 0.4; combined damage 20; summed launch (0,-2.4). |
| Near tie | Initial gap about 0.0001 step stays sequential; updated second contact ~0.400090084. |
| Hit pause | A frozen vulnerable target receives an arriving second hit at 0.6. Pause is local to involved characters. |
| Early mutual contact | Both attacks interrupt at 0.4; their originally predicted later contacts at 0.65/0.7 do not resolve. |
| Eligibility controls | Parallel, startup and inactive cases produce no hits. First-active interval [0.2,0.5) retains crossing at 0.4. |
| Arena boundary fixtures | Piecewise wall path hits a target an endpoint chord would miss; a pre-landing hit at 0.2 survives, while a post-landing candidate at 0.6 is rejected. |

Native `CharacterBody2D.move_and_collide(test_only=true, safe_margin=0.00001)` measures wall/floor travel fractions ~0.398437476/~0.496093702. Those approximate probe boundaries split the analytic fixtures; tangent velocity and landing interruption are model rules. They are fixed unperturbed probes, **not recomputed native arena trajectories after hit changes**.

## Interpretation and remaining work

The measurements support earliest-group resolution followed by re-evaluation for these fixtures. They expose the loss of valid first-active crossings, whole-step tie grouping, endpoint chords, and sorting all candidates only once as inadequate shortcuts. They do not establish the integrated production movement interface.

Provisional engineering conventions are absolute tie tolerance `1e-7` normalized step and each tied launch scaled using shared post-group damage (`1 + damage/100`). Mass, hitstun, full move geometry and numerical robustness across coordinate scales remain unvalidated. The event loop reports incomplete results if it exhausts its 40-iteration bound; this is not a production termination strategy.

Pause lasts through the rest of this one-step fixture. No release, timer, stored-launch restoration, buffered input or later-step behavior is validated. Surface events must be invalidated and re-queried when preceding hits change motion in the production design; multiple surfaces, one-way platforms, ring-outs/respawns and exact combat/surface ties remain open integration work.

The headless launcher passed. A graphical process launched, but screenshot capture hung and was aborted. **Visual layout and interactive controls are unverified.** No new human feedback has been received; the user's old #11 feedback does not cover this experiment. No Linux/Steam Deck, gamepad, performance or gameplay acceptance is claimed.