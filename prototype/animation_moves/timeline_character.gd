extends Character
## PROTOTYPE ONLY. Zip whose moves are authored as Animation timelines.
## The Animation supplies per-step phase, hitbox and hurtbox geometry; the
## inherited Character/Match still own the clock, hits, stocks and pause.

const Sampler = preload("res://prototype/animation_moves/move_sampler.gd")
const PHASES := ["startup", "active", "recovery"]

@export var move_library: AnimationLibrary

var _timeline: Animation
var _sampler
var _sample := {}

func timeline_sample() -> Dictionary:
	return _sample.duplicate(true)

func _start_attack(move_id: String) -> void:
	var key := StringName(move_id)
	_timeline = move_library.get_animation(key) if move_library and move_library.has_animation(key) else null
	_sampler = Sampler.new(_timeline) if _timeline != null else null
	_sample.clear()
	# super calls _update_phase(), which reads the timeline set above.
	super._start_attack(move_id)
	_apply_sample()

func _end_attack() -> void:
	_timeline = null
	_sampler = null
	_sample.clear()
	super._end_attack()

func _update_phase() -> void:
	if _timeline == null:
		super._update_phase()
		return
	_apply_sample()
	var total_steps := int(round(_timeline.length / STEP_SECONDS))
	if _state.attack_age >= total_steps - 1:
		_end_attack()
		return
	var index := clampi(int(_sample.get("phase", 0)), 0, PHASES.size() - 1)
	_state.phase = PHASES[index]

func _apply_sample() -> void:
	if _sampler == null:
		return
	_sample = _sampler.sample(_state.attack_age)

func combat_snapshot() -> Dictionary:
	var snapshot := super.combat_snapshot()
	if _timeline == null:
		return snapshot
	_apply_sample()
	var move: Dictionary = snapshot.get("move", {})
	if not move.is_empty():
		var shape := (move.hitbox as RectangleShape2D).duplicate(true)
		shape.size = _sample["hitbox_extent"]
		move.hitbox = shape
		move.hitbox_offset = _sample["hitbox_offset"]
		snapshot["move"] = move
	snapshot["active"] = bool(_sample["hitbox_active"]) and not _state.frozen
	return snapshot

func predict_interval(until: float = 1.0) -> Dictionary:
	var plan := super.predict_interval(until)
	if not plan.get("ok", false) or _timeline == null:
		return plan
	_apply_sample()
	var geometry: Dictionary = (plan.get("geometry", {}) as Dictionary).duplicate(true)
	for key in geometry:
		if not str(key).begins_with("Hurtboxes/"):
			continue
		var entry: Dictionary = geometry[key]
		var shape := (entry["shape"] as RectangleShape2D).duplicate(true)
		shape.size = _sample["hurtbox_extent"]
		entry["shape"] = shape
		entry["offset"] = _sample["hurtbox_offset"]
		geometry[key] = entry
	plan["geometry"] = geometry
	return plan
