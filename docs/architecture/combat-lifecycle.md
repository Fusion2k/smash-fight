# Combat lifecycle

**Status: agreed gameplay relationships; native timing evidence and human reaction recorded, production schedule pending.** Source: [#2](https://github.com/Fusion2k/smash-fight/issues/2), with the down-input interactions specified in [#4](https://github.com/Fusion2k/smash-fight/issues/4). The [#11 experiment](combat-timing-evidence.md) supplies timing/collision evidence and the user's positive reaction; #8's implementation-order/hit-detection decision remains pending.

## Attack phases

```mermaid
stateDiagram-v2
    [*] --> AbleToAct
    AbleToAct --> Startup: Eligible buffered or fresh attack
    Startup --> ActiveWindow: Startup completes
    ActiveWindow --> AttackRecovery: Active window completes
    AttackRecovery --> AbleToAct: Recovery completes
    Startup --> Hitstun: Struck by a valid hit
    ActiveWindow --> Hitstun: Struck by a valid hit
    AttackRecovery --> Hitstun: Struck by a valid hit
    Startup --> LandingDelay: Aerial attack lands
    ActiveWindow --> LandingDelay: Aerial attack lands
    AttackRecovery --> LandingDelay: Aerial attack lands
    LandingDelay --> AbleToAct: Landing delay completes
    Hitstun --> AbleToAct: Hitstun completes
```

This view omits the orthogonal airborne-resource restrictions for readability. Completing attack recovery does not restore a spent air jump or recovery special. After a recovery special, steering is allowed but jumping/attacking remains unavailable until landing or being hit; taking a hit does not replenish either resource. The involved characters' action timers freeze during hit pause.

## Hit-result constraints

```mermaid
flowchart LR
    Candidates["Valid hits in one simulation step"] --> Once["Each attack hits each opponent once"]
    Once --> Damage["Apply damage"]
    Damage --> Launch["Calculate knockback<br/>Post-hit damage, mass, move direction"]
    Launch --> Response["Interrupt attack and impose hitstun"]
    Response --> Feedback["Hit flash, hit pause, launch feedback"]
    Candidates -.-> Trades["Simultaneous valid hits trade<br/>Character iteration order must not choose a winner"]
```

Arrows express rule dependencies. They do not prescribe Godot callback order, querying before/after movement, a collision-node type, or a synchronization strategy. Ring-out decisions must likewise consider all players for the simulation step before producing a result.

## Timing baseline and evidence needed

The provisional baseline is 60 simulation steps per second, with a six-step input buffer, five-step ground-jump grace period, three-step hit pause, and six-step aerial landing delay. These are playtest starting values; the canonical values and exceptions live in #2.

The completed #11 experiment compares plausible approaches where their observed behavior differs, covering one-step active windows, fast movement, activation/deactivation relative to physics, repeated overlaps, multiple targets, and simultaneous hits. Its [measured results and limitations](combat-timing-evidence.md) identify a relative-translation shape-snapshot candidate and batched hit resolution. Eleven scenarios were measured and the user reported "prototype looks good"; these are not complete-match acceptance checks.

[Backend research #12](https://github.com/Fusion2k/smash-fight/issues/12) recommends the built-in backend as an initial baseline, with Rapier v0.36.1 retained as an alternative. The [source evaluation](https://github.com/Fusion2k/smash-fight/blob/1fb7589/docs/research/physics-backend-evaluation.md) identifies Rapier's backend-specific query refresh as a separate experiment if freshness matters; it does not establish an immediate Area-overlap refresh or solve per-attack hit history and simultaneous trades. Physics ordering and the production backend remain pending decisions. Box2D is deferred by the user.
