extends Node2D
## THROWAWAY engine experiment for #11. No production gameplay architecture.

signal completed(results: Array, metadata: Dictionary)

const ATTACK_SIZE = Vector2(64, 38)
const TARGET_SIZE = Vector2(28, 50)
const METHODS = ["Area poll", "Area signal", "Direct endpoint", "Two-motion sweep", "Relative sweep"]
var results: Array = []
var cases: Array = []
var current: Dictionary = {}
var targets: Array = []
var area: Area2D
var attack_shape: RectangleShape2D
var target_shape: RectangleShape2D
var case_index := -1
var tick := -1
var warmup := 0
var active := false
var attack_id := 0
var platform_tick := -1
var platform: StaticBody2D
var walker: CharacterBody2D
var blocker: CharacterBody2D
var platform_phase := "rise"
var platform_result: Dictionary = {}


func _ready() -> void:
	attack_shape = RectangleShape2D.new()
	attack_shape.size = ATTACK_SIZE
	target_shape = RectangleShape2D.new()
	target_shape.size = TARGET_SIZE
	area = Area2D.new()
	area.name = "MeasuredAttackArea"
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = false
	var collider := CollisionShape2D.new()
	collider.shape = attack_shape
	area.add_child(collider)
	add_child(area)
	area.body_entered.connect(_area_entered)
	cases = [
		_fixture("One-step activation", [40,40,40,220,40,40,40,40,40,40,40,40], [3], [_flat(220)], 1,
			"A newly enabled attack overlaps a target for exactly one full physics step."),
		_fixture("Fast attack crossing", [40,40,40,40,440,440,440,440,440,440,440,440], [3,4], [_flat(220)], 1,
			"The active attack crosses a target between endpoints: 400 px in one step."),
		_fixture("Fast target crossing", _flat(220), [3,4], [[440,440,440,440,40,40,40,40,40,40,40,40]], 1,
			"The target crosses a stationary active attack. Both motions matter."),
		_fixture("Target enters this step", _flat(220), [3], [[440,440,440,220,440,440,440,440,440,440,440,440]], 1,
			"Query before and after moving the target into a one-step attack."),
		_fixture("Parallel motion must not hit", [40,40,40,40,440,440,440,440,440,440,440,440], [3,4],
			[[180,180,180,180,580,580,580,580,580,580,580,580]], 0,
			"Attack and target move equally fast, staying apart. Swept paths overlap but no hit occurs."),
		_fixture("Multiple targets", _flat(220), [3,4,5], [_flat(205),_flat(235),_flat(260)], 3,
			"One attack overlaps three targets; each should receive one hit."),
		_fixture("Persistent overlap / new attack", _flat(220), [2,3,4,5,8,9], [_flat(220)], 2,
			"Repeated samples count once per attack. A later attack may hit again."),
		_fixture("Startup motion must not hit", [40,40,440,440,440,440,440,440,440,440,440,440], [3], [_flat(220)], 0,
			"Crossing during startup must not create a phantom sweep on activation."),
		_fixture("Deactivation must not hit", [40,40,40,40,440,440,440,440,440,440,440,440], [3], [_flat(220)], 0,
			"Crossing after the active window closes must not deal damage."),
		_fixture("Simultaneous trades", _flat(220), [3], [_flat(220),_flat(250)], 2,
			"Resolve two native query results immediately versus collecting before interruption.", true),
	]
	_next_case()


func _flat(x: float) -> Array:
	var path: Array = []
	path.resize(12)
	path.fill(x)
	return path


func _fixture(title: String, path: Array, active_ticks: Array, paths: Array,
		expected: int, explanation: String, trade := false) -> Dictionary:
	return {"title": title, "attack_path": path, "active_ticks": active_ticks,
		"target_paths": paths, "expected": expected, "explanation": explanation, "trade": trade}


func _body(label: String, position_value: Vector2, layer: int, mask: int) -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.name = label
	body.position = position_value
	body.collision_layer = layer
	body.collision_mask = mask
	var collider := CollisionShape2D.new()
	collider.shape = target_shape
	body.add_child(collider)
	add_child(body)
	return body


func _next_case() -> void:
	active = false
	area.monitoring = false
	for body in targets:
		body.free()
	targets.clear()
	case_index += 1
	if case_index == cases.size():
		_begin_platform()
		return
	current = cases[case_index].duplicate(true)
	current["trace"] = []
	current["events"] = {}
	current["raw_counts"] = {}
	current["seen"] = {}
	for method in METHODS:
		current.events[method] = []
		current.raw_counts[method] = 0
		current.seen[method] = {}
	for i in range(current.target_paths.size()):
		targets.append(_body("Target%d" % i, Vector2(current.target_paths[i][0], 0), 1, 0))
	area.position = Vector2(current.attack_path[0], 0)
	tick = -1
	attack_id = 0
	warmup = 4


