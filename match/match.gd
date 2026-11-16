class_name Match
extends Node2D
## Sole gameplay physics callback. Flow may disable automatic stepping for tests.
const EVENT_BUDGET := 128
const EPSILON := Character.TIME_EPSILON

var characters: Array[Character] = []
var arena: Arena
var automatic := false
var event_budget := EVENT_BUDGET
var input_frames := {}
var input_provider: Callable
var _stocks := {}
var _respawns := {}
var _spawn_positions := {}
var _result := {}
var _paused := false
var _removed := {}
var _step_number := 0
var _trace: Array = []
var _events: Array = []
var _failed := false

func start(setup: Dictionary) -> Dictionary:
	automatic = false
	_events = []
	_trace = []
	for body in characters:
		body.free()
	characters.clear()
	if is_instance_valid(arena):
		arena.free()
	_removed.clear()
	_stocks.clear()
	_respawns.clear()
	_spawn_positions.clear()
	_result.clear()
	_step_number = 0
	_failed = true
	_paused = false
	clear_inputs()
	var content: Array = setup.get("characters", [])
	if content.is_empty():
		return {"ok": false, "error": "empty_match"}
	arena = setup.get("arena_scene", preload("res://arenas/first_arena.tscn")).instantiate() as Arena
	add_child(arena)
	var validation := arena.validate_surfaces()
	if not validation.ok:
		return validation
	var positions: Array = setup.get("positions", arena.start_positions())
	var slots: Array = setup.get("slots", range(content.size()))
	var respawn_positions: Array = setup.get("respawn_positions", setup.get("positions", arena.respawn_positions()))
	if respawn_positions.size() < content.size() or positions.size() < content.size() or slots.size() != content.size() or _has_duplicates(slots):
		return {"ok": false, "error": "invalid_match_slots_or_markers"}
	for index in content.size():
		var body := content[index].instantiate_scene() as Character
		add_child(body)
		body.configure(content[index], slots[index])
		body.respawn(positions[index])
		characters.append(body)
		_stocks[body.slot_id] = maxi(1, int(setup.get("stocks", 3)))
		_spawn_positions[body.slot_id] = respawn_positions[index]
	_failed = false
	automatic = setup.get("automatic", false)
	return {"ok": true}

func _physics_process(_delta: float) -> void:
	if automatic:
		var frames: Dictionary = input_provider.call() if input_provider.is_valid() else input_frames
		step(frames)
		# Queued frames are single-use, including fresh action presses.
		input_frames.clear()

func set_paused(value: bool) -> void:
	_paused = value

func clear_inputs() -> void:
	input_frames.clear()
	for body in characters:
		body.clear_inputs()

func view() -> Dictionary:
	var views: Array = []
	for body in characters:
		views.append(body.view())
	return {"step": _step_number, "paused": _paused, "characters": views,
		"stocks": _stocks.duplicate(), "respawns": _respawns.duplicate(), "result": _result.duplicate(true),
		"removed": _removed.duplicate(), "events": _events.duplicate(true), "trace": _trace.duplicate(true), "failed": _failed}

