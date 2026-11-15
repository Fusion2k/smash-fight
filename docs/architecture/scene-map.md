# Scene map

**Status: accepted production composition in [#8](https://github.com/Fusion2k/smash-fight/issues/8), confirmed on 2026-11-15; not implemented.** The main working tree has no gameplay scenes or configured main scene. Paths below are accepted implementation targets; actual scene paths will replace them as implementation lands. The timing labs remain separate experimental branches. Native scheduling and complete-match acceptance remain unverified.

This view translates the agreed [match flow](https://github.com/Fusion2k/smash-fight/issues/4), [combat scope](https://github.com/Fusion2k/smash-fight/issues/2), and confirmed [arena direction](https://github.com/Fusion2k/smash-fight/issues/3) into an accepted scene composition. During #8 on 2026-11-15, the user accepted GDScript and the ownership split: application flow owns slots/controllers, Match owns stocks/results and simulation order, Character owns movement/combat state, and a catalog owns content validation. The [module interfaces](module-interfaces.md) record the accepted contract.

## Accepted composition

Solid lines show accepted parent/child composition. Dashed lines show phase-dependent views: the diagram does not require every menu and match view to remain loaded at once. Every production node remains unimplemented.

```mermaid
flowchart TB
    App["Application root<br/>Active flow and view composition"]

    subgraph Frontend["Frontend views Ã‚Â· active as needed"]
        direction LR
        Join["Join and character select<br/>Slots, picks, ready status"]
        Results["Results<br/>Winner or draw, rematch readiness"]
        Dev["Developer Test entry<br/>Keyboard plus stationary opponent"]
    end

    subgraph Gameplay["Match scene Ã‚Â· proposed"]
        direction TB
        Match["Match root<br/>Compose one match"]
        Arena["Arena scene<br/>Surfaces, spawn markers, ring-out limits"]
        Characters["Character instances<br/>One independent instance per player slot"]
        HUD["Match HUD<br/>Player markers, damage, stocks"]
        Overlay["Pause and countdown overlay<br/>Missing-controller and resume feedback"]
        Match --> Arena
        Match --> Characters
        Match --> HUD
        Main["Solid main surface"]
        Platforms["Two elevated one-way platforms"]
        Markers["Start and respawn markers"]
        Limits["Ring-out limits"]
        Camera["Fixed camera"]
        Arena --> Main
        Arena --> Platforms
        Arena --> Markers
        Arena --> Limits
        Arena --> Camera
        Body["Movement and collision representation<br/>Physics/damage from referenced JSON; geometry from editor"]
        Visual["Character presentation<br/>Silhouette, attack poses, hit feedback"]
        Characters --> Body
        Characters --> Visual
    end

    App -.-> Join
    App -.-> Results
    App -.-> Dev
    App -.-> Match
    App --> Overlay

    classDef application fill:#164e63,color:#ffffff,stroke:#22d3ee,stroke-width:2px;
    classDef flow fill:#ede9fe,color:#3b0764,stroke:#8b5cf6;
    classDef gameplay fill:#dcfce7,color:#14532d,stroke:#22c55e,stroke-width:2px;
    classDef content fill:#fef3c7,color:#78350f,stroke:#f59e0b;
    classDef presentation fill:#dbeafe,color:#1e3a8a,stroke:#3b82f6;
    class App application;
    class Join,Results,Dev flow;
    class Match,Characters,Body gameplay;
    class Arena,Main,Platforms,Markers,Limits content;
    class HUD,Overlay,Camera,Visual presentation;
```

## Accepted responsibilities

| Scene role | Requirement it must support | Implementation status |
| --- | --- | --- |
| Application/frontend | Join, independent selection, readiness, results, and Developer Test entry | Proposed paths below; scenes not implemented |
| Match composition | Complete restartable matches, pause, controller loss, and same-step outcomes | Accepted in #8; not implemented |
| Arena | Main surface, two one-way platforms reachable by both characters' jumps, fixed view, safe starts, respawn positions, and ring-out limits | Topology and recovery expectations agreed in #3; dimensions and scene layout pending |
| Character instance | Independent movement, damage, attack state, and airborne resources for every player slot | Authoring agreed in #7 and timing evidence completed in #11; ownership/Resources/geometry accepted in #8; composition accepted; not implemented |
| HUD/presentation | Distinguishable players, damage/stocks, attack phases, and hit feedback | Requirement agreed; accepted paths below; not implemented |
| Pause/countdown presentation | Frozen match state, explicit missing-slot replacement, and three-second resume countdown | Behavior agreed in #4; application-owned overlay accepted below; not implemented |

### Accepted scene targets

| Scene path | Composition and responsibility |
| --- | --- |
| `app/app.tscn` | Application root; active frontend or Match child; flow overlay in a CanvasLayer that can process while gameplay is frozen. Owns slot/controller flow. |
| `frontend/join_select.tscn` | Join/select/ready view driven by application-owned slots. |
| `frontend/results.tscn` | Winner/draw and rematch/return commands. |
| `frontend/flow_overlay.tscn` | Start/resume countdown, pause and missing-controller UI, driven by application flow. Composed by the application so it can keep processing while Match is gated off. |
| `match/match.tscn` | Match root script, replaceable Arena instance, a character container populated from slot IDs, and HUD. Owns stocks, respawn scheduling, the step callback and result calculation. |
| `match/match_hud.tscn` | Reads a match view; rows come from slot IDs rather than hardcoded P1/P2 character nodes. |
| `arenas/first_arena.tscn` | StaticBody2D surfaces, two one-way platforms, Marker2D starts/respawns, editor-authored ring-out rectangle and fixed Camera2D. |
| `characters/character.tscn` | Shared CharacterBody2D behavior, surface CollisionShape2D, editor-authored rectangular hurtboxes and visual child. No independent gameplay physics callback. |
| `characters/zip/zip.tscn`, `characters/bramble/bramble.tscn` | Character scenes based on shared character behavior, with original silhouettes, editor geometry and visuals. Corresponding CharacterDefinition and MoveDefinition Resources supply authored content. |

Developer Test uses the same Match scene with keyboard and stationary input adapters. It needs no second combat implementation or special arena. The input adapters, character catalog, hit detection and hit resolution are script modules rather than empty scene nodes. The [module interfaces](module-interfaces.md) specifies communication and state ownership; gameplay uses explicit ordered calls and presentation can subscribe to events.

[ADR 0002](../adr/0002-physics-json-and-editor-authored-geometry.md) fixes the authoring split: character physics tuning and attack damage come from JSON referenced by editor-authored character content. Geometry, attack timing, and launch direction/strength are edited in Godot. Production hit/hurt shapes must use that editor-authored source instead of duplicating dimensions in JSON. See [character authoring](character-authoring.md) for the accepted schema and reference workflow. The #11 lab's constant rectangle fixtures are experimental inputs, not a character-file schema.

## Physics backend status

[Research #12](https://github.com/Fusion2k/smash-fight/issues/12) evaluated GodotPhysics2D and Godot Rapier 2D before the timing experiment in #11. Its [cited report](https://github.com/Fusion2k/smash-fight/blob/1fb7589/docs/research/physics-backend-evaluation.md) recommends GodotPhysics2D as the initial baseline and retains Rapier v0.36.1 as a credible alternative if a relevant problem is demonstrated. During #8 on 2026-11-15, the user accepted GodotPhysics2D with explicit shape snapshots and batched hit collection. Box2D remains deferred. No project configuration change or production validation is claimed. The current `project.godot` has no custom 2D-backend selection; its Jolt setting is specifically `3d/physics_engine`.

Backend compatibility and packaging evidence will inform #8 and #9. The initial GodotPhysics2D fixtures now record short-window hits, query-freshness differences, one-way-platform movement, and simultaneous outcomes as described below. The user reported "prototype looks good" after reviewing the lab. Production gameplay coverage, other backends, and target-platform verification remain outstanding.

## Implemented #11 timing lab

This hierarchy exists on [prototype/combat-timing at 3820f96](https://github.com/Fusion2k/smash-fight/tree/3820f96). Read the [experiment instructions](https://github.com/Fusion2k/smash-fight/blob/3820f96/prototype/README.md) and [measured evidence](combat-timing-evidence.md). It is separate from the accepted production composition above.

```mermaid
flowchart TB
    Lab["CombatTimingLab Ã‚Â· Node2D<br/>prototype/timing_lab.tscn<br/>prototype/timing_lab.gd"]
    UI["Status label and scenario/replay buttons<br/>Created at runtime"]
    Measures["Measurements Ã‚Â· Node2D<br/>prototype/measurements.gd"]
    Area["MeasuredAttackArea Ã‚Â· Area2D<br/>64 Ãƒâ€” 38 rectangle"]
    Targets["Target0..2 Ã‚Â· CharacterBody2D<br/>28 Ãƒâ€” 50 rectangles"]
    Platform["OneWayPlatform Ã‚Â· StaticBody2D<br/>220 Ãƒâ€” 12 one-way rectangle"]
    Characters["PlatformCharacter / OtherCharacter<br/>CharacterBody2D"]
    Lab --> UI
    Lab --> Measures
    Measures --> Area
    Measures -.-> Targets
    Measures -.-> Platform
    Measures -.-> Characters
    classDef root fill:#164e63,color:#ffffff,stroke:#22d3ee,stroke-width:2px;
    classDef ui fill:#dbeafe,color:#1e3a8a,stroke:#3b82f6;
    classDef measure fill:#dcfce7,color:#14532d,stroke:#22c55e;
    classDef physics fill:#fef3c7,color:#78350f,stroke:#f59e0b;
    class Lab root;
    class UI ui;
    class Measures measure;
    class Area,Targets,Platform,Characters physics;
```

Dashed edges are fixture-dependent children. Each physics object has a `CollisionShape2D` child; the [full archived hierarchy](https://github.com/Fusion2k/smash-fight/blob/3820f96/prototype/SCENE-MAP.md) includes those shapes. Measurement code runs native physics fixtures first. The root then draws a slowed replay of recorded traces, with actual engine-frame timestamps for delayed signals. This runtime tree is intentionally small and disposable; it does not decide production scene/module responsibilities.

## Evolution checks

- Tune Zip's movement or mass: change its physics JSON, without duplicating the match scene. Change graphics-dependent geometry in the editor.
- Add Bramble: reuse the agreed combat lifecycle with different definition values and presentation.
- Select Zip twice: compose two instances with independent mutable state and player markers.
- Change the arena: keep geometry, start/respawn markers, and ring-out limits local to its content definition/scene.
- Grow to four players: compose instances from player slots; scene responsibilities must not assume exactly two hardcoded character children. Four-player content and hardware acceptance remain later work.

These are verification requirements for the accepted architecture, not passed checks. Replace implementation targets with actual scene paths as implementation lands.

## #13 contact chronology extension

A separate [throwaway extension](https://github.com/Fusion2k/smash-fight/blob/f7a36da/chronology/README.md) on `prototype/contact-chronology` adds `chronology/lab.tscn` (Control), a replay UI in `chronology/lab.gd`, and a pure analytic scheduler in `chronology/model.gd`. The root temporarily creates native CharacterBody2D/StaticBody2D rectangle pairs to measure two surface boundaries, then releases them. Replay drawings are model traces, not native character motion. The original #11 tree above remains preserved.

See [contact chronology evidence](contact-chronology-evidence.md) for fifteen completed fixtures, numerical proposals and limits. Imported surface boundaries were not re-queried after changed trajectories. The accepted [production interval contract](module-interfaces.md#native-interval-contract) requires native prediction/commit agreement and fresh queries after every event; implementation verification belongs in #10. The user reported "looks ok, keep going" on 2026-11-15, completing #13's human reaction. Automated visual QA remains unverified; the reaction does not establish integrated native gameplay.