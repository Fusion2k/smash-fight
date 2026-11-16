extends SceneTree
## Bounded production flow/input/stock acceptance. No physical-device claim.
var failures := 0
var checks := 0
var app: SmashApplication

func _initialize() -> void:
	_run.call_deferred()

func expect(label: String, actual: Variant, expected: Variant) -> void:
	checks += 1
	print("CHECK %s expected=%s actual=%s" % [label, str(expected), str(actual)])
	if actual != expected:
		failures += 1
		push_error("Check failed: " + label)
		if app != null and app.game != null:
			print("FAILURE_TRACE ", var_to_str(app.game.view()))

func tick(samples: Dictionary = {}) -> void:
	var frames := app.advance(samples)
	var stepped := app.game.step(frames)
	if not stepped.ok:
		failures += 1
		print("INCOMPLETE_STEP ", var_to_str(stepped))

func _run() -> void:
	print("CONFIG application engine=", Engine.get_version_info().string, " physics=GodotPhysics2D steps=60 seed=none")
	_input()
	app = preload("res://app/app.tscn").instantiate() as SmashApplication
	app.automatic = false
	root.add_child(app)
	expect("join first Start", app.join(10), true)
	expect("one slot remains joining", app.phase, "join")
	expect("device cannot occupy two slots", app.join(10), false)
	expect("join second", app.join(20), true)
	expect("two slots select", app.phase, "select")
	expect("extra pad cannot steal", app.join(30), false)
	app.ready_slot(0)
	expect("individual readiness", [app.slots[0].ready, app.slots[1].ready], [true, false])
	app.choose(0, 1)
	expect("selection clears readiness", app.slots[0].ready, false)
	app.choose(0, 0)
	app.choose(1, 0)
	app.ready_slot(0)
	app.ready_slot(1)
	await physics_frame
	expect("both ready initial countdown", [app.phase, app.countdown], ["countdown", 180])
	expect("same character distinct instances", app.game.characters[0] != app.game.characters[1], true)
	for index in 35:
		tick()
	var interrupted := app.countdown
	app.controller_lost(20)
	var frozen := app.game.view()
	for index in 20:
		tick()
	expect("initial controller loss freezes match", app.game.view().step, frozen.step)
	expect("initial countdown saved", app.saved_countdown, interrupted)
	expect("unassigned replacement reclaims missing slot", app.join(30), true)
	expect("replacement preserves identity selection", [app.slots[1].id, app.slots[1].selection], [1, 0])
	expect("replacement does not resume", app.phase, "paused")
	app.resume()
	for index in 40:
		tick()
	app.controller_lost(30)
	expect("loss during resume pauses", app.phase, "paused")
	expect("original interrupted phase retained", app.saved_phase, "countdown")
	expect("same device may explicitly rebind", app.join(30), true)
	app.resume()
	for index in 179:
		tick()
	expect("resume countdown full three seconds", app.phase, "resume")
	tick()
	expect("resume restores initial phase", [app.phase, app.countdown], ["countdown", interrupted])
	for index in interrupted - 1:
		tick()
	expect("saved initial countdown not skipped", app.phase, "countdown")
	tick({10: {"jump": true, "attack": true}, 30: {}})
	expect("initial countdown reaches gameplay", app.phase, "playing")
	expect("held ready jump attack suppressed on start", [app.game.characters[0].view().move_id, app.game.characters[0].view().air_jump_available], ["", true])
	expect("extra device cannot join live", app.join(40), false)
	for index in 20:
		tick({10: {"jump": true, "attack": true}, 30: {}})
	expect("holding attack does not repeat", app.game.characters[0].view().move_id, "")
	tick({10: {}, 30: {}})
	tick({10: {"attack": true}, 30: {}})
	expect("fresh attack after release works", app.game.characters[0].view().committed, true)
	expect("same character action independent", app.game.characters[1].view().committed, false)
	app.game.characters[1].apply_event_group({"damage": 47.0, "hitstun": 20, "hit_pause": 3})
	app.game.characters[0].grant_protection(120)
	app.pause()
	frozen = app.game.view()
	for index in 10:
		tick({10: {}, 30: {}})
	expect("full pause freezes local hit pause", app.game.characters[1].view().hit_pause, 3)
	expect("full pause freezes protection", app.game.characters[0].view().protection, 120)
	expect("full pause freezes phase and damage", app.game.view().characters, frozen.characters)
	app.controller_lost(30)
	expect("connected slot cannot be stolen", app.join(10), false)
	expect("rebind new controller", app.join(40), true)
	expect("replacement damage retained", app.game.characters[1].view().damage, 47.0)
	app.resume()
	for index in 179:
		tick({10: {"attack": true, "jump": true}, 40: {}})
	expect("resume protection frozen until countdown ends", app.game.characters[0].view().protection, 120)
	tick({10: {"attack": true, "jump": true}, 40: {}})
	expect("resume returns gameplay", app.phase, "playing")
	expect("resume clears buffer and stale edges", app.game.characters[0].view().buffer_kind, "")
	app.pause()
	app.return_to_selection()
	expect("either player may return select", app.phase, "select")
	expect("selection clears all readiness", app.slots.any(func(slot: Dictionary) -> bool: return slot.ready), false)
	# Raw join/select/ready path, including keyboard+pad, uses the production parser.
	var mixed := preload("res://app/app.tscn").instantiate() as SmashApplication
	mixed.automatic = false
	root.add_child(mixed)
	mixed.advance({-1: {"start": true}, 8: {"start": true}})
	expect("raw keyboard plus gamepad joins normal selection", mixed.phase, "select")
	mixed.advance({-1: {}, 8: {}})
	mixed.advance({-1: {"x": 1.0}, 8: {}})
	expect("raw independent selection", [mixed.slots[0].selection, mixed.slots[1].selection], [1, 0])
	mixed.advance({-1: {"jump": true}, 8: {"jump": true}})
	expect("raw bottom face readiness starts", mixed.phase, "countdown")
	mixed.advance({-1: {}, 8: {"start": true}})
	expect("second player raw Start pauses", mixed.phase, "paused")
	mixed.advance({-1: {}, 8: {"special": true}})
	expect("second player raw top face reselects", mixed.phase, "select")
	for button in mixed.find_children("*", "Button", true, false):
		expect("mouse buttons do not consume gamepad acceptance", button.focus_mode, Control.FOCUS_NONE)
	mixed.free()
	await _stocks()
	await _ending()
	await _four()
	await _restart()
	app.free()
	app = null
	if failures == 0:
		print("CHECKS_PASSED application (%d checks)" % checks)
	quit(1 if failures else 0)

