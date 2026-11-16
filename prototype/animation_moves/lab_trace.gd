extends SceneTree
## PROTOTYPE ONLY. Headless trace: proves an Animation resource can be sampled
## at exact steps and fed to the production swept-rectangle detector.

const LIBRARY_PATH := "res://prototype/animation_moves/move_library.tres"
const Sampler = preload("res://prototype/animation_moves/move_sampler.gd")
const HitDetection = preload("res://combat/hit_detection.gd")

var sampler

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var library := ResourceLoader.load(LIBRARY_PATH, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP) as AnimationLibrary
	sampler = Sampler.new(library.get_animation(&"punch"))
	print("QUESTION: can a Godot Animation timeline author timing, hitbox extent, hurtbox extent and state, while the simulation stays authoritative?")
	print("STEP | MARKER        | PHASE    | HIT EXTENT | HURT EXTENT | HIT? | CONTACTS")
	_trace("baseline")
	sampler.retime_active_start(1)
	_trace("active start moved +1 step")
	sampler.retime_active_start(-1)
	sampler.set_extent("hurtbox_extent", 4, Vector2(10, 40))
	_trace("hurtbox shrunk at step 4")
	print("AUTHORED HURTBOX BASELINE (unchanged): ", sampler.authored_baseline("hurtbox_extent"))
	quit(0)

func _trace(label: String) -> void:
	print("--- ", label, " ---")
	for step in range(14):
		var sample: Dictionary = sampler.sample(step)
		var plans := _plans(sample)
		var result := HitDetection.next_contacts(plans, Sampler.STEP_SECONDS)
		var contacts: Array = result.get("contacts", [])
		print("%4d | %-13s | %-8s | %-10s | %-11s | %-4s | %d" % [
			step, sample["marker"], sample["phase_name"],
			str(sample["hitbox_extent"]), str(sample["hurtbox_extent"]),
			str(sample["hitbox_active"]), contacts.size()])

func _plans(sample: Dictionary) -> Array:
	var hit_shape := RectangleShape2D.new()
	hit_shape.size = sample["hitbox_extent"]
	var hurt_shape := RectangleShape2D.new()
	hurt_shape.size = sample["hurtbox_extent"]
	var attack := {
		"combat": {
			"active": sample["hitbox_active"],
			"move": {
				"hitbox": hit_shape,
				"hitbox_offset": sample["hitbox_offset"],
				"launch_direction": Vector2(1, -0.5),
				"launch_strength": 260.0,
			},
			"targets": [],
			"attack_id": 1,
			"attack_damage": 4,
		},
		"slot_id": 1,
		"facing": 1,
		"from": {"origin": Vector2.ZERO},
		"velocity": Vector2.ZERO,
		"start": 0.0,
	}
	var target := {
		"slot_id": 2,
		"combat": {"active": false, "vulnerable": true},
		"geometry": {
			"Hurtboxes/Body": {
				"shape": hurt_shape,
				"offset": sample["hurtbox_offset"],
			},
		},
		"from": {"origin": Vector2(40, 0)},
		"velocity": Vector2.ZERO,
	}
	return [attack, target]
