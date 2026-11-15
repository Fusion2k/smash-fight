# Scene map

**Status: proposed production composition for [#8](https://github.com/Fusion2k/smash-fight/issues/8), with an implemented timing-lab map below.** The main working tree currently has no gameplay scene files or configured main scene. Production names below are descriptive working names, not agreed filenames or scripting-language choices. The throwaway lab lives on a separate branch.

This view translates the agreed [match flow](https://github.com/Fusion2k/smash-fight/issues/4), [combat scope](https://github.com/Fusion2k/smash-fight/issues/2), and confirmed [arena direction](https://github.com/Fusion2k/smash-fight/issues/3) into a scene-composition candidate. It does not settle where gameplay state or physics processing lives.

## Composition candidate

Solid lines show proposed parent/child composition. Dashed lines show phase-dependent views: the diagram does not require every menu and match view to remain loaded at once. Every node is currently proposed.

```mermaid
flowchart TB
    App["Application root<br/>Active flow and view composition"]

    subgraph Frontend["Frontend views · active as needed"]
        direction LR
        Join["Join and character select<br/>Slots, picks, ready status"]
        Results["Results<br/>Winner or draw, rematch readiness"]
        Dev["Developer Test entry<br/>Keyboard plus stationary opponent"]
    end

    subgraph Gameplay["Match scene · proposed"]
        direction TB
        Match["Match root<br/>Compose one match"]
        Arena["Arena scene<br/>Surfaces, spawn markers, ring-out limits"]
        Characters["Character instances<br/>One independent instance per player slot"]
        HUD["Match HUD<br/>Player markers, damage, stocks"]
        Overlay["Pause and countdown overlay<br/>Missing-controller and resume feedback"]
        Match --> Arena
        Match --> Characters
        Match --> HUD
        Match --> Overlay
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

## Responsibilities to settle

| Scene role | Requirement it must support | Implementation status |
| --- | --- | --- |
| Application/frontend | Join, independent selection, readiness, results, and Developer Test entry | Proposed; no scene path yet |
| Match composition | Complete restartable matches, pause, controller loss, and same-step outcomes | Proposed; state ownership pending #8 |
| Arena | Main surface, two one-way platforms reachable by both characters' jumps, fixed view, safe starts, respawn positions, and ring-out limits | Topology and recovery expectations agreed in #3; dimensions and scene layout pending |
| Character instance | Independent movement, damage, attack state, and airborne resources for every player slot | Authoring agreed in #7 and timing evidence completed in #11; production script/module composition pending #8 |
| HUD/presentation | Distinguishable players, damage/stocks, attack phases, and hit feedback | Requirement agreed; scene paths pending |
| Pause/countdown presentation | Frozen match state, explicit missing-slot replacement, and three-second resume countdown | Behavior agreed in #4; scene ownership pending #8 |

Controller assignment, character-file validation, combat resolution, and match rules need explicit module responsibilities in #8. Their logical roles do not each require a separate node or scene. Likewise, this diagram does not prescribe autoloads, signals, inheritance, collision-node types, or a hit-query method.

[ADR 0002](../adr/0002-physics-json-and-editor-authored-geometry.md) fixes the authoring split: character physics tuning and attack damage come from JSON referenced by editor-authored character content. Geometry, attack timing, and launch direction/strength are edited in Godot. Production hit/hurt shapes must use that editor-authored source instead of duplicating dimensions in JSON. See [character authoring](character-authoring.md) for the accepted schema and reference workflow. The #11 lab's constant rectangle fixtures are experimental inputs, not a character-file schema.

## Physics backend status

[Research #12](https://github.com/Fusion2k/smash-fight/issues/12) evaluated GodotPhysics2D and Godot Rapier 2D before the timing experiment in #11. Its [cited report](https://github.com/Fusion2k/smash-fight/blob/1fb7589/docs/research/physics-backend-evaluation.md) recommends GodotPhysics2D as the initial baseline and retains Rapier v0.36.1 as a credible alternative if a relevant problem is demonstrated. Box2D is deferred at the user's request. No backend switch has been made, and this scene map does not assume one. The current `project.godot` has no custom 2D-backend selection; its Jolt setting is specifically `3d/physics_engine`.

Backend compatibility and packaging evidence will inform #8 and #9. The initial GodotPhysics2D fixtures now record short-window hits, query-freshness differences, one-way-platform movement, and simultaneous outcomes as described below. The user reported "prototype looks good" after reviewing the lab. Production gameplay coverage, other backends, and target-platform verification remain outstanding.

## Implemented #11 timing lab

This hierarchy exists on [prototype/combat-timing at 3820f96](https://github.com/Fusion2k/smash-fight/tree/3820f96). Read the [experiment instructions](https://github.com/Fusion2k/smash-fight/blob/3820f96/prototype/README.md) and [measured evidence](combat-timing-evidence.md). It is separate from the proposed production composition above.

```mermaid
flowchart TB
    Lab["CombatTimingLab · Node2D<br/>prototype/timing_lab.tscn<br/>prototype/timing_lab.gd"]
    UI["Status label and scenario/replay buttons<br/>Created at runtime"]
    Measures["Measurements · Node2D<br/>prototype/measurements.gd"]
    Area["MeasuredAttackArea · Area2D<br/>64 × 38 rectangle"]
    Targets["Target0..2 · CharacterBody2D<br/>28 × 50 rectangles"]
    Platform["OneWayPlatform · StaticBody2D<br/>220 × 12 one-way rectangle"]
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

These are review questions for #8, not claims that the candidate architecture has passed them. Replace this candidate with the agreed scene tree, actual paths, and interfaces as those decisions and implementation land.
