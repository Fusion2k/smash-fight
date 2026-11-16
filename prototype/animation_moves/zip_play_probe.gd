extends SceneTree
## PROTOTYPE ONLY. Drives timeline-driven Zip through real Character steps.

const Catalog = preload("res://characters/character_catalog.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var definition = load("res://prototype/animation_moves/zip_timeline.tres")
	var catalog = Catalog.new()
	var prepared := catalog.prepare_match([definition])
	print("PROTOTYPE: content ok=", prepared.ok, " errors=", prepared.errors)
	if not prepared.ok:
		quit(1)
		return
	var character = prepared.characters[0].instantiate_scene()
	root.add_child(character)
	character.configure(prepared.characters[0], 0)
	character.respawn(Vector2(0, 0))

	var input := {"attack_pressed": true, "attack_direction": "neutral", "horizontal": 1.0}
	print("STEP | PHASE    | TIMELINE | HITBOX       | HURTBOX      | ACTIVE")
	for step in range(16):
		var result = character.prepare_step(input)
		if not result.get("ok", false):
			print("PROTOTYPE: prepare_step failed at ", step, " ", result)
			quit(1)
			return
		var plan = character.predict_interval(1.0)
		if not plan.get("ok", false):
			print("PROTOTYPE: predict failed at ", step, " ", plan)
			quit(1)
			return
		var sample: Dictionary = character.timeline_sample()
		var move: Dictionary = plan.combat.move
		if move.is_empty():
			print("%4d | %-8s | %-8s | %-12s | %-12s | %s" % [
				step, character.view().phase, "idle", "-", "-", "false"])
			character.commit_interval(plan, 1.0)
			character.finish_step()
			input = {}
			continue
		var hurt: Dictionary = plan.geometry["Hurtboxes/Body"]
		print("%4d | %-8s | %-8s | %-12s | %-12s | %s" % [
			step, character.view().phase, str(sample.get("phase", "-")),
			str(move.hitbox.size), str(hurt.shape.size), str(plan.combat.active)])
		character.commit_interval(plan, 1.0)
		character.finish_step()
		input = {}
	print("PROTOTYPE: 16 steps completed with no simulation error")
	quit(0)
