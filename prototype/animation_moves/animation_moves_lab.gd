extends Control
## PROTOTYPE ONLY — interactive shell. The liftable logic is move_sampler.gd.
## Question: can one Godot Animation timeline author a Move's timing, hitbox
## extent, hurtbox extent and state, while the simulation stays authoritative?

const LIBRARY_PATH := "res://prototype/animation_moves/move_library.tres"
const Sampler = preload("res://prototype/animation_moves/move_sampler.gd")
const HitDetection = preload("res://combat/hit_detection.gd")
const GeometryView = preload("res://prototype/animation_moves/geometry_view.gd")

var _sampler
var _step := 0
var _contact_steps: Array[int] = []
var _state_label: Label
var _geometry: Control
var _player: AnimationPlayer

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "ANIMATION-TIMELINE MOVES — PROTOTYPE"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)

	var question := Label.new()
	question.text = "Can one Godot Animation timeline hold a Move's timing, hitbox and hurtbox extents, and state — while a frame-step simulation remains the authority? The blue box is the hitbox; green is the hurtbox. Orange dot = a real contact from the production swept-rectangle detector."
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.custom_minimum_size.y = 52
	column.add_child(question)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 430
	column.add_child(split)

	_state_label = Label.new()
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state_label.custom_minimum_size = Vector2(400, 240)
	split.add_child(_state_label)

	_geometry = GeometryView.new()
	_geometry.custom_minimum_size = Vector2(360, 240)
	split.add_child(_geometry)

	var free := Label.new()
	free.text = "FREE PLAY — any order"
	column.add_child(free)
	var free_buttons := HFlowContainer.new()
	column.add_child(free_buttons)
	_button(free_buttons, "Step", _advance_one)
	_button(free_buttons, "Run to end", _run_to_end)
	_button(free_buttons, "Reset", _reset)
	_button(free_buttons, "Move active start +1 step", func() -> void: _sampler.retime_active_start(1); _refresh())
	_button(free_buttons, "Grow punch x (step 5 -> 40)", func() -> void: _sampler.set_extent("hitbox_extent", 5, Vector2(40, 8)); _refresh())
	_button(free_buttons, "Shrink hurtbox (step 4 -> 10)", func() -> void: _sampler.set_extent("hurtbox_extent", 4, Vector2(10, 40)); _refresh())

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	_tutorial(tabs, "Retime", "Drag the whole active window one step later. Expect the first contact to move from step 5 to step 6 — phase, eligibility, geometry and markers must travel together.",
		[["Reset", _reset], ["Move active start +1 step", func() -> void: _sampler.retime_active_start(1); _refresh()], ["Run to end", _run_to_end]])
	_tutorial(tabs, "Grow / shrink", "The punch grows in x during the active window. The hurtbox can shrink in the same window. Watch the extents and rectangles change while the authored Resource stays put.",
		[["Reset", _reset], ["Grow punch", func() -> void: _sampler.set_extent("hitbox_extent", 5, Vector2(40, 8)); _refresh()], ["Run to end", _run_to_end], ["Shrink hurtbox", func() -> void: _sampler.set_extent("hurtbox_extent", 4, Vector2(10, 40)); _refresh()], ["Replay from step 4", func() -> void: _replay(4)]])
	_tutorial(tabs, "Two instances", "Instance A reads the current step; Instance B stays at step 0. Editing sampled values never writes into the shared authored Resource.",
		[["Reset", _reset], ["Shrink hurtbox", func() -> void: _sampler.set_extent("hurtbox_extent", 4, Vector2(10, 40)); _refresh()], ["Jump to step 5", func() -> void: _step = 5; _refresh()]])

	# The AnimationPlayer exists so the timeline can be opened and dragged in
	# the Godot editor. It is set to MANUAL: the simulation never plays it.
	var sample_node := Node.new()
	sample_node.name = "CombatSample"
	sample_node.set_script(load("res://prototype/animation_moves/combat_sample.gd"))
	add_child(sample_node)
	_player = AnimationPlayer.new()
	_player.name = "Timeline"
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(_player)
	_reset()