func step(frames: Dictionary = {}) -> Dictionary:
	if _failed:
		return {"ok": false, "error": "match_failed", "trace": _trace}
	if _paused or not _result.is_empty():
		return {"ok": true, "paused": true}
	_events = []
	_trace = []
	_advance_respawns()
	var live: Array[Character] = []
	for body in characters:
		if not _removed.has(body.slot_id):
			live.append(body)
			var result := body.prepare_step(frames.get(body.slot_id, {}))
			if not result.ok:
				return _failure(result)
	var cursor := 0.0
	for iteration in event_budget:
		var plans: Array = []
		var horizon := 1.0
		var ring_times := {}
		for body in live:
			var plan := body.predict_interval()
			if not plan.ok:
				return _failure(plan)
			plans.append(plan)
			horizon = minf(horizon, plan.horizon)
			var ring := _ring_time(plan)
			ring_times[body.slot_id] = ring
			horizon = minf(horizon, ring)
		var group := HitDetection.next_contacts(plans, horizon)
		horizon = minf(horizon, group.time)
		var surfaces := {}
		var before := {}
		for index in live.size():
			var body := live[index]
			before[body.slot_id] = plans[index].combat
			var result := body.commit_interval(plans[index], horizon)
			if not result.ok:
				return _failure(result)
			surfaces[body.slot_id] = result.surface
		var removed_now: Array = []
		for body in live:
			if absf(ring_times[body.slot_id] - horizon) <= EPSILON:
				_removed[body.slot_id] = true
				body.clear_inputs()
				removed_now.append(body.slot_id)
				_events.append({"kind": "ring_out", "slot": body.slot_id, "time": horizon})
		live = live.filter(func(body: Character) -> bool: return not _removed.has(body.slot_id))
		var contacts: Array = group.contacts.filter(func(hit: Dictionary) -> bool:
			return not _removed.has(hit.attacker) and not _removed.has(hit.target))
		var results := HitResolution.resolve(contacts, before)
		var changed := not removed_now.is_empty() or not contacts.is_empty()
		for hit in contacts:
			_events.append({"kind": "hit", "time": horizon, "contact": hit})
		for body in live:
			var result: Dictionary = results.get(body.slot_id, {})
			if not surfaces[body.slot_id].is_empty():
				result.surface = surfaces[body.slot_id]
				changed = true
			if not result.is_empty():
				var applied := body.apply_event_group(result)
				if not applied.ok:
					return _failure(applied)
		var states: Array = []
		for body in live:
			states.append(body.view())
		_trace.append({"time": horizon, "states": states, "contacts": contacts, "surfaces": surfaces, "removed": removed_now})
		if horizon >= 1.0:
			for body in live:
				var finished := body.finish_step()
				if not finished.ok:
					return _failure(finished)
			_complete_stocks()
			_step_number += 1
			return {"ok": true, "events": _events.duplicate(true)}
		if horizon <= cursor and not changed:
			return _failure({"error": "non_progressing_event"})
		cursor = horizon
	return _failure({"error": "event_budget_exhausted"})

func _ring_time(plan: Dictionary) -> float:
	var point: Vector2 = plan.from.origin
	if arena.is_out(point):
		return plan.start
	var speed: Vector2 = plan.velocity * Character.STEP_SECONDS
	var time := INF
	for axis in 2:
		if speed[axis] > 0:
			time = minf(time, plan.start + (arena.ring_out_limits.end[axis] - point[axis]) / speed[axis])
		elif speed[axis] < 0:
			time = minf(time, plan.start + (arena.ring_out_limits.position[axis] - point[axis]) / speed[axis])
	return time if time <= plan.horizon else INF

func _failure(details: Dictionary) -> Dictionary:
	_failed = true
	return {"ok": false, "error": details, "trace": _trace.duplicate(true), "completed": false}

func _has_duplicates(values: Array) -> bool:
	var seen := {}
	for value in values:
		if seen.has(value):
			return true
		seen[value] = true
	return false

func _advance_respawns() -> void:
	for slot in _respawns.keys():
		_respawns[slot] -= 1
		if _respawns[slot] == 0:
			for body in characters:
				if body.slot_id == slot:
					body.respawn(_spawn_positions[slot])
					body.grant_protection(120)
			_respawns.erase(slot)
			_removed.erase(slot)
			_events.append({"kind": "respawn", "slot": slot})

func _complete_stocks() -> void:
	# Only after EVERY chronological ring-out in the completed step.
	var lost := false
	for event in _events.duplicate():
		if event.kind == "ring_out":
			var slot: int = event.slot
			_stocks[slot] = maxi(0, _stocks[slot] - 1)
			lost = true
			if _stocks[slot] > 0:
				_respawns[slot] = 60
			_events.append({"kind": "stock_lost", "slot": slot, "stocks": _stocks[slot]})
	if lost:
		var survivors: Array = _stocks.keys().filter(func(slot: int) -> bool: return _stocks[slot] > 0)
		if survivors.size() <= 1:
			_result = {"draw": survivors.is_empty(), "winner": survivors[0] if not survivors.is_empty() else -1}
			_events.append({"kind": "result", "result": _result.duplicate()})