func _input() -> void:
	var input := PlayerInput.new()
	for x in [-1.0, -0.6, -0.2, -0.199, 0.0, 0.199, 0.2, 0.6, 1.0]:
		var frame := input.sample(1, {"x": x})
		var expected := signf(x) * maxf(0, (absf(x) - 0.2) / 0.8)
		expect("analog proportional x=" + str(x), is_equal_approx(frame.horizontal, expected), true)
	for item in [[0.499, "neutral", false], [0.5, "down", true], [1.0, "down", false], [0.3, "neutral", false], [0.5, "down", false], [0.299, "neutral", false], [0.5, "down", true], [-0.499, "neutral", false], [-0.5, "up", false]]:
		var frame := input.sample(1, {"y": item[0]})
		expect("direction threshold " + str(item[0]), [frame.attack_direction, frame.down_pressed], [item[1], item[2]])
	var held := {"jump": true, "attack": true, "special": true, "start": true, "y": 1.0}
	input.synchronize({2: held})
	var frame := input.sample(2, held)
	expect("synchronize suppresses every stale edge", [frame.jump_pressed, frame.attack_pressed, frame.special_pressed, frame.start_pressed, frame.down_pressed], [false, false, false, false, false])
	input.sample(2, {})
	frame = input.sample(2, held)
	expect("release enables all physical presses", [frame.jump_pressed, frame.attack_pressed, frame.special_pressed, frame.start_pressed], [true, true, true, true])
	expect("up stick never jumps", input.sample(3, {"y": -1.0}).jump_pressed, false)
	for key in [KEY_D, KEY_S, KEY_SPACE, KEY_J, KEY_K, KEY_ESCAPE]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = true
		Input.parse_input_event(event)
	Input.flush_buffered_events()
	var raw := input.read_device(PlayerInput.KEYBOARD)
	expect("physical keyboard mapping", [raw.x, raw.y, raw.jump, raw.attack, raw.special, raw.start], [1.0, 1.0, true, true, true, true])
	for key in [KEY_D, KEY_S, KEY_SPACE, KEY_J, KEY_K, KEY_ESCAPE]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = false
		Input.parse_input_event(event)
	for button in [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START]:
		var event := InputEventJoypadButton.new()
		event.device = 7
		event.button_index = button
		event.pressed = true
		Input.parse_input_event(event)
	Input.flush_buffered_events()
	raw = input.read_device(7)
	expect("logical Godot face-position mapping", [raw.jump, raw.attack, raw.special, raw.start], [true, true, true, true])
	for button in [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START]:
		var event := InputEventJoypadButton.new()
		event.device = 7
		event.button_index = button
		event.pressed = false
		Input.parse_input_event(event)

