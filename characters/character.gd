class_name Character
extends CharacterBody2D
## Simulation-owned body: deliberately has no _physics_process callback.
## Only static Arena bodies occupy collision mask 1. Characters occupy layer 0.

const STEP_SECONDS := 1.0 / 60.0
const BUFFER_STEPS := 6
const GRACE_STEPS := 5
const MARGIN := 0.01
const TIME_EPSILON := 0.0000001
const POSITION_EPSILON := 0.002
const QUERY_BUDGET := 32

var slot_id := -1
var prepared: PreparedCharacter
var _settings: Dictionary
var _state := {}
var _revision := 0
var _cursor := 0.0
var _in_step := false
var _support: Dictionary = {}
var _drop_rid := RID()
var _drop_bottom := 0.0
var _move: Dictionary = {}
var _new_counters := {}
var _next_attack_id := 0

func configure(content: PreparedCharacter, slot: int) -> void:
	prepared = content
	_settings = content.settings()
	slot_id = slot
	respawn(global_position)

func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_state = {"grounded": false, "air_jump_available": true, "recovery_available": true,
		"recovery_locked": false, "facing": 1, "fast_fall": false, "ground_jump": false,
		"buffer_kind": "", "buffer_steps": 0, "grace_steps": 0, "committed": false,
		"hitstun": 0, "frozen": false, "damage": 0.0, "pending_launch": Vector2.ZERO,
		"hit_pause": 0, "landing_delay": 0, "protection": 0, "move_id": "",
		"attack_age": 0, "attack_id": 0, "targets": [], "phase": "idle"}
	_move = {}
	_new_counters.clear()
	_support = {}
	_drop_rid = RID()
	_cursor = 0.0
	_in_step = false
	_revision += 1

func view() -> Dictionary:
	var result := _state.duplicate(true)
	result.merge({"slot_id": slot_id, "position": global_position, "velocity": velocity,
		"revision": _revision, "cursor": _cursor, "in_step": _in_step})
	return result

func clear_inputs() -> void:
	_state.buffer_kind = ""
	_state.buffer_steps = 0
	_revision += 1