func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)

func _tutorial(tabs: TabContainer, name: String, description: String, steps: Array) -> void:
	var tab := VBoxContainer.new()
	tab.name = name
	tab.add_theme_constant_override("separation", 8)
	tabs.add_child(tab)
	var label := Label.new()
	label.text = description
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.y = 58
	tab.add_child(label)
	var buttons := HFlowContainer.new()
	tab.add_child(buttons)
	for entry in steps:
		_button(buttons, entry[0], entry[1])

func _reset() -> void:
	var library := ResourceLoader.load(LIBRARY_PATH, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP) as AnimationLibrary
	_sampler = Sampler.new(library.get_animation(&"punch"))
	if _player and _player.has_animation_library(&"moves"):
		_player.remove_animation_library(&"moves")
	_player.add_animation_library(&"moves", library)
	_player.assigned_animation = &"moves/punch"
	_step = 0
	_contact_steps.clear()
	_refresh()

func _advance_one() -> void:
	if _step > 13:
		return
	var sample: Dictionary = _sampler.sample(_step)
	var contacts: Array = _contacts(sample)
	if not contacts.is_empty():
		_contact_steps.append(_step)
	_step += 1
	_refresh()

func _run_to_end() -> void:
	while _step <= 13:
		_advance_one()

func _replay(from_step: int) -> void:
	_step = from_step
	_contact_steps.clear()
	_run_to_end()

func _refresh() -> void:
	var shown := mini(_step, 13)
	var sample: Dictionary = _sampler.sample(shown)
	var contacts: Array = _contacts(sample)
	var other: Dictionary = _sampler.sample(0)
	_state_label.text = "STEP %d / 13   marker: %s\nphase: %s   hitbox active: %s\n\nhitbox extent: %s   offset: %s\nhurtbox extent: %s   offset: %s\n\nInstance A (step %d) hurtbox: %s\nInstance B (step 0) hurtbox: %s\nAuthored hurtbox baseline: %s  (never mutated)\n\nContacts in steps: %s\nContact this step: %s" % [
		shown, sample["marker"], sample["phase_name"], str(sample["hitbox_active"]),
		str(sample["hitbox_extent"]), str(sample["hitbox_offset"]),
		str(sample["hurtbox_extent"]), str(sample["hurtbox_offset"]),
		shown, str(sample["hurtbox_extent"]), str(other["hurtbox_extent"]),
		str(_sampler.authored_baseline("hurtbox_extent")),
		str(_contact_steps), str(contacts.size())]
	_geometry.sample = sample
	_geometry.contact = not contacts.is_empty()
	_geometry.queue_redraw()

func _contacts(sample: Dictionary) -> Array:
	var hit_shape := RectangleShape2D.new()
	hit_shape.size = sample["hitbox_extent"]
	var hurt_shape := RectangleShape2D.new()
	hurt_shape.size = sample["hurtbox_extent"]
	var attack := {
		"combat": {
			"active": sample["hitbox_active"],
			"move": {
				"hitbox": hit_shape,
				"hitbox_offset": sample["hitbox_offset"],
				"launch_direction": Vector2(1, -0.5),
				"launch_strength": 260.0,
			},
			"targets": [],
			"attack_id": 1,
			"attack_damage": 4,
		},
		"slot_id": 1,
		"facing": 1,
		"from": {"origin": Vector2.ZERO},
		"velocity": Vector2.ZERO,
		"start": 0.0,
	}
	var target := {
		"slot_id": 2,
		"combat": {"active": false, "vulnerable": true},
		"geometry": {
			"Hurtboxes/Body": {
				"shape": hurt_shape,
				"offset": sample["hurtbox_offset"],
			},
		},
		"from": {"origin": Vector2(40, 0)},
		"velocity": Vector2.ZERO,
	}
	var result := HitDetection.next_contacts([attack, target], Sampler.STEP_SECONDS)
	return result.get("contacts", [])
