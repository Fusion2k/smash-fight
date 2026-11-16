extends RefCounted
## All assertions cross production Match/Character/catalog/native Arena interfaces.
var failures := 0
var checks := 0
var tree: SceneTree
var game: Match
var content: Array = []

func expect(label: String, condition: bool, details: Variant = "") -> void:
	checks += 1
	print("CHECK combat %s expected=true actual=%s %s" % [label, condition, str(details)])
	if not condition:
		failures += 1
		push_error("Combat check failed: " + label)
		print("COMBAT_TRACE ", game.view() if is_instance_valid(game) else details)

func prepared(startup: int = 0, active: int = 1, recovery: int = 2, strength: float = 300.0, duplicate_hurt: bool = false, bramble: bool = false, launch_direction: Vector2 = Vector2(1, -1)) -> PreparedCharacter:
	var definition := load("res://characters/bramble/bramble.tres" if bramble else "res://characters/zip/zip.tres").duplicate(true) as CharacterDefinition
	for move in definition.moves:
		move.startup_steps = startup
		move.active_steps = active
		move.recovery_steps = recovery
		move.launch_direction = launch_direction
		move.launch_strength = strength
	if duplicate_hurt:
		var scene := definition.character_scene.instantiate()
		var shape := scene.get_node("Hurtboxes/Body").duplicate()
		scene.get_node("Hurtboxes").add_child(shape)
		shape.owner = scene
		var packed := PackedScene.new()
		packed.pack(scene)
		definition.character_scene = packed
		scene.free()
	var result := CharacterCatalog.new().prepare_match([definition])
	if not result.ok:
		expect("fixture catalog validates", false, result.errors)
		return null
	return result.characters[0]

func setup(positions: Array, definitions: Array = []) -> void:
	if is_instance_valid(game):
		game.free()
	game = load("res://match/match.tscn").instantiate() as Match
	tree.root.add_child(game)
	var selected := definitions
	if selected.is_empty():
		selected = []
		for at in positions:
			selected.append(content[0])
	var result := game.start({"characters": selected, "positions": positions})
	if not result.ok:
		expect("production composition succeeds", false, result)
	game.arena.ring_out_limits = Rect2(-10000, -10000, 20000, 20000)

func step(frames: Dictionary = {}) -> Dictionary:
	var result := game.step(frames)
	if not result.ok:
		expect("chronological step completes", false, result)
	return result

func repeat(count: int, frames: Dictionary = {}) -> void:
	for index in count:
		if not step(frames).ok:
			return

func hits() -> Array:
	return game.view().events.filter(func(event: Dictionary) -> bool: return event.kind == "hit")

func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	content = [prepared(), prepared(2, 1, 2), prepared(0, 8, 2)]
	await lifecycle()
	await contacts_and_pause()
	await chronology()
	await surfaces()
	await failure_and_resources()
	for fixture in [Vector3(600, 525, 900), Vector3(680, 532, 840)]:
		await calibrated_landing_tie(fixture)
	game.free()
	print("CHECKS_PASSED combat (%d checks)" % checks if failures == 0 else "COMBAT_FAILURES %d" % failures)
	return failures