func prepare_step(input: Dictionary) -> Dictionary:
	if _in_step:
		return _error("step_already_prepared")
	_in_step = true
	_cursor = 0.0
	_new_counters.clear()
	_state.frozen = _state.hit_pause > 0
	if not _state.frozen and _state.pending_launch != Vector2.ZERO:
		velocity = _state.pending_launch
		_state.pending_launch = Vector2.ZERO
	_revision += 1
	# Input owns physical edges. Keeping only the latest press is Character's rule.
	for action in ["jump", "attack", "special"]:
		if input.get(action + "_pressed", false):
			_state.buffer_kind = action
			_state.buffer_steps = BUFFER_STEPS
	if _state.frozen:
		return {"ok": true}
	_refresh_drop()
	var was_grounded: bool = _state.grounded
	var support_query := _find_support()
	if not support_query.ok:
		return support_query
	_support = support_query.support
	_state.grounded = not _support.is_empty()
	if _state.grounded:
		_state.grace_steps = GRACE_STEPS
	elif was_grounded:
		_state.grace_steps = GRACE_STEPS
	var can_act: bool = not _state.committed and _state.hitstun == 0 and not _state.recovery_locked and _state.landing_delay == 0
	if can_act and input.get("down_pressed", false) and _support.get("one_way", false):
		_drop_rid = _support.rid
		_drop_bottom = _support.bottom
		_support = {}
		_state.grounded = false
		_state.grace_steps = 0
	var horizontal := clampf(float(input.get("horizontal", 0.0)), -1.0, 1.0)
	if horizontal != 0 and not _state.committed and not _state.recovery_locked and _state.hitstun == 0:
		_state.facing = 1 if horizontal > 0 else -1
	if can_act and _state.buffer_steps > 0:
		if _state.buffer_kind == "special" and _state.recovery_available:
			_start_attack("recovery_special")
			velocity.y = -_settings.recovery.up_speed
			_state.recovery_available = false
			_state.recovery_locked = true
			_state.grounded = false
			_state.grace_steps = 0
			_state.ground_jump = false
			_state.fast_fall = false
			clear_inputs()
		elif _state.buffer_kind == "attack":
			var direction: String = input.get("attack_direction", "neutral")
			if direction not in ["up", "down"]:
				direction = "neutral"
			_start_attack(("ground_" if _state.grounded else "aerial_") + direction)
			clear_inputs()
		elif _state.buffer_kind == "jump":
			if _state.grounded or _state.grace_steps > 0:
				velocity.y = -_settings.jumping.ground_jump_speed
				_state.ground_jump = true
				_state.grounded = false
				_state.grace_steps = 0
				clear_inputs()
			elif _state.air_jump_available:
				velocity.y = -_settings.jumping.air_jump_speed
				_state.air_jump_available = false
				_state.ground_jump = false
				_state.fast_fall = false
				clear_inputs()
	if _state.ground_jump and velocity.y < 0 and not input.get("jump_held", false):
		velocity.y *= _settings.jumping.jump_release_multiplier
		_state.ground_jump = false
	if _state.hitstun == 0:
		var movement: Dictionary = _settings.movement
		var speed: float = movement.ground_speed if _state.grounded else movement.air_speed
		var acceleration: float = movement.ground_acceleration if _state.grounded else movement.air_acceleration
		if _state.recovery_locked:
			speed = _settings.recovery.air_speed
		elif _state.committed and _state.grounded:
			speed *= movement.ground_attack_speed_multiplier
		if _state.grounded and horizontal == 0:
			acceleration = movement.ground_deceleration
		velocity.x = move_toward(velocity.x, horizontal * speed, acceleration * STEP_SECONDS)
		if input.get("down_pressed", false) and velocity.y > 0 and not _state.grounded:
			_state.fast_fall = true
			velocity.y = _settings.falling.fast_fall_speed
	velocity.y += _settings.falling.gravity * STEP_SECONDS
	if _state.hitstun == 0:
		var cap: float = _settings.falling.fast_fall_speed if _state.fast_fall else _settings.falling.max_fall_speed
		velocity.y = minf(velocity.y, cap)
	return {"ok": true}

func predict_interval(until: float = 1.0) -> Dictionary:
	if not _in_step or until < _cursor or until > 1.0:
		return _error("invalid_prediction_interval")
	var moving_velocity := Vector2.ZERO if _state.frozen else velocity
	var motion := moving_velocity * STEP_SECONDS * (until - _cursor)
	var query := _query(global_transform, motion)
	if not query.ok:
		return query
	var horizon: float = _cursor + (until - _cursor) * query.fraction
	return {"ok": true, "slot_id": slot_id, "revision": _revision, "start": _cursor,
		"until": until, "horizon": horizon, "from": global_transform, "velocity": moving_velocity,
		"motion": motion * query.fraction, "surface": query.contacts,
		"geometry": prepared.geometry(), "facing": _state.facing,
		"frozen": _state.frozen, "combat": combat_snapshot()}

func commit_interval(plan: Dictionary, until: float) -> Dictionary:
	if not plan.get("ok", false) or plan.get("revision", -1) != _revision:
		return _error("stale_plan")
	if plan.slot_id != slot_id or plan.start != _cursor or plan.from != global_transform:
		return _error("plan_origin_mismatch")
	if until < _cursor or until > plan.horizon + TIME_EPSILON:
		return _error("commit_beyond_prediction")
	until = minf(until, plan.horizon)
	var motion: Vector2 = plan.velocity * STEP_SECONDS * (until - _cursor)
	# Repeat the native query from the original pose. The interval ends at a safe
	# fraction, so a shorter native cast must permit this prefix within precision.
	var verified := _query(global_transform, motion)
	if not verified.ok or motion.distance_to(motion * verified.fraction) > POSITION_EPSILON:
		return _error("native_prefix_disagreement", {"motion": motion, "query": verified})
	global_position += motion
	_cursor = until
	_revision += 1
	return {"ok": true, "surface": plan.surface if absf(until - plan.horizon) <= TIME_EPSILON else []}

