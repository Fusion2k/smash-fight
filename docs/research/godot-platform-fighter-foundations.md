# Godot foundations for a local platform fighter

Research for [Research Godot foundations for a local platform fighter](https://github.com/Fusion2k/smash-fight/issues/5), supporting [Scope the first playable Smash Fight](https://github.com/Fusion2k/smash-fight/issues/1). Investigated 2026-11-15. This note records capabilities and options; it selects no architecture, data format, or gameplay rules.

## Version and evidence boundary

Locally executed `C:\tools\Godot4\Godot_v4.7.2-stable_win64_console.exe --version`; output was `4.7.2.stable.official.ed1daf0bf`. The repository's `project.godot` declares the 4.7 feature level. This verifies binary identity, not controller behavior or game correctness. Official [4.7.2 version source](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/version.py) declares major 4, minor 7, patch 2, stable, and documentation series `4.7`. The [official archive](https://godotengine.org/download/archive/) lists 4.7.2 stable on 2026-08-18.

Sources below explicitly identify either the **4.7 documentation series** or **4.7.2-tagged source**. Series pages can receive later edits; they are not patch-frozen evidence. No 4.8/latest guidance is used as a 4.7.2 guarantee. This was source research plus a binary version check, not a gameplay prototype, exported-build test, or physical gamepad test.

## Scene composition, communication, and ownership

**Fact, 4.7 docs:** `PackedScene.instantiate()` creates a scene instance; add it to a parent with `add_child()`. Packing saves the root and nodes it owns. [`PackedScene`](https://docs.godotengine.org/en/4.7/classes/class_packedscene.html)

**Fact, 4.7 docs:** node parentage determines the tree/lifetime relationship: freeing a node frees its children. `Node.owner` is an ancestor reference used for scene persistence, distinct from assigning a fighter to a local player. Physics callbacks have a separately configurable processing priority. [`Node`](https://docs.godotengine.org/en/4.7/classes/class_node.html#class-node-property-owner)

**Guidance, 4.7 docs:** self-contained scenes avoid brittle external node paths; a parent can supply dependencies and connect a child's signals. These are engine documentation recommendations, not mandatory architecture. [Scene organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/scene_organization.html)

**Options/inference:** a reusable fighter scene could receive its character definition and local input source when instantiated. Separate stage and HUD scenes could respond through explicit methods/signals. Alternatively, a match coordinator can run shared combat updates. Engine support does not decide which object owns damage, stocks, respawn, hit resolution, or the order of simultaneous hits. Keep those choices explicit; `Node.owner` does not implement them. Two instances of the same character are possible without authoring duplicate scenes; definition sharing requires the state precautions below.

## Movement, collision, and combat detection

**Fact, 4.7 docs:** `CharacterBody2D` is script-controlled, rather than automatically driven by physics forces. It supplies floor/wall/slope collision handling. Its `velocity` is pixels/second; `move_and_slide()` consumes the physics delta itself, may alter velocity on collision, and belongs in `_physics_process()`. Do not multiply the velocity passed to it by delta. Moving-platform velocity can be added automatically. [`CharacterBody2D`](https://docs.godotengine.org/en/4.7/classes/class_characterbody2d.html)

**Fact, 4.7 docs:** collision layers describe membership and masks describe what to detect. Collision objects support multiple shapes; collisions across different canvases are undefined. [`CollisionObject2D`](https://docs.godotengine.org/en/4.7/classes/class_collisionobject2d.html)

**Fact, 4.7 docs:** `Area2D` detects area/body overlaps through shapes and signals. Its overlap lists update during physics processing, not immediately after a transform changes. [`Area2D`](https://docs.godotengine.org/en/4.7/classes/class_area2d.html#class-area2d-method-get-overlapping-areas)

**Options/inference:** movement collision can use a character body while attack/hurt regions use areas. Percent damage, knockback curves, hitstun, stock loss, blast zones, and respawn are game rules that must be written above those primitives. A knockback value can influence scripted velocity, but the engine does not supply this game's formula. High-speed attacks or a hitbox enabled and disabled within one physics step need a prototype: overlap timing alone does not establish reliable hit detection. Layer/mask policy and deduplication of one attack hitting the same target repeatedly remain choices.

## Fixed-step timing and responsiveness

**Fact, 4.7 docs:** `Engine.physics_ticks_per_second` defaults to 60 and controls fixed physics iterations. `max_physics_steps_per_frame` defaults to 8; insufficient rendering throughput can slow simulated time even when delta is used. Increasing the physics rate costs CPU and may require changing the step limit. [`Engine`](https://docs.godotengine.org/en/4.7/classes/class_engine.html#class-engine-property-physics-ticks-per-second)

**Fact, 4.7 docs:** timers can process in physics or rendered-frame callbacks; they process at most once per applicable frame. The documentation warns about inconsistent very short waits (roughly below 0.05 seconds), and timers are affected by time scale. [`Timer`](https://docs.godotengine.org/en/4.7/classes/class_timer.html#class-timer-property-wait-time)

**Options/inference:** integer physics-tick counters are viable for attack startup/active/recovery and hitstun; elapsed seconds are also viable if rounding and boundaries are defined. A nominal 60-Hz gameplay tick is not proof of deterministic replay or fixed wall-clock latency. Buffering button edges into the next simulation step can preserve short taps; the implementation must define press/release consumption and update order. Tick rate, hitstop behavior, pause semantics, and input-buffer length need human choices and a feel test.

## Local gamepads, four players, and keyboard tests

**Fact, exact 4.7.2 source:** `Input.get_connected_joypads()` enumerates devices; `get_joy_axis(device, axis)` and `is_joy_button_pressed(device, button)` read a specific device. `joy_connection_changed(device, connected)` reports hotplug. Global action polling reflects global input state even after UI event consumption. [`Input.xml` at 4.7.2](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/Input.xml)

**Fact, 4.7 docs:** `InputEvent.device` identifies the originating device. [`InputEvent`](https://docs.godotengine.org/en/4.7/classes/class_inputevent.html#class-inputevent-property-device) `InputMap` supports runtime action/event registration and action deadzones. [`InputMap`](https://docs.godotengine.org/en/4.7/classes/class_inputmap.html)

**Options/inference:** either route events by device into player slots, or create separate per-player action sets with explicit device bindings. Reusing one global action set for every fighter does not by itself isolate players. A keyboard mapping can feed the same gameplay command representation for quick tests. Slot assignment, keyboard participation, deadzones, reconnect/rejoin behavior, and whether a disconnect pauses the match are game policy. On disconnection, explicitly clear held commands to avoid a stuck movement/attack state. Do not assume connected IDs are a permanent player identity or always a contiguous 0..3 sequence.

**Version uncertainty, not a proven four-device failure:** the [4.7 controller guide](https://docs.godotengine.org/en/4.7/tutorials/inputs/controllers_gamepads_joysticks.html) says Windows/macOS/Linux use SDL3 since 4.5, yet its troubleshooting section says Windows is limited to four controllers through XInput. Exact [4.7.2 input header](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/core/input/input.h) reserves 16 joypad slots, and its [SDL driver](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/drivers/sdl/joypad_sdl.cpp) initializes SDL joystick/gamepad support. The documentation's broad Windows limit and the implementation capacity should not be conflated. Four local slots fit either stated capacity, but compatibility, transport, mappings, and simultaneous use of the actual four devices remain unverified. Physical tests should cover mixed controllers, simultaneous held inputs, unplug/replug, focus loss, and transition from two to four players.

## One editable file per character: viable options

All three options below can concentrate scalar stats and move parameters in one authoring file while shared code supplies behavior. That is an application design possibility, not a Godot-enforced schema. Asset references can point outside the file; whether “one file” also means embedded art/animation is unresolved.

| Option | Verified support | Cost or limitation to decide |
| --- | --- | --- |
| Custom `Resource` stored as text `.tres` | Godot supports custom resources with exported fields and native serialization/editor editing. [Resources, 4.7 docs](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html) | Native typed/editor workflow; raw syntax includes engine/script/resource references. Engine load errors do not replace gameplay validation. |
| JSON, loaded as text and parsed | `JSON.parse()` returns an error; `get_error_line()` and `get_error_message()` give useful syntax diagnostics. `parse_string()` returns null on failure without the same error handling. Objects become dictionaries. [JSON, 4.7 docs](https://docs.godotengine.org/en/4.7/classes/class_json.html) | Explicit schema/type/range validation and conversion of vectors/references are application work. Godot's parser accepts some nonstandard JSON forms, so external strict parsers may disagree. |
| INI-style `ConfigFile` | Sections/keys hold Godot Variant values; `load()`/`parse()` return `Error`, and keys/sections can be enumerated. [ConfigFile, exact 4.7.2 source](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/ConfigFile.xml) | Convenient grouped stats with native value types; not a generic JSON interchange format. Public API lacks JSON's structured error-line/message accessors. Application schema validation is still needed. |

**Export constraint, 4.7 docs:** non-resource files such as JSON/text require export inclusion filters. Editing data in a source checkout is a different workflow from modifying data beside an exported game; the latter needs an explicit external file location/loading policy. [Exporting projects](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html#resource-options)

## Definition versus per-match state

**Fact, exact 4.7.2 source:** loaded resources are cached by path and later loads can return the same reference. `resource_local_to_scene` duplicates a resource during scene instantiation, not retroactively. `duplicate(false)` shares nested arrays/dictionaries/resources; `duplicate(true)` recursively copies collections but only duplicates local resources by default. `duplicate_deep()` offers subresource policy control. [`Resource.xml` at 4.7.2](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/Resource.xml)

**Options/inference:** share a definition treated as read-only and construct fresh mutable match/fighter state, or deliberately duplicate a mutable instance with a documented deep-copy policy. A fresh fighter scene alone does not guarantee every referenced resource is private. Definition fields could include movement constants and move data; current percent, stocks, velocity, timers, active attacks, and held input belong to runtime state. This separation is equally relevant when JSON/config dictionaries are assigned to multiple fighters. A meaningful isolation check uses two fighters of the same character, damages one, respawns/restarts, and verifies the other fighter and original definition remain unchanged.

## Useful character-file errors and remaining decisions

**Application-level validation option:** distinguish open/read failure, syntax failure, schema failure, and invalid asset references. Report file path plus JSON line/message when available; report field paths for semantic errors, e.g. `characters/example.json: moves.jab.active_ticks: expected integer >= 1, received -2`. Validate required/unknown keys, types, finite numeric values, ranges/units, move identifiers, cross-field timing, and referenced resources before spawning. Return all useful semantic errors together; do not silently substitute defaults for malformed required stats. These are proposed validator behaviors, not capabilities supplied automatically by a file format.

The human decisions still open are authoring format/editor preference; stat and move schema; units and tick convention; definition/state ownership; combat update order and simultaneous hits; device-to-slot/reconnect policy; and whether character editing must work after export. The next evidence needed is a small movement/hit-timing test, a same-character state-isolation test, an invalid-file diagnostic test, and a Windows four-controller smoke test. Research establishes available mechanisms, not their game feel or the final design.
