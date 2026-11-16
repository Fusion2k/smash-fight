extends SceneTree
## PROTOTYPE ONLY. Runs the real application in Developer Test, presses attack,
## and captures a real 1280x720 viewport PNG of timeline-driven Zip in action.

var _app
var _ticks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed := load("res://app/app.tscn") as PackedScene
	_app = packed.instantiate()
	_app.automatic = false
	root.add_child(_app)
	_app.start_developer_test()
	await process_frame
	# Countdown is 180 flow ticks; advance it with no input, then press attack.
	for i in range(184):
		var frames: Dictionary = _app.advance({-1: {}, -2: {}})
		_app.game.step(frames)
		await process_frame
	print("PROTOTYPE: app phase after countdown=", _app.phase, " slots=", _app.slots)
	for i in range(3):
		var input := {}
		if i == 0:
			input = {"attack": true}
		var frames: Dictionary = _app.advance({-1: input, -2: {}})
		var stepped: Dictionary = _app.game.step(frames)
		var body = _app.game.characters[0]
		print("PROTOTYPE: tick ", i, " move=", body.view().move_id,
			" phase=", body.view().phase, " step=", stepped.get("ok", false))
		await process_frame
	var character = _app.game.characters[0]
	var sample: Dictionary = character.timeline_sample()
	var state: Dictionary = character.view()
	var combat: Dictionary = character.combat_snapshot()
	var move: Dictionary = combat.get("move", {})
	var active: String = "no"
	if not move.is_empty():
		active = str((move.hitbox as RectangleShape2D).size)
	print("PROTOTYPE: phase=", state.phase, " move=", state.move_id,
		" sample=", sample, " hitbox=", active)
	await RenderingServer.frame_post_draw
	var path := "res://prototype/animation_moves/zip_play_capture.png"
	root.get_texture().get_image().save_png(path)
	print("PROTOTYPE: captured ", path)
	quit(0)
