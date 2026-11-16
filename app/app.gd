class_name SmashApplication
extends Node2D
## Slots survive controller loss. Match owns all gameplay state and its clock.
const DEFINITIONS := [preload("res://characters/zip/zip.tres"), preload("res://characters/bramble/bramble.tres")]
const COLORS := [Color("62d8ff"), Color("ff83ae"), Color("c1ef77"), Color("ffce66")]
var definitions: Array = DEFINITIONS.duplicate()
var controls := PlayerInput.new()
var catalog := CharacterCatalog.new()
var game: Match
var slots: Array = []
var capacity := 2
var automatic := true
var phase := "join"
var countdown := 0
var saved_phase := "playing"
var saved_countdown := 0
var developer := false
var diagnostics: Array = []
var available: Array = []
var _samples := {}
var _connected: Array = []
var _hud: Label
var _overlay: PanelContainer
var _title: Label
var _details: Label
var _buttons: VBoxContainer
var _player_labels: Array[Label] = []
var _verify_ticks := -1
var _capture_phase := ""
var _capture := ""
var _discard_edges := false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("111c30"))
	game = preload("res://match/match.tscn").instantiate() as Match
	add_child(game)
	game.input_provider = _poll
	game.automatic = automatic
	game.set_paused(true)
	_make_ui()
	retry_content()
	var args := OS.get_cmdline_user_args()
	if args.has("--developer-test"):
		start_developer_test()
	if args.has("--verify-quit"):
		_verify_ticks = 12
	for arg in args:
		if arg.begins_with("--verify-steps=") and _verify_ticks > 0:
			_verify_ticks = clampi(int(arg.trim_prefix("--verify-steps=")), 12, 1800)
		if arg.begins_with("--capture-phase="):
			_capture_phase = arg.trim_prefix("--capture-phase=")
		if arg.begins_with("--capture="):
			_capture = arg.trim_prefix("--capture=")

	if _verify_ticks > 0 and _capture_phase == "results":
		# Explicit bounded developer draw fixture, through the real Match.
		start_developer_test()
		var prepared := catalog.prepare_match(definitions)
		game.start({"characters": prepared.characters, "stocks": 1, "positions": [Vector2(1500, 200), Vector2(-200, 200)], "automatic": automatic})
		phase = "playing"
		game.set_paused(false)

func retry_content() -> void:
	available.clear()
	diagnostics.clear()
	for index in definitions.size():
		var definition: CharacterDefinition = definitions[index]
		var loaded := true
		if not definition.resource_path.is_empty():
			# Refresh saved editor Resources/dependencies too; prepared running data
			# has already detached settings, moves, geometry and scene shapes.
			var fresh := ResourceLoader.load(definition.resource_path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP) as CharacterDefinition
			loaded = fresh != null
			if loaded:
				definitions[index] = fresh
				definition = fresh
			else:
				diagnostics.append("Cannot load character file: " + definition.resource_path)
		var prepared := catalog.prepare_match([definition])
		available.append(loaded and prepared.ok)
		diagnostics.append_array(prepared.errors)

func join(device: int) -> bool:
	if device == PlayerInput.DUMMY or slots.any(func(slot: Dictionary) -> bool: return slot.device == device and slot.connected):
		return false
	for slot in slots:
		if not slot.connected:
			slot.device = device
			slot.connected = true
			_sync()
			return true
	if phase not in ["join", "select"] or slots.size() >= capacity:
		return false
	slots.append({"id": slots.size(), "device": device, "connected": true, "selection": 0, "ready": false})
	if slots.size() == capacity:
		phase = "select"
	return true

func controller_lost(device: int) -> void:
	for slot in slots:
		if slot.device == device and slot.connected:
			slot.connected = false
			if phase in ["playing", "countdown", "resume", "paused"]:
				pause()

func choose(slot_id: int, selection: int) -> void:
	if phase != "select" or selection < 0 or selection >= definitions.size():
		return
	for slot in slots:
		if slot.id == slot_id:
			slot.selection = selection
			slot.ready = false

