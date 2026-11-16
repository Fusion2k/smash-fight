extends SceneTree
## PROTOTYPE ONLY. Proves the Animation tracks move real scene nodes when the
## AnimationPlayer seeks — i.e. what the editor's animation preview will show.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed := load("res://prototype/animation_moves/zip_timeline.tscn") as PackedScene
	var zip := packed.instantiate()
	root.add_child(zip)
	var player := zip.get_node("Timeline") as AnimationPlayer
	var hitbox := zip.get_node("HitboxPreview")
	var hurtbox := zip.get_node("HurtboxPreview")
	var weapon := zip.get_node("Visual/Weapon")
	var sample := zip.get_node("CombatSample")
	player.assigned_animation = &"moves/ground_neutral"

	for step in [0, 3, 4, 6, 8]:
		player.seek(float(step) / 60.0, true)
		hitbox.sync()
		hurtbox.sync()
		print("STEP %d sample_hit=%s sample_hurt=%s drawn_hit=%s drawn_hurt=%s weapon_rot=%.2f" % [
			step, str(sample.hitbox_extent), str(sample.hurtbox_extent),
			str(hitbox._last_extent), str(hurtbox._last_extent), weapon.rotation])
	quit(0)
