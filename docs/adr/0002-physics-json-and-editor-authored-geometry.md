---
status: accepted
---

# Separate physics tuning from editor-authored character geometry

During [the character-authoring decision, #7](https://github.com/Fusion2k/smash-fight/issues/7), the user chose one JSON file per character for physics tuning such as speeds, accelerations, and mass, and explicitly included per-attack damage. Graphics-dependent properties, including hitboxes, dimensions, offsets, animation/attack timing, and attack launch direction/strength, stay editor-authored; the character content references its JSON from within Godot. This supersedes the initial all-stats-in-one-file direction: the split keeps animation and geometry with the graphics they must match instead of duplicating their authority in JSON, while numeric physics/damage tuning remains easy to edit. The [accepted schema and validation contract](../architecture/character-authoring.md) complete #7; scene/module interfaces and the concrete editor binding remain #8's responsibility.