func ready_slot(slot_id: int) -> void:
	if phase not in ["select", "results"]:
		return
	for slot in slots:
		if slot.id == slot_id and slot.connected:
			if phase == "select" and not available[slot.selection]:
				return
			slot.ready = not slot.ready
	if developer:
		for slot in slots:
			if slot.device == PlayerInput.DUMMY:
				slot.ready = true
	if slots.size() == capacity and slots.all(func(slot: Dictionary) -> bool: return slot.ready and slot.connected):
		_start_match()

func _start_match() -> void:
	retry_content()
	if slots.any(func(slot: Dictionary) -> bool: return not available[slot.selection]):
		phase = "select"
		for slot in slots:
			slot.ready = false
		return
	var selections: Array = slots.map(func(slot: Dictionary) -> CharacterDefinition: return definitions[slot.selection])
	var prepared := catalog.prepare_match(selections)
	if not prepared.ok:
		diagnostics = prepared.errors
		phase = "select"
		for slot in slots:
			slot.ready = false
		return
	var started := game.start({"characters": prepared.characters, "slots": slots.map(func(slot: Dictionary) -> int: return slot.id), "automatic": automatic})
	if not started.ok:
		_fail(started)
		return
	for slot in slots:
		slot.ready = false
	phase = "countdown"
	countdown = 180
	game.set_paused(true)
	_sync()

func start_developer_test() -> void:
	developer = true
	slots = [{"id": 0, "device": PlayerInput.KEYBOARD, "connected": true, "selection": 0, "ready": false},
		{"id": 1, "device": PlayerInput.DUMMY, "connected": true, "selection": 1, "ready": false}]
	_start_match()

func pause() -> void:
	if phase in ["playing", "countdown"]:
		saved_phase = phase
		saved_countdown = countdown
	if phase in ["playing", "countdown", "resume", "paused"]:
		phase = "paused"
		game.set_paused(true)

func resume() -> void:
	if phase != "paused" or not _all_connected():
		return
	phase = "resume"
	countdown = 180
	_sync()

func return_to_selection() -> void:
	if phase not in ["paused", "results", "error"]:
		return
	phase = "select"
	game.set_paused(true)
	for slot in slots:
		slot.ready = false
	retry_content()
	_sync()

func _all_connected() -> bool:
	return slots.size() == capacity and slots.all(func(slot: Dictionary) -> bool: return slot.connected)

func _sync() -> void:
	_discard_edges = true
	controls.synchronize(_samples)
	game.clear_inputs()

func _poll() -> Dictionary:
	var connected: Array = Input.get_connected_joypads()
	for device in _connected:
		if not connected.has(device):
			controller_lost(device)
	_connected = connected
	var samples := {PlayerInput.KEYBOARD: controls.read_device(PlayerInput.KEYBOARD)}
	for device in connected:
		samples[device] = controls.read_device(device)
	var frames := advance(samples)
	if _verify_ticks > 0:
		_verify_ticks -= 1
		if _verify_ticks == 0 and _capture_phase == "paused":
			pause()
	return frames