func _stocks() -> void:
	var prepared := app.catalog.prepare_match([app.DEFINITIONS[0], app.DEFINITIONS[0]])
	expect("stock match starts", app.game.start({"characters": prepared.characters}).ok, true)
	await physics_frame
	var body: Character = app.game.characters[0]
	body.apply_event_group({"damage": 80.0})
	body.global_position = Vector2(1500, 200)
	var result := app.game.step()
	expect("ringout step completes", result.ok, true)
	expect("ringout loses exactly one stock", app.game.view().stocks[0], 2)
	expect("ringout schedules sixty steps", app.game.view().respawns[0], 60)
	app.game.set_paused(true)
	for index in 60:
		app.game.step()
	expect("full pause freezes respawn", app.game.view().respawns[0], 60)
	app.game.set_paused(false)
	for index in 59:
		app.game.step()
	expect("no early respawn", app.game.view().removed.has(0), true)
	app.game.step()
	expect("one-second respawn restores live", app.game.view().removed.has(0), false)
	var state := body.view()
	expect("respawn zero damage fresh resources", [state.damage, state.air_jump_available, state.recovery_available, state.targets], [0.0, true, true, []])
	expect("respawn protection visible in view", state.protection > 0, true)
	expect("stock not consumed repeatedly", app.game.view().stocks[0], 2)
	body.grant_protection(120)
	for index in 119:
		app.game.step()
	expect("protection lasts first119 local steps", body.view().protection, 1)
	app.game.step()
	expect("protection expires on120", body.view().protection, 0)
	body.grant_protection(120)
	app.game.step({0: {"attack_pressed": true}})
	expect("attacking ends protection immediately", body.view().protection, 0)
	expect("attack committed on protected spawn", body.view().committed, true)

