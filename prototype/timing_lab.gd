extends Node2D
## A recorded, slowed replay of real 60 Hz physics observations.

const Measurements = preload("res://prototype/measurements.gd")
const METHOD_COLORS = [Color("a5b4fc"), Color("c4b5fd"), Color("38bdf8"), Color("fbbf24"), Color("34d399")]
var results: Array = []
var metadata: Dictionary = {}
var selected := 0
var replay_tick := 0
var playing := true
var elapsed := 0.0
var font := ThemeDB.fallback_font
var status: Label
var lab: Node2D
var headless_measure := false
var snapshot_requested := false


func _ready() -> void:
	headless_measure = OS.get_cmdline_user_args().has("--measure")
	status = Label.new()
	status.position = Vector2(35,110)
	status.text = "Measuring actual Godot physics steps..."
	status.add_theme_font_size_override("font_size", 20)
	add_child(status)
	lab = Measurements.new()
	lab.name = "Measurements"
	lab.completed.connect(_completed)
	add_child(lab)


func _completed(observations: Array, environment: Dictionary) -> void:
	results = observations
	metadata = environment
	if headless_measure:
		var output := "res://prototype/observations.json"
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--output="):
				output = argument.trim_prefix("--output=")
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			push_error("Could not write measurement artifact: " + output)
			get_tree().quit(2)
			return
		file.store_string(JSON.stringify({"metadata": metadata, "cases": results}, "\t") + "\n")
		file.close()
		get_tree().quit(0 if metadata.all_checks_passed else 1)
		return
	status.text = "Measured at 60 Hz. Replay is slowed to 8 steps/sec; these are recorded observations."
	for i in range(results.size()):
		var button := Button.new()
		button.position = Vector2(25,160 + i*43)
		button.size = Vector2(300,36)
		button.text = "%d. %s" % [i+1, results[i].title]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_select.bind(i))
		add_child(button)
	var controls := [["Replay", _restart], ["Play / pause", _toggle], ["Step", _step]]
	for i in range(controls.size()):
		var button := Button.new()
		button.position = Vector2(355+i*155,705)
		button.size = Vector2(145,38)
		button.text = controls[i][0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(controls[i][1])
		add_child(button)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scenario="):
			selected = clampi(argument.trim_prefix("--scenario=").to_int()-1, 0, results.size()-1)
		elif argument.begins_with("--frame="):
			replay_tick = argument.trim_prefix("--frame=").to_int()
	replay_tick = clampi(replay_tick, 0, results[selected].trace.size()-1)
	queue_redraw()


func _select(index: int) -> void:
	selected = index
	_restart()


func _restart() -> void:
	replay_tick = 0
	elapsed = 0
	playing = true
	queue_redraw()


func _toggle() -> void:
	playing = not playing


func _step() -> void:
	playing = false
	_advance()


func _advance() -> void:
	if results.is_empty():
		return
	replay_tick = (replay_tick + 1) % results[selected].trace.size()
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_SPACE:
		_toggle()
	elif event.keycode == KEY_N:
		_step()
	elif event.keycode == KEY_R:
		_restart()
	elif event.keycode >= KEY_1 and event.keycode <= KEY_9 and not results.is_empty():
		_select(mini(event.keycode-KEY_1, results.size()-1))
	elif event.keycode == KEY_0 and results.size() >= 10:
		_select(9)
	elif event.keycode == KEY_MINUS and results.size() >= 11:
		_select(10)


func _process(delta: float) -> void:
	if results.is_empty() or not playing:
		return
	elapsed += delta
	if elapsed > 0.125:
		elapsed = 0
		_advance()


func _text(point: Vector2, value: String, size := 18, color := Color("cbd5e1")) -> void:
	for line in value.split("\n"):
		draw_string(font, point, line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		point.y += size+7


func _draw() -> void:
	_text(Vector2(30,48), "SMASH FIGHT / COMBAT TIMING LAB", 28, Color.WHITE)
	_text(Vector2(30,80), "THROWAWAY #11 EXPERIMENT  |  GodotPhysics2D  |  Not a playable match", 16, Color("fbbf24"))
	if results.is_empty():
		return
	var result: Dictionary = results[selected]
	var frame: Dictionary = result.trace[replay_tick]
	draw_style_box(_panel(), Rect2(345,155,805,525))
	_text(Vector2(365,190), result.title, 24, Color.WHITE)
	_text(Vector2(365,220), result.explanation, 15)
	_text(Vector2(365,250), "Recorded step %d / %d%s" % [frame.tick, result.trace[-1].tick,
		"   Engine frame %d" % frame.engine_frame if frame.has("engine_frame") else ""], 17)
	if result.has("rose_through"):
		_draw_platform(result, frame)
	elif result.trade:
		_draw_trade(result)
	else:
		_draw_collision(result, frame)
	_text(Vector2(30,710), "1-9 / 0 / - select\nSpace pause\nN step / R replay", 16)
	_text(Vector2(365,765), "Checks passed: %s | Engine: %s | Server: %s" % [str(metadata.all_checks_passed),
		metadata.godot.string, metadata.physics_server_class], 13, Color("94a3b8"))
	_snapshot_if_requested()


func _panel() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("111d30")
	panel.corner_radius_top_left = 10
	panel.corner_radius_top_right = 10
	panel.corner_radius_bottom_left = 10
	panel.corner_radius_bottom_right = 10
	return panel


func _draw_collision(result: Dictionary, frame: Dictionary) -> void:
	var origin := Vector2(390,335)
	var scale_x := 1.15
	var attack_width: float = Measurements.ATTACK_SIZE.x*scale_x
	var target_width: float = Measurements.TARGET_SIZE.x*scale_x
	var attack_color := Color("fbbf24") if frame.active else Color("64748b")
	draw_line(origin, origin+Vector2(700,0), Color("334155"), 2)
	if frame.active:
		var sweep_left: float = minf(frame.sweep_start_x, frame.attack_x)*scale_x-attack_width/2
		var sweep_width: float = absf(frame.attack_x-frame.sweep_start_x)*scale_x+attack_width
		draw_rect(Rect2(origin+Vector2(sweep_left,-28), Vector2(sweep_width,56)), Color(1,0.75,0.2,0.13))
	draw_rect(Rect2(origin+Vector2(frame.previous_x*scale_x-attack_width/2,-28), Vector2(attack_width,56)), Color(1,1,1,0.15), false, 2)
	draw_rect(Rect2(origin+Vector2(frame.attack_x*scale_x-attack_width/2,-28), Vector2(attack_width,56)), attack_color, false, 3)
	for i in range(frame.targets.size()):
		var x: float = frame.targets[i]*scale_x
		draw_line(origin+Vector2(frame.previous_targets[i]*scale_x,0), origin+Vector2(x,0), Color(0.2,0.7,1,0.4), 3)
		draw_rect(Rect2(origin+Vector2(x-target_width/2,-36), Vector2(target_width,72)), Color("38bdf8"), false, 2)
		_text(origin+Vector2(x-8,62), str(i+1), 16)
	_text(Vector2(365,430), "Active: %s   Attack ID: %d   Endpoint x: %.0f" % [str(frame.active), frame.attack_id, frame.attack_x], 18, attack_color)
	for i in range(Measurements.METHODS.size()):
		var method: String = Measurements.METHODS[i]
		var hits := 0
		for hit in result.events[method]:
			# Signal callbacks arrive in a later engine frame than the activation sample.
			if hit.engine_frame <= frame.engine_frame:
				hits += 1
		_text(Vector2(365,466+i*32), "%s: %d hits so far / %d total; %d raw observations" % [
			method, hits, result.hits[method], result.raw_counts[method]], 17, METHOD_COLORS[i])
	_text(Vector2(365,650), "Expected %d total hits. A target may be hit once per attack." % result.expected, 17)


func _draw_trade(result: Dictionary) -> void:
	_text(Vector2(365,310), "Native query candidates: %s" % str(result.native_pairs), 20)
	_text(Vector2(365,365), "Immediate interruption, A first: %s damage" % str(result.naive_forward), 20, Color("fbbf24"))
	_text(Vector2(365,405), "Immediate interruption, B first: %s damage" % str(result.naive_reverse), 20, Color("fbbf24"))
	_text(Vector2(365,480), "Collect then resolve, A first: %s damage" % str(result.batch_forward), 20, Color("34d399"))
	_text(Vector2(365,520), "Collect then resolve, B first: %s damage" % str(result.batch_reverse), 20, Color("34d399"))
	_text(Vector2(365,600), "Collect both valid attacks before either character is interrupted.", 17)


func _draw_platform(result: Dictionary, frame: Dictionary) -> void:
	draw_rect(Rect2(550,390,350,12), Color("fbbf24"))
	var y: float = 390+(frame.y-580)*1.4
	draw_rect(Rect2(700,y-35,40,70), Color("38bdf8"), false, 3)
	_text(Vector2(365,530), "Phase: %s   Character y: %.1f   On floor: %s" % [frame.phase, frame.y, str(frame.on_floor)], 18)
	_text(Vector2(365,570), "Upward passage: %s   Landing: %s   Down-only drop: %s" % [
		str(result.rose_through), str(result.landed), str(result.dropped)], 18)
	_text(Vector2(365,610), "Collision restored: %s   Characters pass through: %s" % [
		str(result.restored), str(result.characters_pass)], 18, Color("34d399"))


func _snapshot_if_requested() -> void:
	if snapshot_requested:
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--snapshot="):
			snapshot_requested = true
			set_process(false)
			_capture.call_deferred(argument.trim_prefix("--snapshot="))
			return


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