func lifecycle() -> void:
	# Every move uses real authored geometry/JSON, including unedited content.
	var originals := CharacterCatalog.new().prepare_match([load("res://characters/zip/zip.tres"), load("res://characters/bramble/bramble.tres")])
	for source in originals.characters:
		for prefix in ["ground_", "aerial_"]:
			for direction in ["neutral", "up", "down"]:
				setup([Vector2(640, 560 - source.geometry()["SurfaceShape"].shape.size.y / 2.0 - 0.02) if prefix == "ground_" else Vector2(640, 100)], [source])
				await tree.physics_frame
				step({0: {"attack_pressed": true, "attack_direction": direction, "horizontal": -1}})
				var first := game.characters[0].view()
				expect("%s %s%s selected and facing locked" % [source.identity().character_id, prefix, direction], first.move_id == prefix + direction and first.facing == -1, first)
				step({0: {"attack_pressed": true, "jump_pressed": true, "horizontal": 1, "attack_direction": "up"}})
				var later := game.characters[0].view()
				expect("committed selection/facing/jump preserved", later.move_id == first.move_id and later.facing == -1 and later.air_jump_available)
				repeat(45, {0: {"attack_held": true}})
				expect("held attack never repeats", game.characters[0].view().attack_id == 1 and not game.characters[0].view().committed)
	for source in originals.characters:
		setup([Vector2(640, 100)], [source])
		await tree.physics_frame
		step({0: {"special_pressed": true, "attack_pressed": true, "jump_pressed": true}})
		expect("authored recovery wins press priority", game.characters[0].view().move_id == "recovery_special" and game.characters[0].view().recovery_locked and not game.characters[0].view().recovery_available)
		repeat(35)
		step({0: {"jump_pressed": true, "attack_pressed": true}})
		expect("recovery locks actions after move ends", game.characters[0].view().attack_id == 1 and game.characters[0].view().air_jump_available)
	setup([Vector2(600, 100), Vector2(640, 100)], [content[1], content[0]])
	await tree.physics_frame
	step({0: {"attack_pressed": true}})
	expect("startup interval cannot hit", hits().is_empty())
	step()
	expect("last startup interval cannot hit", hits().is_empty())
	step()
	expect("first active interval hits", hits().size() == 1)
	setup([Vector2(600, 100)])
	await tree.physics_frame
	step({0: {"jump_pressed": true, "attack_pressed": true}})
	expect("ordinary attack wins jump priority", game.characters[0].view().move_id == "aerial_neutral" and game.characters[0].view().air_jump_available)
	var frozen_view := game.view()
	game.set_paused(true)
	step({0: {"special_pressed": true}})
	expect("whole match pause preserves counters and poses", game.view().characters == frozen_view.characters and game.view().step == frozen_view.step)
	game.clear_inputs()
	expect("resume input clearing seam", game.characters[0].view().buffer_steps == 0)

func contacts_and_pause() -> void:
	setup([Vector2(600, 100), Vector2(640, 100), Vector2(1000, 100), Vector2(1100, 100)], [content[2], prepared(0, 1, 2, 300, true), content[0], content[0]])
	await tree.physics_frame
	step({0: {"attack_pressed": true}, 2: {"horizontal": 1}})
	expect("duplicate hurtboxes deduplicated", hits().size() == 1 and game.characters[1].view().damage == 4)
	var struck := game.characters[1].view()
	var attacking := game.characters[0].view()
	expect("damage before launch, mass scaled", absf(struck.pending_launch.length() - 300 * 1.04 / 0.8) < 0.001, struck)
	expect("new counters retained on entry", struck.hit_pause == 3 and struck.hitstun == 13 and struck.velocity == Vector2.ZERO)
	var other_at := game.characters[2].global_position
	step({0: {"jump_pressed": true}, 2: {"horizontal": 1}})
	expect("local freeze while third participant moves", game.characters[0].global_position == attacking.position and game.characters[1].global_position == struck.position and game.characters[2].global_position.x > other_at.x)
	expect("paused action buffers with frozen expiry", game.characters[0].view().buffer_steps == 6 and game.characters[0].view().attack_age == attacking.attack_age and game.characters[1].view().hitstun == struck.hitstun)
	game.characters[2].respawn(attacking.position + Vector2(40, 0))
	step()
	expect("buffer expiry remains frozen", game.characters[0].view().buffer_steps == 6)
	expect("frozen attack cannot hit a newly arriving target", game.characters[2].view().damage == 0 and hits().is_empty())
	# An independent live attacker can strike the vulnerable frozen target later.
	game.characters[3].respawn(struck.position + Vector2(40, 0))
	step({3: {"attack_pressed": true, "horizontal": -1}, 1: {"attack_pressed": true}})
	var rehit := game.characters[1].view()
	expect("later hit resets pause and clears buffer", rehit.damage == 8 and rehit.hit_pause == 3 and rehit.buffer_steps == 0 and rehit.pending_launch.x < 0, rehit)
	var launch: Vector2 = rehit.pending_launch
	game.characters[0].respawn(Vector2(200, 100))
	game.characters[3].respawn(Vector2(1200, 100))
	repeat(3)
	expect("three whole frozen steps retain pending launch", game.characters[1].view().hit_pause == 0 and game.characters[1].global_position == rehit.position and game.characters[1].view().pending_launch == launch)
	step({1: {"horizontal": 1}})
	var released := game.characters[1].view()
	expect("release applies latest launch exactly once without steering", released.pending_launch == Vector2.ZERO and released.velocity.x == launch.x and released.damage == 8 and hits().is_empty(), released)
	step()
	expect("release never restarts hit pause", game.characters[1].view().hit_pause == 0)
	setup([Vector2(600, 100), Vector2(630, 100), Vector2(640, 100), Vector2(645, 100)], [content[2], content[0], content[0], content[0]])
	await tree.physics_frame
	step({0: {"attack_pressed": true}})
	expect("one attack hits three targets", hits().size() == 3 and game.characters[0].view().targets.size() == 3)
	repeat(5)
	expect("history persists across overlap/pause", game.characters[1].view().damage == 4 and game.characters[2].view().damage == 4 and game.characters[3].view().damage == 4)
	# Controlled variants use production resolution, never direct formula-only tests.
	var lengths: Array = []
	var stuns: Array = []
	for variant in 4:
		setup([Vector2(600, 100), Vector2(640, 100)], [prepared(0, 1, 2, 300 if variant < 3 else 10000), prepared(0, 1, 2, 300, false, variant == 2)])
		await tree.physics_frame
		if variant == 1:
			game.characters[1].apply_event_group({"damage": 100.0})
		step({0: {"attack_pressed": true}})
		lengths.append(game.characters[1].view().pending_launch.length())
		stuns.append(game.characters[1].view().hitstun)
	expect("greater damage increases launch and hitstun", lengths[1] > lengths[0] and stuns[1] > stuns[0])
	expect("greater mass reduces equivalent launch", lengths[2] < lengths[0])
	expect("strong launch hitstun capped", stuns[3] == HitResolution.MAX_HITSTUN)

