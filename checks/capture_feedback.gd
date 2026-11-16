extends SceneTree
## Bounded native-render QA fixture. Frames advance through production Match only.
var app: SmashApplication
var directory := "res://build"
func _initialize() -> void:
	_run.call_deferred()
func capture(name: String) -> void:
	app._present()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := directory.path_join("19-" + name + ".png")
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--directory="):
			directory = arg.trim_prefix("--directory=")
	app = load("res://app/app.tscn").instantiate() as SmashApplication
	app.automatic = false
	root.add_child(app)
	app.start_developer_test()
	app.phase = "playing"
	var prepared := app.catalog.prepare_match(app.definitions)
	app.game.start({"characters": prepared.characters, "positions": [Vector2(600, 538), Vector2(645, 530)]})
	await physics_frame
	for tick in 4:
		app.game.step()
	for tick in 14:
		app.game.step({0: {"attack_pressed": tick == 0}})
		if tick == 0:
			await capture("startup")
		if tick == 4:
			await capture("hit")
		if tick == 10:
			await capture("recovery")
	app.game.start({"characters": prepared.characters, "positions": [Vector2(400, 300), Vector2(840, 300)]})
	await physics_frame
	for tick in 8:
		app.game.step({0: {"special_pressed": tick == 0}, 1: {"special_pressed": tick == 0}})
	await capture("special")
	# Independent same-identity state and color markers in the actual application.
	app.slots[1].selection = 0
	prepared = app.catalog.prepare_match([app.definitions[0], app.definitions[0]])
	app.game.start({"characters": prepared.characters})
	await physics_frame
	for tick in 15:
		app.game.step({1: {"horizontal": -1}})
	await capture("same-character")
	app.pause()
	await capture("paused")
	app.game.start({"characters": prepared.characters, "stocks": 1, "positions": [Vector2(-200, 200), Vector2(1500, 200)]})
	app.game.step()
	app.phase = "results"
	await capture("results")
	app.free()
	quit()
