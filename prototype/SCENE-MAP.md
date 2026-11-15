# Implemented experiment scene map

This is the actual scene composition of the throwaway #11 lab. It is separate from the proposed production scene tree in the main architecture documents.

```mermaid
flowchart TB
    Root["CombatTimingLab · Node2D<br/>prototype/timing_lab.tscn<br/>prototype/timing_lab.gd"]
    Status["Status · Label"]
    Scenarios["Scenario buttons · Button instances"]
    Replay["Replay / pause / step · Button instances"]
    Measurements["Measurements · Node2D<br/>prototype/measurements.gd"]
    Area["MeasuredAttackArea · Area2D"]
    Targets["Target0..2 · CharacterBody2D<br/>Created per collision fixture"]
    Platform["OneWayPlatform · StaticBody2D<br/>Created for platform fixture"]
    Characters["PlatformCharacter / OtherCharacter<br/>CharacterBody2D"]
    AttackShape["CollisionShape2D<br/>64 × 38 rectangle"]
    BodyShape["CollisionShape2D per target<br/>28 × 50 shared rectangle definition"]
    PlatformShape["CollisionShape2D<br/>220 × 12 one-way rectangle"]
    CharacterShapes["CollisionShape2D per character"]
    Root --> Status
    Root --> Scenarios
    Root --> Replay
    Root --> Measurements
    Measurements --> Area
    Measurements -.-> Targets
    Measurements -.-> Platform
    Measurements -.-> Characters
    Area --> AttackShape
    Targets --> BodyShape
    Platform --> PlatformShape
    Characters --> CharacterShapes
    classDef root fill:#164e63,color:#ffffff,stroke:#22d3ee,stroke-width:2px;
    classDef measure fill:#dcfce7,color:#14532d,stroke:#22c55e;
    classDef ui fill:#dbeafe,color:#1e3a8a,stroke:#3b82f6;
    classDef physics fill:#fef3c7,color:#78350f,stroke:#f59e0b;
    class Root root;
    class Measurements measure;
    class Status,Scenarios,Replay ui;
    class Area,Targets,Platform,Characters,AttackShape,BodyShape,PlatformShape,CharacterShapes physics;
```

Solid edges show parent/child composition; dashed edges indicate fixture-dependent children. Scripts create the controls and physics fixtures at runtime. The root draws the replay from measured traces, not from those fixtures' current post-measurement positions. Shape resources are constant definitions; target bodies and measurement ledgers are separate runtime state.

The experiment deliberately uses two scripts without defining production gameplay interfaces. Its fixtures and UI should remain disposable. The next architecture decision uses the observed timing behavior to select real module responsibilities and interfaces.
