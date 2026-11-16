extends SceneTree
## PROTOTYPE ONLY. Graphical capture of the editor-style preview at step 4.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed := load("res://prototype/animation_moves/zip_timeline.tscn") as PackedScene
	var zip := packed.instantiate()
	root.add_child(zip)
	zip.global_position = Vector2(640, 360)
	var player := zip.get_node("Timeline") as AnimationPlayer
	player.assigned_animation = &"moves/ground_neutral"
	player.seek(4.0 / 60.0, true)
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://prototype/animation_moves/zip_editor_preview.png"
	root.get_texture().get_image().save_png(path)
	var hitbox = zip.get_node("HitboxPreview")
	var hurtbox = zip.get_node("HurtboxPreview")
	print("PROTOTYPE: step 4 hitbox=", hitbox._last_extent, " hurtbox=", hurtbox._last_extent)
	print("PROTOTYPE: captured ", path)
	quit(0)