func _ending() -> void:
	var prepared := app.catalog.prepare_match(app.DEFINITIONS)
	app.game.start({"characters": prepared.characters, "stocks": 1, "positions": [Vector2(1450, 200), Vector2(1439, 200)]})
	await physics_frame
	app.game.characters[1].apply_event_group({"hitstun": 10, "velocity": Vector2(600, 0)})
	var result := app.game.step()
	expect("distinct-time final ringouts complete", result.ok, true)
	var rings: Array = result.events.filter(func(event: Dictionary) -> bool: return event.kind == "ring_out")
	expect("both ringouts collected", rings.size(), 2)
	if rings.size() == 2:
		expect("final ringouts are distinct contact times", rings[0].time != rings[1].time, true)
	expect("same-step finals draw", app.game.view().result, {"draw": true, "winner": -1})
	var before: int = app.game.view().step
	app.game.step()
	expect("finished match stops once", app.game.view().step, before)
	app.game.start({"characters": prepared.characters, "stocks": 1})
	await physics_frame
	app.game.characters[0].global_position = Vector2(1500, 200)
	app.game.step()
	expect("last survivor wins", app.game.view().result, {"draw": false, "winner": 1})
	app.phase = "playing"
	tick()
	expect("app consumes Match result", app.phase, "results")
	var selections: Array = app.slots.map(func(slot: Dictionary) -> int: return slot.selection)
	app.ready_slot(0)
	expect("rematch requires both ready", app.phase, "results")
	app.ready_slot(1)
	await physics_frame
	expect("rematch starts countdown", app.phase, "countdown")
	expect("rematch retains selections", app.slots.map(func(slot: Dictionary) -> int: return slot.selection), selections)
	expect("rematch resets stocks results damage", [app.game.view().stocks, app.game.view().result, app.game.characters[0].view().damage], [{0: 3, 1: 3}, {}, 0.0])

func _four() -> void:
	var four := preload("res://app/app.tscn").instantiate() as SmashApplication
	four.capacity = 4
	four.automatic = false
	root.add_child(four)
	for device in [1, 2, 3, 4]:
		expect("four-slot join " + str(device), four.join(device), true)
	four.controller_lost(2)
	expect("four-slot explicit replacement", four.join(9), true)
	expect("four-slot identity stable", four.slots.map(func(slot: Dictionary) -> int: return slot.id), [0, 1, 2, 3])
	var arena := preload("res://arenas/first_arena.tscn").instantiate()
	for container in ["Starts", "Respawns"]:
		for index in 2:
			var marker := Marker2D.new()
			marker.position = Vector2(550 + 100 * index, 200)
			arena.get_node(container).add_child(marker)
			marker.owner = arena
	var scene := PackedScene.new()
	scene.pack(arena)
	arena.free()
	var prepared := app.catalog.prepare_match([app.DEFINITIONS[0], app.DEFINITIONS[0], app.DEFINITIONS[0], app.DEFINITIONS[0]])
	expect("four real characters compose", four.game.start({"characters": prepared.characters, "slots": [0, 1, 2, 3], "arena_scene": scene, "stocks": 1}).ok, true)
	await physics_frame
	four.game.characters[0].apply_event_group({"damage": 23.0, "hit_pause": 3})
	var original := four.game.characters[0].global_position
	four.game.step({2: {"horizontal": 1.0}})
	expect("four local pause third player moves", four.game.characters[2].velocity.x > 0, true)
	expect("local pause preserves first position", four.game.characters[0].global_position, original)
	expect("four same-character damage independent", four.game.characters[2].view().damage, 0.0)
	for index in 3:
		four.game.characters[index].global_position = Vector2(1500, 200)
	four.game.step()
	expect("four stock winner not pair assumption", four.game.view().result, {"draw": false, "winner": 3})
	four.game.start({"characters": prepared.characters, "slots": [0, 1, 2, 3], "arena_scene": scene, "stocks": 1})
	await physics_frame
	for body in four.game.characters:
		body.global_position = Vector2(1500, 200)
	four.game.step()
	expect("four final-stock ringouts draw", four.game.view().result, {"draw": true, "winner": -1})
	four.free()