func chronology() -> void:
	# Crossing entirely through a target in a single first-active interval.
	setup([Vector2(500, 100), Vector2(600, 100)])
	await tree.physics_frame
	game.characters[0].apply_event_group({"velocity": Vector2(12000, 0)})
	step({0: {"attack_pressed": true}})
	expect("first-active fast crossing swept", hits().size() == 1 and hits()[0].time > 0 and hits()[0].time < 1)
	setup([Vector2(500, 100), Vector2(600, 100)])
	await tree.physics_frame
	for body in game.characters:
		body.apply_event_group({"velocity": Vector2(12000, 0)})
	step({0: {"attack_pressed": true}})
	expect("parallel equal-speed separation never hits", hits().is_empty())
	setup([Vector2(500, 100), Vector2(600, 100)], [content[1], content[0]])
	await tree.physics_frame
	game.characters[0].apply_event_group({"velocity": Vector2(12000, 0)})
	step({0: {"attack_pressed": true}})
	repeat(2)
	expect("startup crossing never becomes a later sweep", game.characters[1].view().damage == 0 and game.characters[0].view().targets.is_empty())
	setup([Vector2(600, 100), Vector2(1200, 100)])
	await tree.physics_frame
	step({0: {"attack_pressed": true}})
	game.characters[1].respawn(game.characters[0].global_position + Vector2(40, 0))
	step()
	expect("attack recovery interval cannot hit", hits().is_empty() and game.characters[1].view().damage == 0)
	var outcomes: Array = []
	for reverse in [false, true]:
		setup([Vector2(600, 100), Vector2(640, 100)])
		await tree.physics_frame
		if reverse:
			game.characters.reverse()
		step({0: {"attack_pressed": true}, 1: {"attack_pressed": true, "horizontal": -1}})
		var state := {}
		for body in game.characters:
			state[body.slot_id] = [body.view().damage, body.view().pending_launch]
		outcomes.append(state)
		expect("true simultaneous mutual trade", hits().size() == 2 and state[0][0] == 4 and state[1][0] == 4)
	expect("trade invariant under enumeration", outcomes[0] == outcomes[1])
	setup([Vector2(550, 100), Vector2(650, 100), Vector2(600, 100)], [prepared(), prepared(0, 1, 2, 600), content[0]])
	await tree.physics_frame
	game.characters[0].apply_event_group({"velocity": Vector2(600, 0)})
	game.characters[1].apply_event_group({"velocity": Vector2(-600, 0)})
	step({0: {"attack_pressed": true}, 1: {"attack_pressed": true, "horizontal": -1}})
	var unequal: Vector2 = game.characters[2].view().pending_launch
	expect("unequal simultaneous vectors retain their remainder", hits().size() == 2 and unequal.x < 0 and absf(unequal.y - unequal.x * 3) < 0.001 and game.characters[2].view().damage == 8, unequal)
	for delta in [0.0, 0.01, -0.01]:
		for reverse in [false, true]:
			setup([Vector2(550, 100), Vector2(650 + delta, 100), Vector2(600, 100)])
			await tree.physics_frame
			game.characters[0].apply_event_group({"velocity": Vector2(600, 0)})
			game.characters[1].apply_event_group({"velocity": Vector2(-600, 0)})
			if reverse:
				game.characters.reverse()
			step({0: {"attack_pressed": true}, 1: {"attack_pressed": true, "horizontal": -1}})
			var target: Character
			for body in game.characters:
				if body.slot_id == 2:
					target = body
			expect("true/near contacts both apply %s reversed=%s" % [delta, reverse], target.view().damage == 8 and hits().size() == 2, game.view().events)
			if delta == 0:
				expect("simultaneous opposing vectors sum upward", absf(target.view().pending_launch.x) < 0.0001 and target.view().pending_launch.y < -500, target.view())
			else:
				expect("distinct contacts replace later launch", (target.view().pending_launch.x < 0) == (delta > 0) and absf(hits()[0].time - hits()[1].time) > Character.TIME_EPSILON, game.view().events)
	# Earlier hit interrupts another attack before its predicted future contact.
	setup([Vector2(550, 100), Vector2(590, 100), Vector2(650, 100)])
	await tree.physics_frame
	game.characters[1].apply_event_group({"velocity": Vector2(1200, 0)})
	step({0: {"attack_pressed": true}, 1: {"attack_pressed": true}})
	expect("early interruption invalidates future contact", game.characters[1].view().damage == 4 and game.characters[2].view().damage == 0, game.view().events)