func apply_event_group(results: Dictionary) -> Dictionary:
	# Match resolves a true combat tie before supplying these surface constraints.
	# This seam also constrains pending launch held during future local hit pause.
	if results.get("being_hit", false):
		clear_inputs()
		_state.fast_fall = false
		_state.ground_jump = false
		_state.recovery_locked = false
		_end_attack()
	if results.get("hit_pause", 0) > 0:
		_state.hit_pause = results.hit_pause
		_state.frozen = true
		_new_counters.hit_pause = true
	if results.has("hitstun"):
		_new_counters.hitstun = true
	if results.has("targets"):
		for target in results.targets:
			if target not in _state.targets:
				_state.targets.append(target)
	if results.has("velocity"):
		velocity = results.velocity
	if results.has("pending_launch"):
		_state.pending_launch = results.pending_launch
	for key in ["hitstun", "damage", "protection"]:
		if results.has(key):
			_state[key] = results[key]
	var contacts: Array = results.get("surface", [])
	var changed := false
	for contact in contacts:
		var normal: Vector2 = contact.normal
		if velocity.dot(normal) < 0:
			velocity = velocity.slide(normal)
			changed = true
		if _state.pending_launch.dot(normal) < 0:
			_state.pending_launch = _state.pending_launch.slide(normal)
			changed = true
		if normal.y < -0.5:
			if _state.move_id.begins_with("aerial_") or _state.move_id == "recovery_special":
				_end_attack()
				_state.landing_delay = 6
				_new_counters.landing_delay = true
			_state.grounded = true
			_state.air_jump_available = true
			_state.recovery_available = true
			_state.recovery_locked = false
			_state.fast_fall = false
			_state.ground_jump = false
			_state.grace_steps = GRACE_STEPS
	if not contacts.is_empty() and not changed and not _state.frozen:
		return _error("non_progressing_surface_group", {"contacts": contacts})
	_revision += 1
	return {"ok": true}

func finish_step() -> Dictionary:
	if not _in_step or _cursor < 1.0 - TIME_EPSILON:
		return _error("incomplete_step")
	if not _state.frozen:
		if _state.committed and not _move.is_empty():
			_state.attack_age += 1
			_update_phase()
		for counter in ["hitstun", "landing_delay", "protection"]:
			if not _new_counters.has(counter):
				_state[counter] = maxi(0, _state[counter] - 1)
		_state.buffer_steps = maxi(0, _state.buffer_steps - 1)
		if _state.buffer_steps == 0:
			_state.buffer_kind = ""
		if not _state.grounded:
			_state.grace_steps = maxi(0, _state.grace_steps - 1)
	if not _new_counters.has("hit_pause"):
		_state.hit_pause = maxi(0, _state.hit_pause - 1)
	_in_step = false
	_revision += 1
	return {"ok": true}

func combat_snapshot() -> Dictionary:
	var result := {"damage": _state.damage, "mass": _settings.mass,
		"vulnerable": _state.protection == 0, "active": _state.phase == "active" and not _state.frozen,
		"attack_id": _state.attack_id, "targets": _state.targets.duplicate(), "move": _move.duplicate(true)}
	if not _move.is_empty():
		result.attack_damage = _settings.attack_damage[_state.move_id]
	return result

func _start_attack(move_id: String) -> void:
	_move = prepared.move(StringName(move_id))
	_next_attack_id += 1
	_state.attack_id = _next_attack_id
	_state.move_id = move_id
	_state.attack_age = 0
	_state.targets = []
	_state.committed = true
	_state.protection = 0
	_update_phase()

func _end_attack() -> void:
	_move = {}
	_state.move_id = ""
	_state.committed = false
	_state.phase = "idle"

func _update_phase() -> void:
	var age: int = _state.attack_age
	if age < _move.startup_steps:
		_state.phase = "startup"
	elif age < _move.startup_steps + _move.active_steps:
		_state.phase = "active"
	elif age < _move.startup_steps + _move.active_steps + _move.recovery_steps:
		_state.phase = "recovery"
	else:
		_end_attack()