func _restart() -> void:
	var tuning_path := "user://app-restart.physics.json"
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(app.DEFINITIONS[0].tuning_path))
	var definition: CharacterDefinition = app.DEFINITIONS[0].duplicate(true)
	for index in definition.moves.size():
		definition.moves[index] = definition.moves[index].duplicate(true)
	definition.tuning_path = tuning_path
	var scene_path := "user://app-restart.tscn"
	var definition_path := "user://app-restart.tres"
	_save_scene(scene_path, 28)
	definition.character_scene = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	ResourceSaver.save(definition, definition_path)
	app.definitions = [ResourceLoader.load(definition_path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP), app.DEFINITIONS[1]]
	var file := FileAccess.open(tuning_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(source))
	file.close()
	app.start_developer_test()
	await physics_frame
	var active_mass: float = app.game.characters[0].prepared.settings().mass
	var active_width: float = app.game.characters[0].prepared.geometry()["SurfaceShape"].shape.size.x
	var active_startup: int = app.game.characters[0].prepared.move(&"ground_neutral").startup_steps
	definition.moves[0].startup_steps += 2
	ResourceSaver.save(definition, definition_path)
	_save_scene(scene_path, 38)
	expect("active prepared geometry survives saved scene edit", app.game.characters[0].prepared.geometry()["SurfaceShape"].shape.size.x, active_width)
	expect("active prepared move survives saved Resource edit", app.game.characters[0].prepared.move(&"ground_neutral").startup_steps, active_startup)
	source.mass = active_mass * 2
	source.attack_damage.ground_neutral += 5
	file = FileAccess.open(tuning_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(source))
	file.close()
	expect("active app match keeps prepared mass", app.game.characters[0].prepared.settings().mass, active_mass)
	expect("Developer Test uses same Match", [app.slots[0].device, app.slots[1].device, app.game.characters.size()], [-1, -2, 2])
	var first: Character = app.game.characters[0]
	first.apply_event_group({"damage": 50.0})
	app.start_developer_test()
	await physics_frame
	expect("app restart reloads saved scene geometry", app.game.characters[0].prepared.geometry()["SurfaceShape"].shape.size.x, 38.0)
	expect("app restart reloads saved move timing", app.game.characters[0].prepared.move(&"ground_neutral").startup_steps, active_startup + 2)
	expect("app restart reloads source JSON snapshot", app.game.characters[0].prepared.settings().mass, active_mass * 2)
	expect("other character snapshot unchanged", app.game.characters[1].prepared.settings().mass, app.catalog.prepare_match([app.DEFINITIONS[1]]).characters[0].settings().mass)
	expect("Developer restart replaces mutable character", app.game.characters[0] != first, true)
	expect("Developer restart clean damage stocks", [app.game.characters[0].view().damage, app.game.view().stocks[0]], [0.0, 3])
	for index in 180:
		tick()
	app.game.event_budget = 0
	var failed := app.game.step()
	expect("simulation exhaustion incomplete", [failed.ok, failed.completed], [false, false])
	app.advance({})
	expect("simulation failure understandable stopped state", app.phase, "error")
	app.game.event_budget = Match.EVENT_BUDGET
	app.return_to_selection()
	app.ready_slot(0)
	await physics_frame
	expect("Developer stationary opponent allows restart readiness", app.phase, "countdown")
	expect("restart clears failure", app.game.view().failed, false)
	file = FileAccess.open(tuning_path, FileAccess.WRITE)
	file.store_string("{invalid")
	file.close()
	app.start_developer_test()
	expect("invalid corrected content cannot start", app.phase, "select")
	expect("invalid character unavailable", app.available[0], false)
	file = FileAccess.open(tuning_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(source))
	file.close()
	app.retry_content()
	expect("correct retry available without editor restart", app.available[0], true)
	app.start_developer_test()
	expect("corrected content restarts same application", app.phase, "countdown")
	for path in [tuning_path, scene_path, definition_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _save_scene(path: String, width: float) -> void:
	var body := app.DEFINITIONS[0].character_scene.instantiate()
	PreparedCharacter.copy_scene_shapes(body)
	body.get_node("SurfaceShape").shape.size.x = width
	var packed := PackedScene.new()
	packed.pack(body)
	ResourceSaver.save(packed, path)
	body.free()
