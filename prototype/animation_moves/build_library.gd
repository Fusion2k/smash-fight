extends SceneTree
## PROTOTYPE ONLY. Generates the animation resource used by the lab.
## Run: godot --headless --path <prototype root> --script res://prototype/animation_moves/build_library.gd

const STEP_SECONDS := 1.0 / 60.0
const OUT := "res://prototype/animation_moves/move_library.tres"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var anim := Animation.new()
	anim.step = STEP_SECONDS
	anim.length = STEP_SECONDS * 14.0
	anim.loop_mode = Animation.LOOP_NONE

	# Every key sits on a whole simulation step. Nearest/discrete means the
	# sampled value never blends between keys.
	_track(anim, "CombatSample:hitbox_extent", [
		[0, Vector2(12, 8)], [3, Vector2(12, 8)], [5, Vector2(26, 8)],
		[7, Vector2(26, 8)], [8, Vector2(12, 8)], [13, Vector2(12, 8)]])
	_track(anim, "CombatSample:hitbox_offset", [
		[0, Vector2(14, 0)], [3, Vector2(14, 0)], [5, Vector2(20, 0)],
		[7, Vector2(20, 0)], [8, Vector2(14, 0)], [13, Vector2(14, 0)]])
	_track(anim, "CombatSample:hurtbox_extent", [
		[0, Vector2(30, 46)], [13, Vector2(30, 46)]])
	_track(anim, "CombatSample:hurtbox_offset", [
		[0, Vector2(0, 0)], [13, Vector2(0, 0)]])
	_track(anim, "CombatSample:phase", [
		[0, 0], [3, 1], [7, 2], [13, 2]])
	_track(anim, "CombatSample:hitbox_active", [
		[0, false], [3, true], [7, false], [13, false]])

	anim.add_marker(&"startup_end", STEP_SECONDS * 3.0)
	anim.add_marker(&"active_end", STEP_SECONDS * 7.0)
	anim.add_marker(&"move_end", STEP_SECONDS * 13.0)

	var library := AnimationLibrary.new()
	library.add_animation(&"punch", anim)
	var err := ResourceSaver.save(library, OUT)
	if err != OK:
		push_error("PROTOTYPE: could not save %s: %s" % [OUT, err])
		quit(1)
		return
	print("PROTOTYPE: wrote %s (%d tracks, %d markers)" % [OUT, anim.get_track_count(), anim.get_marker_names().size()])
	quit(0)

func _track(anim: Animation, path: String, keys: Array) -> void:
	var index := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(index, path)
	anim.track_set_interpolation_type(index, Animation.INTERPOLATION_NEAREST)
	anim.value_track_set_update_mode(index, Animation.UPDATE_DISCRETE)
	for entry in keys:
		anim.track_insert_key(index, float(entry[0]) * STEP_SECONDS, entry[1])