func surfaces() -> void:
	setup([Vector2(440, 267.98)])
	await tree.physics_frame
	step({0: {"down_pressed": true, "attack_pressed": true, "attack_direction": "down"}})
	expect("drop eligibility before attack selection", game.characters[0].view().move_id == "aerial_down" and not game.characters[0].view().grounded, game.characters[0].view())
	setup([Vector2(640, 537.98)])
	await tree.physics_frame
	step({0: {"down_pressed": true, "attack_pressed": true, "attack_direction": "down"}})
	expect("solid ground selects ground down", game.characters[0].view().move_id == "ground_down")
	setup([Vector2(640, 535)])
	await tree.physics_frame
	game.characters[0].apply_event_group({"velocity": Vector2(0, 600)})
	step({0: {"attack_pressed": true}})
	expect("landing ends aerial action with full six-step delay", not game.characters[0].view().committed and game.characters[0].view().landing_delay == 6, game.view())
	repeat(6, {0: {"jump_pressed": true}})
	expect("landing delay blocks action through final delayed step", game.characters[0].view().grounded and game.characters[0].view().landing_delay == 0)
	step({0: {"jump_held": true}})
	expect("latest buffered jump starts after landing delay", game.characters[0].velocity.y < 0)
	setup([Vector2(640, 535)])
	await tree.physics_frame
	game.characters[0].apply_event_group({"hitstun": 20, "velocity": Vector2(0, 600)})
	step({0: {"horizontal": 1}})
	expect("landing preserves hitstun", game.characters[0].view().hitstun == 19 and game.characters[0].view().grounded and game.characters[0].velocity.x == 0)
	# A native wall before the potential contact must remove the endpoint chord.
	setup([Vector2(2250, 300), Vector2(2380, 300)])
	game.add_child(load("res://checks/movement_arena.tscn").instantiate())
	await tree.physics_frame
	game.characters[0].apply_event_group({"velocity": Vector2(12000, 0)})
	step({0: {"attack_pressed": true}})
	expect("native wall requery prevents later chord hit", hits().is_empty() and game.characters[0].velocity.x == 0 and game.view().trace.size() >= 2, game.view().trace)
	# Native surface horizon is measured before constructing an exact tie.
	for delta in [0.0, -0.001, 0.001]:
		setup([Vector2(640, 530), Vector2(700, 530)], [prepared(0, 1, 2, 300, false, false, Vector2(1, 1)), content[0]])
		await tree.physics_frame
		var body := game.characters[0]
		body.prepare_step({"attack_pressed": true})
		body.apply_event_group({"velocity": Vector2(0, 600)})
		var plan := body.predict_interval()
		var native_time: float = plan.horizon
		# Restart into the same velocity after preparation's gravity.
		body.respawn(Vector2(640, 530))
		body.apply_event_group({"velocity": Vector2(0, 570)})
		var move: Dictionary = body.prepared.move(&"aerial_neutral")
		var extent: float = move.hitbox.size.x / 2 + 15 + move.hitbox_offset.x
		game.characters[1].respawn(Vector2(700, 530))
		var required_speed: float = (game.characters[1].global_position.x - 640 - extent) * 60 / (native_time + delta)
		game.characters[1].apply_event_group({"velocity": Vector2(-required_speed - 26.6666666667, 570)})
		step({0: {"attack_pressed": true}})
		if delta <= 0:
			expect("hit before/at native landing connects %s" % delta, hits().size() == 1, game.view())
			if delta == 0 and not hits().is_empty():
				expect("measured exact landing tie ends attack after hit", absf(hits()[0].time - native_time) <= Character.TIME_EPSILON and body.view().landing_delay == 6 and not body.view().committed, game.view())
				expect("surface constrains tied pending launch", game.characters[1].view().pending_launch.y == 0 and game.characters[1].view().hitstun > 0, game.characters[1].view())
		else:
			expect("contact after landing rejected", hits().is_empty(), game.view())
	# Ring-out removes eligibility before a tied zero-time hit.
	setup([Vector2(600, 100), Vector2(640, 100)])
	await tree.physics_frame
	game.arena.ring_out_limits = Rect2(0, -180, 600, 1100)
	game.characters[0].apply_event_group({"velocity": Vector2(600, 0)})
	step({0: {"attack_pressed": true}})
	expect("ring-out/combat exact tie removes first", hits().is_empty() and game.view().removed.size() == 2 and game.view().events.size() == 2, game.view().events)

