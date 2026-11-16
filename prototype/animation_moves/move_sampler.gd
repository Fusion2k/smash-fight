class_name PrototypeMoveSampler
extends RefCounted
## PROTOTYPE ONLY — the liftable part.
## Pure sampling of an Animation resource into per-step combat values.
## No playback, no clock, no node writes, no side effects on authored data.

const STEP_SECONDS := 1.0 / 60.0

const TRACKS := {
	"hitbox_extent": "CombatSample:hitbox_extent",
	"hitbox_offset": "CombatSample:hitbox_offset",
	"hurtbox_extent": "CombatSample:hurtbox_extent",
	"hurtbox_offset": "CombatSample:hurtbox_offset",
	"phase": "CombatSample:phase",
	"hitbox_active": "CombatSample:hitbox_active",
}

const PHASE_NAMES := ["startup", "active", "recovery"]

var animation: Animation

func _init(anim: Animation) -> void:
	animation = anim

## Sample one simulation step. Time is derived from the integer step, never
## from wall clock or AnimationPlayer playback position.
func sample(step: int) -> Dictionary:
	var time := float(step) * STEP_SECONDS
	var result := {"step": step, "time": time}
	for key in TRACKS:
		var index := animation.find_track(TRACKS[key], Animation.TYPE_VALUE)
		result[key] = animation.value_track_interpolate(index, time) if index >= 0 else null
	result["phase_name"] = PHASE_NAMES[int(result.get("phase", 0))]
	result["marker"] = _marker_at(time)
	return result

## The authored key value at step 0, used to prove sampling never mutates
## the shared Resource (A2 isolation).
func authored_baseline(key: String) -> Variant:
	var index := animation.find_track(TRACKS[key], Animation.TYPE_VALUE)
	return animation.track_get_key_value(index, 0)

func set_extent(key: String, step: int, value: Vector2) -> void:
	var index := animation.find_track(TRACKS[key], Animation.TYPE_VALUE)
	var key_index := _key_index_at(index, step)
	if key_index >= 0:
		animation.track_set_key_value(index, key_index, value)
	else:
		animation.track_insert_key(index, float(step) * STEP_SECONDS, value)

## Editor-style retiming: drag the whole active window — phase, eligibility,
## hitbox geometry and markers — one step. Moving only the phase key would
## leave geometry behind, which is exactly the failure this prototype probes.
func retime_active_start(delta_steps: int) -> void:
	var startup_step := int(round(animation.get_marker_time(&"startup_end") / STEP_SECONDS))
	var active_step := int(round(animation.get_marker_time(&"active_end") / STEP_SECONDS))
	var middle_step := (startup_step + active_step) / 2
	# Descending order avoids overwriting a key we have not moved yet.
	for step in [active_step + 1, active_step, middle_step, startup_step]:
		for key in TRACKS:
			_move_key(key, step, step + delta_steps)
	animation.remove_marker(&"startup_end")
	animation.add_marker(&"startup_end", float(startup_step + delta_steps) * STEP_SECONDS)
	animation.remove_marker(&"active_end")
	animation.add_marker(&"active_end", float(active_step + delta_steps) * STEP_SECONDS)

func _move_key(key: String, from_step: int, to_step: int) -> void:
	var index := animation.find_track(TRACKS[key], Animation.TYPE_VALUE)
	var key_index := _key_index_at(index, from_step)
	if key_index >= 0:
		animation.track_set_key_time(index, key_index, float(to_step) * STEP_SECONDS)

## Animation stores key times as float32, so an exact float64 comparison can
## miss a key at what looks like the same step. This is a prototype finding,
## not production code.
func _key_index_at(track: int, step: int) -> int:
	var target := float(step) * STEP_SECONDS
	for i in range(animation.track_get_key_count(track)):
		if absf(animation.track_get_key_time(track, i) - target) <= STEP_SECONDS * 0.25:
			return i
	return -1

func _marker_at(time: float) -> String:
	for marker_name in animation.get_marker_names():
		var marker_time := animation.get_marker_time(marker_name)
		if absf(marker_time - time) <= STEP_SECONDS * 0.25:
			return String(marker_name)
	return ""
