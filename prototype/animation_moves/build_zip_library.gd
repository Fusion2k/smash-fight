extends SceneTree
## PROTOTYPE ONLY. Generates one Animation per Zip move from the authored move data.
## Each key sits on a whole simulation step; all combat values live on the timeline.

const STEP_SECONDS := 1.0 / 60.0
const OUT := "res://prototype/animation_moves/zip_move_library.tres"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var definition = load("res://characters/zip/zip.tres")
	var library := AnimationLibrary.new()
	for move in definition.moves:
		var startup := int(move.startup_steps)
		var active := int(move.active_steps)
		var recovery := int(move.recovery_steps)
		var total := startup + active + recovery
		var end := total - 1
		var grow := startup + maxi(1, active / 2)
		var base_extent: Vector2 = move.hitbox.size
		var base_offset: Vector2 = move.hitbox_offset
		var hurt_base := Vector2(30, 46)
		var hurt_small := Vector2(18, 42)

		var anim := Animation.new()
		anim.step = STEP_SECONDS
		anim.length = float(total) * STEP_SECONDS
		anim.loop_mode = Animation.LOOP_NONE

		# Data tracks sampled by the simulation.
		_track(anim, "CombatSample:hitbox_extent", [
			[0, base_extent], [startup, base_extent],
			[grow, Vector2(base_extent.x * 1.8, base_extent.y)],
			[startup + active, base_extent], [end, base_extent]])
		_track(anim, "CombatSample:hitbox_offset", [
			[0, base_offset], [startup, base_offset],
			[grow, base_offset + Vector2(4, 0)],
			[startup + active, base_offset], [end, base_offset]])
		_track(anim, "CombatSample:hurtbox_extent", [
			[0, hurt_base], [startup, hurt_base], [grow, hurt_small],
			[startup + active, hurt_base], [end, hurt_base]])
		_track(anim, "CombatSample:hurtbox_offset", [[0, Vector2.ZERO], [end, Vector2.ZERO]])
		_track(anim, "CombatSample:phase", [
			[0, 0], [startup, 1], [startup + active, 2], [end, 2]])
		_track(anim, "CombatSample:hitbox_active", [
			[0, false], [startup, true], [startup + active, false], [end, false]])

		# Visual-only tracks. Combat geometry is NOT duplicated here: the two
		# preview rectangles read the CombatSample properties above, so one key
		# moves the editor preview and the simulation together.
		_track(anim, "Visual/Weapon:rotation", [
			[0, -0.6], [startup, -0.6], [grow, 0.5],
			[startup + active, 0.2], [end, 0.0]])
		_track(anim, "Visual/Weapon:position", [
			[0, Vector2(0, -5)], [startup, Vector2(0, -5)],
			[grow, Vector2(6, -8)], [startup + active, Vector2(2, -5)],
			[end, Vector2(0, -5)]])
		_track(anim, "Visual/Feet:position", [
			[0, Vector2.ZERO], [startup, Vector2.ZERO],
			[grow, Vector2(0, 3)], [startup + active, Vector2.ZERO],
			[end, Vector2.ZERO]])

		anim.add_marker(&"startup_end", float(startup) * STEP_SECONDS)
		anim.add_marker(&"active_end", float(startup + active) * STEP_SECONDS)
		anim.add_marker(&"move_end", float(end) * STEP_SECONDS)
		library.add_animation(StringName(move.move_id), anim)
		print("PROTOTYPE: %s startup=%d active=%d recovery=%d keys on %d steps" % [
			move.move_id, startup, active, recovery, total])

	var err := ResourceSaver.save(library, OUT)
	if err != OK:
		push_error("PROTOTYPE: could not save %s: %s" % [OUT, err])
		quit(1)
		return
	print("PROTOTYPE: wrote %s with %d move animations" % [OUT, library.get_animation_list().size()])
	quit(0)

func _track(anim: Animation, path: String, entries: Array) -> void:
	var by_step := {}
	for entry in entries:
		by_step[int(entry[0])] = entry[1]
	var index := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(index, path)
	anim.track_set_interpolation_type(index, Animation.INTERPOLATION_NEAREST)
	anim.value_track_set_update_mode(index, Animation.UPDATE_DISCRETE)
	var steps := by_step.keys()
	steps.sort()
	for step in steps:
		anim.track_insert_key(index, float(step) * STEP_SECONDS, by_step[step])