func _query(from: Transform2D, motion: Vector2) -> Dictionary:
	if not from.x.is_equal_approx(Vector2.RIGHT) or not from.y.is_equal_approx(Vector2.DOWN):
		return _error("unsupported_character_transform")
	var excluded: Array[RID] = []
	if _drop_rid.is_valid():
		excluded.append(_drop_rid)
	var contacts: Array = []
	var fraction := 1.0
	# Native 2D returns one contact. Exclude each returned static body and cast
	# again to collect all bodies at the earliest horizon, then sort normals.
	for iteration in QUERY_BUDGET:
		var parameters := PhysicsTestMotionParameters2D.new()
		parameters.from = from
		parameters.motion = motion
		parameters.margin = MARGIN
		parameters.exclude_bodies = excluded
		var result := PhysicsTestMotionResult2D.new()
		if not PhysicsServer2D.body_test_motion(get_rid(), parameters, result):
			contacts = contacts.filter(func(contact: Dictionary) -> bool:
				return absf(contact.fraction - fraction) <= TIME_EPSILON)
			contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return a.normal.x < b.normal.x or (a.normal.x == b.normal.x and a.normal.y < b.normal.y))
			return {"ok": true, "fraction": fraction, "contacts": contacts}
		var validation := Arena.validate_surface(result.get_collider())
		if not validation.ok:
			return _error("unsupported_arena_surface", validation)
		# Godot's default motion cast performs a short internal binary search.
		# Refine its native collision predicate from this SAME committed origin;
		# using the raw safe fraction makes the horizon depend on requested length.
		var lower := 0.0
		var upper := 1.0
		for refinement in 26:
			var middle := (lower + upper) * 0.5
			parameters.motion = motion * middle
			var refined := PhysicsTestMotionResult2D.new()
			if PhysicsServer2D.body_test_motion(get_rid(), parameters, refined):
				upper = middle
				result = refined
			else:
				lower = middle
		validation = Arena.validate_surface(result.get_collider())
		if not validation.ok:
			return _error("unsupported_arena_surface", validation)
		var hit_fraction := lower
		if hit_fraction < fraction:
			if fraction - hit_fraction > TIME_EPSILON:
				contacts.clear()
			fraction = hit_fraction
		if absf(hit_fraction - fraction) <= TIME_EPSILON:
			contacts.append({"normal": result.get_collision_normal(), "rid": result.get_collider_rid(),
				"collider": result.get_collider(), "shape": result.get_collider_shape(), "fraction": hit_fraction})
		excluded.append(result.get_collider_rid())
	return _error("native_query_budget_exhausted", {"motion": motion, "contacts": contacts,
		"body_attempts": QUERY_BUDGET, "refinements_per_body": 26})

func _find_support() -> Dictionary:
	if velocity.y < 0:
		return {"ok": true, "support": {}}
	var query := _query(global_transform, Vector2(0, 0.1))
	if not query.ok:
		return query
	for contact in query.contacts:
		if contact.normal.y < -0.5:
			var body := contact.collider as CollisionObject2D
			var shape_node := body.shape_owner_get_owner(body.shape_find_owner(contact.shape)) as CollisionShape2D
			return {"ok": true, "support": {"rid": contact.rid, "one_way": shape_node.one_way_collision,
				"bottom": shape_node.global_position.y + (shape_node.shape as RectangleShape2D).size.y / 2.0}}
	return {"ok": true, "support": {}}

func _refresh_drop() -> void:
	if not _drop_rid.is_valid():
		return
	var surface := get_node("SurfaceShape") as CollisionShape2D
	var top := surface.global_position.y - (surface.shape as RectangleShape2D).size.y / 2.0
	if top > _drop_bottom + MARGIN:
		_drop_rid = RID()

func _error(code: String, details: Dictionary = {}) -> Dictionary:
	return {"ok": false, "error": code, "slot_id": slot_id, "revision": _revision,
		"cursor": _cursor, "position": global_position, "velocity": velocity, "details": details}
