extends SceneTree
## PROTOTYPE ONLY. Graphical capture of the lab for a visual sanity check.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed := load("res://prototype/animation_moves/animation_moves_lab.tscn") as PackedScene
	root.add_child(packed.instantiate())
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "res://prototype/animation_moves/lab_capture.png"
	image.save_png(path)
	print("PROTOTYPE: captured ", path, " ", image.get_size())
	quit(0)