func failure_and_resources() -> void:
	setup([Vector2(640, 530)])
	await tree.physics_frame
	game.event_budget = 1
	game.characters[0].apply_event_group({"velocity": Vector2(0, 600)})
	var failed := game.step()
	expect("budget exhaustion reports incomplete trace", not failed.ok and failed.get("completed", true) == false and failed.error.error == "event_budget_exhausted" and failed.trace.size() == 1 and game.view().step == 0, failed)
	expect("failed match refuses false completion", not game.step().ok)
	game.automatic = true
	var invalid := game.start({})
	expect("invalid restart disables automatic simulation and old feedback", not invalid.ok and not game.automatic and game.view().events.is_empty() and game.view().trace.is_empty())
	# A spent air jump and special remain spent after a genuine incoming hit.
	setup([Vector2(600, 100), Vector2(1200, 100)])
	await tree.physics_frame
	step({0: {"jump_pressed": true, "jump_held": true}})
	step({0: {"special_pressed": true}})
	game.characters[1].respawn(game.characters[0].global_position + Vector2(40, -10))
	step({1: {"attack_pressed": true, "horizontal": -1}})
	var target := game.characters[0].view()
	expect("actual hit clears recovery lock without replenishing resources", target.damage == 4 and not target.recovery_locked and not target.air_jump_available and not target.recovery_available and target.buffer_steps == 0, target)
	# A new attack instance can hit the same opponent again after recovery.
	setup([Vector2(600, 100), Vector2(640, 100)])
	await tree.physics_frame
	step({0: {"attack_pressed": true}})
	var first_id: int = game.characters[0].view().attack_id
	repeat(8)
	game.characters[1].respawn(game.characters[0].global_position + Vector2(40, 0))
	step({0: {"attack_pressed": true}})
	expect("new attack has fresh once-per-target history", game.characters[0].view().attack_id == first_id + 1 and game.characters[1].view().damage == 4 and hits().size() == 1)
	# Protection counts on the character clock and an attack ends it immediately.
	setup([Vector2(600, 100), Vector2(640, 100)])
	await tree.physics_frame
	game.characters[0].apply_event_group({"protection": 120})
	step({1: {"attack_pressed": true, "horizontal": -1}})
	expect("protected target cannot be hit", hits().is_empty() and game.characters[0].view().protection == 119)
	game.characters[1].respawn(Vector2(640, 100))
	step({0: {"attack_pressed": true}, 1: {"attack_pressed": true, "horizontal": -1}})
	expect("starting attack removes protection before contacts", hits().size() == 2 and game.characters[0].view().protection == 0)
	# Multiple native horizons and tangent/separating motion use the same Match loop.
	setup([Vector2(2250, 530)])
	game.add_child(load("res://checks/movement_arena.tscn").instantiate())
	await tree.physics_frame
	game.characters[0].apply_event_group({"hitstun": 30, "velocity": Vector2(6000, 6000)})
	step()
	expect("Match integrates native floor and wall piecewise", game.characters[0].velocity == Vector2.ZERO and game.view().trace.size() >= 3, game.view().trace)
	game.characters[0].apply_event_group({"velocity": Vector2(-300, -300)})
	step()
	expect("separating native corner progresses", game.characters[0].velocity.x < 0 and game.characters[0].velocity.y < 0)
	# Pending launch release is freshly queried against native surfaces.
	setup([Vector2(2250, 300)])
	game.add_child(load("res://checks/movement_arena.tscn").instantiate())
	await tree.physics_frame
	game.characters[0].apply_event_group({"being_hit": true, "hit_pause": 2, "hitstun": 30, "pending_launch": Vector2(6000, 0), "velocity": Vector2.ZERO})
	repeat(2)
	step()
	expect("released pending launch re-queries native wall", game.characters[0].velocity.x == 0 and game.characters[0].global_position.x < 2286.01 and game.view().trace.size() >= 2, game.view().trace)