func _physics_process(delta: float) -> void:
	if platform_tick >= 0:
		_measure_platform(delta)
		return
	if current.is_empty():
		return
	if warmup > 0:
		warmup -= 1
		return
	tick += 1
	if tick >= current.attack_path.size():
		current["hits"] = {}
		for method in METHODS:
			current.hits[method] = current.events[method].size()
		current.erase("seen")
		if current.trade:
			current["passed"] = current.batch_forward == [12,12] and current.batch_reverse == [12,12]
		else:
			current["passed"] = current.hits["Relative sweep"] == current.expected
		results.append(current.duplicate(true))
		if current.trade:
			print("OBSERVATION ", current.title, " immediate=", current.naive_forward,
				" reversed=", current.naive_reverse, " batched=", current.batch_forward, "/", current.batch_reverse)
		else:
			print("OBSERVATION ", current.title, " ", current.hits, " expected=", current.expected)
		_next_case()
		return
	var was_active := active
	active = current.active_ticks.has(tick)
	if active and not was_active:
		attack_id += 1
	var previous_attack: Vector2 = area.position
	var previous_targets: Array = []
	for body in targets:
		previous_targets.append(body.position)
	var before_move: Array = _query(area.position)
	area.position.x = current.attack_path[tick]
	for i in range(targets.size()):
		# Use scripted CharacterBody movement, not a teleport, for moving-target evidence.
		var movement := Vector2(current.target_paths[i][tick] - targets[i].position.x, 0)
		targets[i].move_and_collide(movement)
	area.monitoring = active
	var sampled: Dictionary = {"Area poll": [], "Area signal": [], "Direct endpoint": [],
		"Two-motion sweep": [], "Relative sweep": []}
	if active and not current.trade:
		for body in area.get_overlapping_bodies():
			var target_index: int = targets.find(body)
			if target_index >= 0:
				sampled["Area poll"].append(target_index)
		for target_index in _query(area.position):
			sampled["Direct endpoint"].append(target_index)
		for i in range(targets.size()):
			# Never sweep across startup or inactive time; activation starts at its current pose.
			var attack_start: Vector2 = previous_attack if was_active else area.position
			var target_start: Vector2 = previous_targets[i] if was_active else targets[i].position
			if attack_shape.collide_with_motion(Transform2D(0, attack_start), area.position - attack_start,
					target_shape, Transform2D(0, target_start), targets[i].position - target_start):
				sampled["Two-motion sweep"].append(i)
			# Sweep in the target's reference frame. Sweeping both paths separately is conservative
			# and can report a collision when the shapes remain equally far apart throughout.
			var relative_motion: Vector2 = (area.position-attack_start) - (targets[i].position-target_start)
			if attack_shape.collide_with_motion(Transform2D(0, attack_start), relative_motion,
					target_shape, Transform2D(0, target_start), Vector2.ZERO):
				sampled["Relative sweep"].append(i)
		for method in ["Area poll", "Direct endpoint", "Two-motion sweep", "Relative sweep"]:
			for target_index in sampled[method]:
				_record(method, target_index)
	if active and current.trade:
		_measure_trade()
	var target_x: Array = []
	var previous_target_x: Array = []
	for body in targets:
		target_x.append(body.position.x)
	for previous_position in previous_targets:
		previous_target_x.append(previous_position.x)
	current.trace.append({"tick": tick, "engine_frame": Engine.get_physics_frames(), "active": active,
		"attack_id": attack_id, "attack_x": area.position.x, "previous_x": previous_attack.x,
		"sweep_start_x": previous_attack.x if active and was_active else area.position.x,
		"targets": target_x, "previous_targets": previous_target_x,
		"sampled": sampled, "direct_before_move": before_move})


func _query(origin: Vector2, excluded: Array[RID] = []) -> Array:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape
	query.transform = Transform2D(0, origin)
	query.collision_mask = 1
	query.exclude = excluded
	var found: Array = []
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var target_index: int = targets.find(hit.collider)
		if target_index >= 0:
			found.append(target_index)
	found.sort()
	return found


func _record(method: String, target_index: int) -> void:
	current.raw_counts[method] += 1
	var key := "%d:%d" % [attack_id, target_index]
	if current.seen[method].has(key):
		return
	current.seen[method][key] = true
	current.events[method].append({"tick": tick, "engine_frame": Engine.get_physics_frames(),
		"attack_id": attack_id, "target": target_index})