## One 60 Hz flow tick; fixtures supply raw device samples through the real adapter.
func advance(samples: Dictionary) -> Dictionary:
	_samples = samples.duplicate(true)
	var frames := {}
	for device in samples:
		frames[device] = controls.sample(device, samples[device])
	if phase == "playing":
		var state := game.view()
		if state.failed:
			_fail({"trace": state.trace})
		elif not state.result.is_empty():
			phase = "results"
			game.set_paused(true)
	for device in frames:
		var frame: Dictionary = frames[device]
		var owned := -1
		for index in slots.size():
			if slots[index].device == device and slots[index].connected:
				owned = index
		if owned < 0:
			if frame.start_pressed:
				join(device)
			continue
		var slot: Dictionary = slots[owned]
		match phase:
			"select":
				if frame.left_pressed or frame.right_pressed:
					choose(slot.id, (slot.selection + 1) % definitions.size())
				if frame.jump_pressed or frame.start_pressed:
					ready_slot(slot.id)
			"countdown", "playing":
				if frame.start_pressed:
					pause()
			"paused":
				if frame.special_pressed:
					return_to_selection()
				elif frame.start_pressed or frame.jump_pressed:
					resume()
			"results":
				if frame.special_pressed:
					return_to_selection()
				elif frame.jump_pressed or frame.start_pressed:
					ready_slot(slot.id)
			"error":
				if frame.start_pressed or frame.jump_pressed:
					return_to_selection()
	if phase in ["countdown", "resume"]:
		countdown -= 1
		if countdown <= 0:
			if phase == "resume":
				phase = saved_phase
				countdown = saved_countdown
			else:
				phase = "playing"
			_sync()
	var gameplay := {}
	if phase == "playing":
		for slot in slots:
			gameplay[slot.id] = frames.get(slot.device, {}).duplicate()
		# All transition ticks discard edges sampled before the resynchronization.
		if _discard_edges:
			for frame in gameplay.values():
				for action in ["jump", "attack", "special", "down"]:
					frame[action + "_pressed"] = false
			_discard_edges = false
	game.set_paused(phase != "playing")
	return gameplay

func _fail(details: Dictionary) -> void:
	phase = "error"
	game.set_paused(true)
	game.automatic = automatic
	diagnostics = ["The match stopped safely. Return to selection to start again."]
	# Bounded Match trace retained separately; it is not the player-facing HUD.
	var file := FileAccess.open("user://last-match-failure.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(details))

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(40, 20)
	_hud.add_theme_font_size_override("font_size", 23)
	layer.add_child(_hud)
	_overlay = PanelContainer.new()
	_overlay.position = Vector2(240, 145)
	_overlay.size = Vector2(800, 410)
	layer.add_child(_overlay)
	var margin := MarginContainer.new()
	for edge in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(edge, 24)
	_overlay.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 36)
	column.add_child(_title)
	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 21)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size = Vector2(730, 140)
	column.add_child(_details)
	_buttons = VBoxContainer.new()
	column.add_child(_buttons)
	_button("Developer Test - keyboard + stationary opponent", start_developer_test)
	_button("Join keyboard player (then Start on a gamepad)", func() -> void: join(PlayerInput.KEYBOARD))
	_button("Resume", resume)
	_button("Return to character select", return_to_selection)
	_button("Retry character files", retry_content)
	for index in capacity:
		var marker := Label.new()
		marker.add_theme_color_override("font_color", COLORS[index % COLORS.size()])
		marker.add_theme_font_size_override("font_size", 19)
		layer.add_child(marker)
		_player_labels.append(marker)

func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	_buttons.add_child(button)

func _process(_delta: float) -> void:
	if game == null:
		return
	_present()
	queue_redraw()
	if _verify_ticks == 0:
		_verify_ticks = -1
		var prepared := catalog.prepare_match(definitions)
		if not prepared.ok:
			push_error(str(prepared.errors))
			get_tree().quit(1)
			return
		for body in prepared.characters:
			print("APPLICATION_CONTENT ", body.identity().character_id)
		if not _capture.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_capture)
		print("APPLICATION_START_PASSED phase=%s exported=%s display=%s" % [phase, str(OS.has_feature("template")), DisplayServer.get_name()])
		get_tree().quit()