func calibrated_landing_tie(fixture: Vector3) -> void:
	var origin := Vector2(fixture.x, fixture.y)
	setup([origin, origin + Vector2(60, 0)])
	await tree.physics_frame
	var attacker := game.characters[0]
	attacker.prepare_step({"attack_pressed": true})
	attacker.apply_event_group({"velocity": Vector2(0, fixture.z)})
	var native: Dictionary = attacker.predict_interval()
	var time: float = native.horizon
	attacker.respawn(origin)
	attacker.apply_event_group({"velocity": Vector2(0, fixture.z - 30)})
	var move: Dictionary = attacker.prepared.move(&"aerial_neutral")
	var reach: float = move.hitbox.size.x / 2 + 15 + move.hitbox_offset.x
	var relative_distance: float = game.characters[1].global_position.x - origin.x - reach
	var speed: float = relative_distance * 60 / time
	game.characters[1].apply_event_group({"velocity": Vector2(-speed - 26.6666666667, fixture.z - 30)})
	step({0: {"attack_pressed": true}})
	var actual_time: float = hits()[0].time if not hits().is_empty() else INF
	expect("calibrated native tie at position/speed %s" % fixture, absf(actual_time - time) <= Character.TIME_EPSILON and attacker.view().landing_delay == 6, {"native_time": time, "combat_time": actual_time, "difference": actual_time - time})