func _area_entered(body: Node2D) -> void:
	if current.is_empty() or current.trade or not active:
		return
	var target_index: int = targets.find(body)
	if target_index >= 0:
		_record("Area signal", target_index)


func _measure_trade() -> void:
	var pairs: Array = []
	for attacker in range(2):
		var excluded: Array[RID] = [targets[attacker].get_rid()]
		for defender in _query(targets[attacker].position, excluded):
			pairs.append([attacker, defender])
	current["native_pairs"] = pairs
	current["naive_forward"] = _resolve_trade(pairs, [0,1], false)
	current["naive_reverse"] = _resolve_trade(pairs, [1,0], false)
	current["batch_forward"] = _resolve_trade(pairs, [0,1], true)
	current["batch_reverse"] = _resolve_trade(pairs, [1,0], true)


func _resolve_trade(pairs: Array, order: Array, batched: bool) -> Array:
	var damage := [0,0]
	var interrupted := [false,false]
	var accepted: Array = []
	for attacker in order:
		for pair in pairs:
			if pair[0] == attacker and not interrupted[attacker]:
				if batched:
					accepted.append(pair)
				else:
					damage[pair[1]] += 12
					interrupted[pair[1]] = true
	for pair in accepted:
		damage[pair[1]] += 12
		interrupted[pair[1]] = true
	return damage


func _begin_platform() -> void:
	current = {}
	platform = StaticBody2D.new()
	platform.name = "OneWayPlatform"
	platform.position = Vector2(300, 580)
	platform.collision_layer = 8
	platform.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(220, 12)
	collider.shape = shape
	collider.one_way_collision = true
	platform.add_child(collider)
	add_child(platform)
	walker = _body("PlatformCharacter", Vector2(300,630), 2, 8)
	blocker = _body("OtherCharacter", Vector2(500,500), 2, 8)
	platform_result = {"title": "One-way platform and pass-through", "explanation":
		"Actual upward passage, resting landing, fresh-down drop, restored collision, and pass-through.",
		"trace": [], "rose_through": false, "landed": false, "dropped": false,
		"restored": false, "characters_pass": false}
	platform_tick = 0
	platform_phase = "rise"
	walker.velocity.y = -600


func _measure_platform(delta: float) -> void:
	platform_tick += 1
	if platform_tick <= 4:
		return
	if platform_tick == 5:
		walker.position = Vector2(400,500)
		var contact: KinematicCollision2D = walker.move_and_collide(Vector2(240,0))
		platform_result.characters_pass = contact == null and walker.position.x > blocker.position.x
		walker.position = Vector2(300,630)
	if platform_phase == "rise":
		walker.move_and_slide()
		if walker.position.y < 515:
			platform_result.rose_through = true
			platform_phase = "fall"
			walker.velocity.y = 0
	elif platform_phase == "fall" or platform_phase == "restore":
		walker.velocity.y += 1200 * delta
		walker.move_and_slide()
		if walker.is_on_floor():
			if platform_phase == "fall":
				platform_result.landed = true
				platform_phase = "rest"
			else:
				platform_result.restored = true
				_finish_platform()
				return
	elif platform_phase == "rest":
		# A single scripted down press temporarily excludes only the supporting platform.
		walker.add_collision_exception_with(platform)
		walker.velocity.y = 180
		platform_phase = "drop"
	elif platform_phase == "drop":
		walker.move_and_slide()
		if walker.position.y - TARGET_SIZE.y / 2 > 590:
			platform_result.dropped = true
			walker.remove_collision_exception_with(platform)
			walker.position = Vector2(300,500)
			walker.velocity = Vector2.ZERO
			platform_phase = "restore"
	platform_result.trace.append({"tick": platform_tick, "y": walker.position.y,
		"phase": platform_phase, "on_floor": walker.is_on_floor()})
	if platform_tick > 180:
		_finish_platform()


func _finish_platform() -> void:
	platform_result["passed"] = platform_result.rose_through and platform_result.landed \
		and platform_result.dropped and platform_result.restored and platform_result.characters_pass
	results.append(platform_result.duplicate(true))
	platform_tick = -1
	set_physics_process(false)
	var passed := true
	for result in results:
		passed = passed and result.passed
	var metadata := {"godot": Engine.get_version_info(), "platform": OS.get_name(),
		"physics_server_class": PhysicsServer2D.get_class(),
		"loaded_extensions": GDExtensionManager.get_loaded_extensions(),
		"selected_backend": ProjectSettings.get_setting("physics/2d/physics_engine"),
		"ticks_per_second": Engine.physics_ticks_per_second, "all_checks_passed": passed}
	print("MEASUREMENT_SUMMARY ", JSON.stringify(metadata))
	completed.emit(results, metadata)
