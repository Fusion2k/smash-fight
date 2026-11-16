# Character authoring

**Status: accepted specification from [#7](https://github.com/Fusion2k/smash-fight/issues/7).** The user confirmed the complete schema, validation rules, and shared understanding. The production Resources, catalog, authored Zip/Bramble pairs and content snapshot checks are implemented in #15. See the concrete authoring interface below; shared Character movement is implemented in #16; Match/combat behavior and hardware acceptance remain upcoming.

## Authoring responsibilities

| Source | Owns |
| --- | --- |
| One JSON file per character | Movement/body physics, relative mass, recovery movement, per-attack damage, and `schema_version` |
| Godot editor | Character identity/display name, art and animation, hitboxes/hurtboxes, dimensions/offsets, attack phase timing, and attack launch direction/strength |
| Shared game settings/rules | Stocks, match conditions, common input/buffer/grace/pause rules, and other settings that are not character-specific |
| Runtime state | Current damage/stocks, velocity, attack progress, hit history, airborne resources, and held input; never written back into authored definitions |

Attack damage is explicitly in JSON. Attack launch parameters stay in the editor under the user's clarification even though they affect motion. Recovery boost speeds are general character physics in JSON. Do not duplicate a property between the two sources.

The editor-authored character definition references its JSON file while working in Godot. The Inspector should expose that file reference, preferably with a JSON file picker. Identity, display names, artwork, asset references, and collision geometry do not move into JSON. #15 implements this with `CharacterDefinition.tuning_path` and `@export_file("*.json")`.

## Schema version 1

Every listed leaf is required; unknown keys are errors, so misspellings and accidentally stored geometry are detected. No silent physics/damage defaults are substituted. Values are finite JSON numbers, excluding booleans; only `schema_version` must be an integer exactly equal to `1`.

Speeds use world units/second, accelerations use world units/second squared, and mass is a positive relative value with `1.0` as the baseline. World units describe movement, not TV pixels or a graphics-size setting. Jump speeds are positive upward magnitudes; gravity and falling speeds are positive downward magnitudes. Multipliers are dimensionless. Attack damage is a nonnegative increase in accumulated damage, in percentage points.

| JSON field | Meaning | Range |
| --- | --- | --- |
| `schema_version` | Authoring format version | Integer `1` |
| `mass` | Relative resistance to knockback | Greater than zero |
| `movement.ground_speed` | Maximum ordinary horizontal ground speed | Greater than zero |
| `movement.ground_acceleration` | Acceleration toward requested ground movement | Nonnegative |
| `movement.ground_deceleration` | Ground slowdown when movement input is released | Nonnegative |
| `movement.ground_attack_speed_multiplier` | Ground speed multiplier during committed ordinary attacks | At least zero, less than one |
| `movement.air_speed` | Maximum ordinary horizontal air speed | Greater than zero |
| `movement.air_acceleration` | Horizontal air-control acceleration | Nonnegative |
| `jumping.ground_jump_speed` | Ground-jump takeoff speed | Greater than zero |
| `jumping.air_jump_speed` | Air-jump takeoff speed | Greater than zero |
| `jumping.jump_release_multiplier` | Remaining upward speed after early ground-jump release | At least zero, less than one |
| `falling.gravity` | Downward acceleration | Greater than zero |
| `falling.max_fall_speed` | Ordinary downward speed limit | Greater than zero |
| `falling.fast_fall_speed` | Fast-fall downward speed | Greater than `max_fall_speed` |
| `recovery.up_speed` | Recovery-special upward boost speed | Greater than zero |
| `recovery.air_speed` | Horizontal steering speed limit after recovery-special use | Nonnegative |
| `attack_damage.<move_id>` | Damage added by the corresponding move | Nonnegative |

The exact required move keys are `ground_neutral`, `ground_up`, `ground_down`, `aerial_neutral`, `aerial_up`, `aerial_down`, and `recovery_special`. Editor-authored moves use the same keys to obtain damage. These keys are shared move vocabulary; character display names and character IDs remain editor-authored.

### Illustrative character JSON

These values are provisional examples of Zip's direction, not approved balance or a passed gameplay test. Bramble uses the same schema with different values and its own editor-authored content.

```json
{
  "schema_version": 1,
  "mass": 0.8,
  "movement": {
    "ground_speed": 320,
    "ground_acceleration": 2200,
    "ground_deceleration": 2600,
    "ground_attack_speed_multiplier": 0.25,
    "air_speed": 300,
    "air_acceleration": 1600
  },
  "jumping": {
    "ground_jump_speed": 650,
    "air_jump_speed": 600,
    "jump_release_multiplier": 0.45
  },
  "falling": {
    "gravity": 1800,
    "max_fall_speed": 900,
    "fast_fall_speed": 1400
  },
  "recovery": {
    "up_speed": 800,
    "air_speed": 180
  },
  "attack_damage": {
    "ground_neutral": 4,
    "ground_up": 5,
    "ground_down": 4,
    "aerial_neutral": 4,
    "aerial_up": 5,
    "aerial_down": 6,
    "recovery_special": 5
  }
}
```

## Validation and loading contract

Validate the referenced JSON and editor-authored character content together before allowing that character into a match. Check missing/unreadable files, JSON syntax, root/object structure, required/unknown fields, version, numeric types/ranges, all seven move keys, and matching editor move definitions. Editor content supplies the graphics-dependent data JSON intentionally excludes. Timing still honors #2's integer simulation steps and at-least-one-step active windows; how animation is kept in sync is #8's implementation responsibility.

Report useful semantic errors together using file and field paths, such as `zip.physics.json: attack_damage.ground_up: expected nonnegative number` or `zip.physics.json: movement.air_speeed: unknown field`. Include syntax line/message when available. Unsupported versions are errors; future migration is explicit. Keep invalid characters unavailable with an understandable error while the project remains open; never spawn fallback stats.

For each new match or Developer Test restart, load a fresh validated tuning snapshot so saved edits are visible. Keep the active match's snapshot stable. It can be shared read-only, but each character instance has fresh mutable state and its own per-attack hit history. #8 must enforce this without relying on a scene instance alone to make shared data private.

## Editing and extension walkthroughs

1. **Create Bramble:** create its editor-authored character content, create a separate JSON using the same schema, and assign that JSON reference in Godot. Keep the seven move keys consistent and validate the pair. Adjust physics/damage in JSON and geometry/timing/launch properties in the editor.
2. **Change damage:** edit one `attack_damage` value, save, then start a new match or restart Developer Test. The old match retains its original values.
3. **Change reach or animation:** edit the shape, offsets, pose, or timing in Godot. Do not add size/offset/timing fields to JSON.
4. **Introduce malformed data:** report file/field errors and make that character unavailable. Correct the file and retry selection/start; no editor restart should be required solely to reread JSON.
5. **Select Zip twice:** both instances use the same authored identity and tuning; damaging, attacking, spending a jump, or respawning one must not mutate the other instance or authored data.
6. **Add a new mechanic:** tuning existing movement/attacks needs data edits. A new rule/action outside the agreed lifecycle needs code and an explicit schema/editor-definition change when it introduces new authoring data; do not hide executable behavior in JSON.

First-playable editing is for a source checkout. Exported-game modding and live-match reload are deferred. JSON must be included in Windows/native-Linux exports and references validated in the eventual #9/#10 workflow. This document does not claim exported builds or these loader/validation/state-isolation checks have passed.

## Implemented authoring interface (#15)

Open `characters/zip/zip.tres` or `characters/bramble/bramble.tres` in the Inspector. Each CharacterDefinition references its same-directory `.tscn`, `.physics.json` and seven named move `.tres` files. The scenes provide original simple courier/guardian silhouettes; detailed animation, phase poses and player feedback remain #19. Values are provisional: Zip is lighter/faster with shorter melee regions and taller recovery; Bramble is heavier/slower with wider regions and stronger launches. These are authored differences, not a passed feel/reach gate.

`characters/character_catalog.gd` exposes `CharacterCatalog.new().prepare_match(definitions)`. Input is an ordered array of CharacterDefinition selections (repeated definitions are allowed). The result has `ok`, `characters` and `errors`. A failure returns no prepared characters, with aggregated file/field diagnostics across JSON, moves, scenes and selections. A corrected call rereads JSON from disk; no ResourceLoader cache controls tuning reload. The application must display the returned diagnostics and keep start unavailable; that UI belongs to #18.

Successful `characters` entries are PreparedCharacter snapshots with these read-only methods:

- `identity()` returns character ID and display name.
- `settings()` returns the schema-versioned physics/damage dictionary.
- `move(move_id)` returns hitbox/offset, integer phase lengths, normalized launch direction/strength and presentation pose name. Missing IDs return an empty dictionary; gameplay uses the seven validated IDs.
- `geometry()` returns scene-relative `SurfaceShape` and `Hurtboxes/<name>` entries, each containing `shape` and `offset`.
- `instantiate_scene()` returns a fresh CharacterBody2D with detached native shape Resources.

All dictionary getters return detached containers, and shape getters explicitly duplicate native Resources. The catalog packs a private scene snapshot with copied shapes. Changes to the authored scene/moves or a getter result cannot alter an existing snapshot. Underscore storage is private by convention in GDScript; callers use the methods above and must never edit it. Prepared data contains no damage, velocity, action state or hit history: #16 allocates independent movement/resource state for every Character; #17 completes action/history state. These content checks do not establish full A2 gameplay isolation.

Scene contract: identity root transform, CharacterBody2D root, direct `SurfaceShape: CollisionShape2D`, and a nonempty `Hurtboxes` container with CollisionShape2D children. Native surface/combat rectangles require positive finite dimensions and enabled, translation-only transforms; offsets may vary. The root position belongs to Match. Each move has one positive finite RectangleShape2D, finite offset, nonnegative startup/recovery and at least one active simulation step, finite nonzero launch direction and positive launch strength. Integer Resource properties enforce whole-step authoring. Pose names are presentation references; animation never controls hit eligibility. JSON supplies exactly the existing schema and seven damage keys, with no editor data duplication.

Run `./tools/dev.ps1 check` to exercise both production interfaces and foundation settings. See [catalog evidence](../evidence/15-character-catalog.md) for scope, results and retained traces.