func _present() -> void:
	var state := game.view()
	var keyboard := slots.any(func(slot: Dictionary) -> bool: return slot.device == PlayerInput.KEYBOARD)
	var lines: Array[String] = []
	for index in slots.size():
		var slot: Dictionary = slots[index]
		var stock: int = state.stocks.get(slot.id, 3)
		var damage := 0.0
		var action := ""
		for body in state.characters:
			if body.slot_id == slot.id:
				damage = body.damage
				action = body.phase
		lines.append("P%d  %s  %.0f%%  |  %d stocks%s%s" % [slot.id + 1, definitions[slot.selection].display_name, damage, stock, "  READY" if slot.ready else "", "  Controller missing" if not slot.connected else ""])
		if index < _player_labels.size():
			var marker: Label = _player_labels[index]
			marker.visible = phase in ["playing", "countdown", "paused", "resume"] and not state.removed.has(slot.id)
			if index < game.characters.size():
				var body: Character = game.characters[index]
				var view := body.view()
				marker.position = body.global_position + Vector2(-36, -80)
				marker.text = "P%d%s" % [slot.id + 1, "  SAFE" if view.protection > 0 else ""]
				body.visible = marker.visible
				body.modulate = Color(1.8, 1.8, 1.8) if view.hit_pause > 0 else (Color(0.55, 0.85, 1.0, 0.6 + 0.4 * sin(view.protection)) if view.protection > 0 else Color.WHITE)
				if view.hitstun > 0:
					marker.text += "  LAUNCH"
				elif action != "idle":
					marker.text += "  " + action.to_upper()
	_hud.text = "SMASH FIGHT" + ("  /  DEVELOPER TEST" if developer else "") + "\n" + "\n".join(lines)
	_overlay.visible = phase != "playing"
	for index in _buttons.get_child_count():
		_buttons.get_child(index).visible = (phase == "join" and index <= 1) or (phase == "paused" and index in [2, 3]) or (phase in ["results", "error"] and index == 3) or (phase == "select" and index == 4)
	match phase:
		"join":
			_title.text = "Smash Fight"
			_details.text = "Two players. Three stocks. No time limit.\nPress Start on each gamepad to join.\nBottom face: jump / ready. Left face: attack. Top face: special."
		"select":
			_title.text = "Choose your character"
			_details.text = "Left / right: choose Zip or Bramble. Bottom face or Start: ready.\nKeyboard: A / D choose, Space ready.\n" + "\n".join(lines)
			if not diagnostics.is_empty():
				_details.text += "\nUnavailable character files: " + str(diagnostics[0]).left(180)
		"countdown", "resume":
			_title.text = ("Get ready!  " if phase == "countdown" else "Resuming in  ") + str(ceili(countdown / 60.0))
			_details.text = "Start pauses.\nKeyboard: WASD move, Space jump, J attack, K special, Esc pause." if keyboard else "Stick moves and aims attacks. Down drops through platforms.\nBottom face jumps. Left face attacks. Top face is recovery."
		"paused":
			_title.text = "Paused"
			_details.text = ("Press Start on an unassigned controller to replace the missing player.\n" if not _all_connected() else ("Space / Esc: resume after three seconds.\n" if keyboard else "Bottom face or Start: resume after three seconds.\n")) + ("K: return to character select.\n" if keyboard else "Top face: return to character select.\n") + "\n".join(lines)
		"results":
			_title.text = "Draw!" if state.result.get("draw", false) else "Player %d wins!" % (int(state.result.get("winner", 0)) + 1)
			_details.text = ("Space / Esc: ready for a rematch. K: return to character select.\n" if keyboard else "Bottom face or Start: ready for a rematch with the same characters.\nTop face: return to character select.\n") + "\n".join(lines)
		"error":
			_title.text = "Match stopped"
			_details.text = "The match paused after a problem. Return to character select and start again.\nA diagnostic was saved for the developer."

func _draw() -> void:
	if game == null or phase not in ["playing", "countdown", "paused", "resume"]:
		return
	var removed: Dictionary = game.view().removed
	for body in game.characters:
		var state := body.view()
		if removed.has(body.slot_id):
			continue
		var color: Color = COLORS[body.slot_id % COLORS.size()]
		if state.protection > 0:
			draw_arc(body.position, 46, 0, TAU, 40, color, 3)
		if state.phase == "active":
			var move := body.prepared.move(StringName(state.move_id))
			var size: Vector2 = move.hitbox.size
			var offset: Vector2 = move.hitbox_offset
			offset.x *= state.facing
			draw_rect(Rect2(body.position + offset - size / 2, size), Color(color, 0.25), true)
			draw_rect(Rect2(body.position + offset - size / 2, size), color, false, 2)
		if state.hitstun > 0:
			var launch: Vector2 = state.pending_launch if state.pending_launch != Vector2.ZERO else state.velocity
			draw_line(body.position, body.position + launch.normalized() * 65, color, 4)
