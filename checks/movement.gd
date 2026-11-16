extends RefCounted
## Native production Character + prepared content; no parallel movement model.

var failures := 0
var checks := 0
var events: Array = []
var bodies: Array[Character] = []
var world: Node2D

func expect(label: String, condition: bool, details: Variant = "") -> void:
	checks += 1
	print("CHECK movement %s expected=true actual=%s %s" % [label, condition, str(details)])
	if not condition:
		failures += 1
		push_error("Movement check failed: " + label)

func frame(body: Character, input: Dictionary = {}) -> bool:
	var result := body.prepare_step(input)
	if not result.ok:
		return fail_step(result)
	for iteration in 32:
		var plan := body.predict_interval(1.0)
		if not plan.ok:
			return fail_step(plan)
		result = body.commit_interval(plan, plan.horizon)
		if not result.ok:
			return fail_step(result)
		if not result.surface.is_empty():
			events.append({"time": plan.horizon, "slot": plan.slot_id, "revision": plan.revision,
				"position": body.global_position, "velocity": body.velocity, "surface": result.surface})
			result = body.apply_event_group({"surface": result.surface})
			if not result.ok:
				return fail_step(result)
		if plan.horizon == 1.0:
			result = body.finish_step()
			return true if result.ok else fail_step(result)
	return fail_step({"error": "fixture_event_budget", "view": body.view(), "events": events})

func fail_step(result: Dictionary) -> bool:
	expect("native step completes", false, result)
	return false

func repeat(body: Character, count: int, input: Dictionary = {}) -> void:
	for i in count:
		if not frame(body, input):
			return

func reset(body: Character, at: Vector2, motion: Vector2 = Vector2.ZERO) -> void:
	body.respawn(at)
	body.apply_event_group({"velocity": motion})
	events.clear()

func run(tree: SceneTree) -> int:
	world = Node2D.new()
	tree.root.add_child(world)
	var arena := load("res://arenas/first_arena.tscn").instantiate() as Arena
	world.add_child(arena)
	expect("production arena geometry supported", arena.validate_surfaces().ok)
	world.add_child(load("res://checks/movement_arena.tscn").instantiate())
	var content := CharacterCatalog.new().prepare_match([
		load("res://characters/zip/zip.tres"), load("res://characters/bramble/bramble.tres")])
	expect("prepared real content", content.ok, content.errors)
	if not content.ok:
		world.free()
		return failures
	for slot in 4:
		var body := content.characters[slot % 2].instantiate_scene() as Character
		world.add_child(body)
		body.configure(content.characters[slot % 2], slot)
		bodies.append(body)
	await tree.physics_frame
	await tree.process_frame
	var zip := bodies[0]
	var bramble := bodies[1]
	interval_checks(zip)
	movement_checks(zip)
	resource_checks(zip)
	one_way_checks(zip)
	for body in [zip, bramble]:
		reach_checks(body, arena)
	isolation_checks()
	diagnostic_checks(zip)
	expect("arena start/respawn markers", arena.start_positions().size() == 2 and arena.respawn_positions().size() == 2)
	var added_start := Marker2D.new()
	var added_respawn := Marker2D.new()
	arena.get_node("Starts").add_child(added_start)
	arena.get_node("Respawns").add_child(added_respawn)
	expect("arena marker capacity follows authored children", arena.start_positions().size() == 3 and arena.respawn_positions().size() == 3)
	added_start.free()
	added_respawn.free()
	expect("ring-out rectangle edges inclusive", not arena.is_out(Vector2(-160, 0)) and arena.is_out(Vector2(-160.1, 0)))
	world.free()
	print("CHECKS_PASSED movement (%d checks)" % checks if failures == 0 else "MOVEMENT_FAILURES %d" % failures)
	return failures

func interval_checks(body: Character) -> void:
	reset(body, Vector2(2200, 530), Vector2(6000, 6000))
	body.prepare_step({})
	var before := body.view()
	var plan := body.predict_interval()
	var again := body.predict_interval()
	expect("prediction leaves pose/runtime/revision unchanged", body.view() == before)
	expect("repeat native query stable", plan.from == again.from and plan.motion == again.motion and plan.surface == again.surface and plan.revision == again.revision)
	expect("native floor horizon before full endpoint", plan.horizon > 0 and plan.horizon < 1, plan.horizon)
	expect("beyond surface commit rejected", body.commit_interval(plan, 1.0).get("error") == "commit_beyond_prediction")
	var expected_position: Vector2 = body.global_position + plan.velocity * Character.STEP_SECONDS * plan.horizon * 0.5
	var result := body.commit_interval(plan, plan.horizon * 0.5)
	expect("prefix native agreement", result.ok and body.global_position.distance_to(expected_position) < 0.0001, result)
	expect("previous plan becomes stale after prefix", body.commit_interval(plan, plan.horizon).get("error") == "stale_plan")
	plan = body.predict_interval()
	result = body.commit_interval(plan, plan.horizon)
	expect("requery contact prefix native agreement", result.ok, result)
	body.apply_event_group({"surface": result.get("surface", [])})
	var after := body.predict_interval()
	expect("surface requery uses changed velocity", after.velocity.y == 0 and after.horizon > body.view().cursor, after)
	if after.ok:
		body.commit_interval(after, after.horizon)
		if not after.surface.is_empty():
			body.apply_event_group({"surface": after.surface})
	# Each cast stops at the first surface. A complete frame then continues tangent.
	reset(body, Vector2(2250, 530), Vector2(6000, 6000))
	expect("wall/floor piecewise native step", frame(body), events)
	expect("multiple native surfaces stop both components", body.velocity == Vector2.ZERO and events.size() >= 2, events)
	reset(body, Vector2(2270, 300), Vector2(3000, -300))
	expect("wall retains upward tangent", frame(body) and body.velocity.x == 0 and body.velocity.y < 0, events)
	expect("tangent requery progresses", frame(body), events)
	body.apply_event_group({"velocity": Vector2(-300, -300)})
	expect("separating wall motion progresses", frame(body) and body.velocity.x < 0)
	reset(body, Vector2(2000, 230), Vector2(0, -1200))
	expect("native ceiling stops upward motion", frame(body) and body.velocity.y == 0, events)
	for distance in [10.0, 20.0]:
		reset(body, Vector2(2286 - distance, 538 - distance))
		body.prepare_step({})
		# Native single-precision coordinates do not make geometrically equal
		# distances at x=2286/y=538 exact native ties. Calibrate from the two
		# independently measured native horizons, using only production queries.
		var horizontal_speed: float = distance * 120
		var vertical_speed := horizontal_speed
		body.apply_event_group({"velocity": Vector2(horizontal_speed, 0)})
		var wall := body.predict_interval()
		for calibration in 8:
			body.apply_event_group({"velocity": Vector2(0, vertical_speed)})
			var floor_plan := body.predict_interval()
			vertical_speed *= floor_plan.horizon / wall.horizon
		body.apply_event_group({"velocity": Vector2(horizontal_speed, vertical_speed)})
		plan = body.predict_interval()
		print("TRACE native corner distance=%s horizon=%s normals=%s" % [distance, plan.horizon, plan.surface])
		expect("equal measured native corner groups both normals %s" % distance, plan.surface.size() == 2, plan.surface)
		result = body.commit_interval(plan, plan.horizon)
		body.apply_event_group({"surface": result.get("surface", [])})
		expect("corner group stops both axes %s" % distance, result.ok and body.velocity == Vector2.ZERO)
		var next := body.predict_interval()
		expect("corner zero-time requery progresses %s" % distance, next.ok and next.horizon == 1.0)
		reset(body, Vector2(2286 - distance, 538 - distance + 0.02))
		body.prepare_step({})
		body.apply_event_group({"velocity": Vector2(horizontal_speed, vertical_speed)})
		var near := body.predict_interval()
		expect("near native corner remains distinct %s" % distance, near.surface.size() == 1 and near.surface[0].normal == Vector2.UP, near.surface)
	# Prefix subdivision cannot change the collision horizon beyond the selected
	# native spatial precision. Repeat at several native distances/speeds.
	for speed in [120.0, 900.0, 4500.0]:
		reset(body, Vector2(2200, 537.0))
		body.prepare_step({})
		body.apply_event_group({"velocity": Vector2(0, speed)})
		plan = body.predict_interval()
		var full_horizon: float = plan.horizon
		result = body.commit_interval(plan, full_horizon * 0.37)
		var remaining := body.predict_interval()
		var disagreement: float = absf(remaining.horizon - full_horizon) * speed * Character.STEP_SECONDS
		expect("prefix subdivision horizon agreement %s" % speed, result.ok and disagreement < Character.POSITION_EPSILON, disagreement)
	reset(body, Vector2(2100, 400))
	body.prepare_step({})
	plan = body.predict_interval()
	body.apply_event_group({"velocity": Vector2(10, 10)})
	expect("event invalidates plan", body.commit_interval(plan, plan.horizon).get("error") == "stale_plan")
	expect("partial step cannot finish", body.finish_step().get("error") == "incomplete_step")

func movement_checks(body: Character) -> void:
	reset(body, Vector2(640, 510))
	repeat(body, 30)
	expect("native ground resting support", body.view().grounded and absf(body.velocity.y) < 0.001, body.view())
	frame(body, {"horizontal": 0.5})
	expect("ground acceleration once", absf(body.velocity.x - 2200.0 / 60.0) < 0.001, body.velocity)
	repeat(body, 12, {"horizontal": 0.5})
	expect("analog half speed", absf(body.velocity.x - 160) < 0.001)
	repeat(body, 12)
	expect("ground braking", body.velocity.x == 0)
	frame(body, {"horizontal": -1.0})
	expect("movement updates facing", body.view().facing == -1)
	body.apply_event_group({"committed": true})
	repeat(body, 20, {"horizontal": 1.0})
	expect("committed ground speed and facing lock", absf(body.velocity.x - 80) < 0.001 and body.view().facing == -1)
	reset(body, Vector2(640, 100))
	repeat(body, 14, {"horizontal": 1.0})
	expect("air acceleration/speed", absf(body.velocity.x - 300) < 0.001)
	reset(body, Vector2(1100, -100))
	repeat(body, 70)
	expect("gravity caps fall speed", body.velocity.y == 900)
	frame(body, {"down_pressed": true})
	expect("fresh down descending fast-fall", body.view().fast_fall and body.velocity.y == 1400)
	body.apply_event_group({"being_hit": true})
	expect("being hit resets fast-fall", not body.view().fast_fall)
	reset(body, Vector2(640, 200), Vector2(0, -200))
	frame(body, {"down_pressed": true})
	expect("rising down cannot fast-fall", not body.view().fast_fall)
	reset(body, Vector2(1100, -100))
	body.apply_event_group({"velocity": Vector2(0, 5000), "hitstun": 10})
	frame(body)
	expect("ordinary fall cap does not truncate downward launch", body.velocity.y == 5030)

func resource_checks(body: Character) -> void:
	reset(body, Vector2(640, 510))
	repeat(body, 30)
	frame(body, {"jump_pressed": true, "jump_held": true})
	var held_speed := body.velocity.y
	expect("ground jump retains air jump", held_speed == -620 and body.view().air_jump_available)
	frame(body, {"jump_held": false})
	expect("early release cuts ground jump", absf(body.velocity.y - (held_speed * 0.45 + 30)) < 0.001)
	frame(body, {"jump_pressed": true, "jump_held": true})
	expect("one air jump consumed", body.velocity.y == -570 and not body.view().air_jump_available)
	frame(body, {})
	expect("air jump release has fixed height", body.velocity.y == -540)
	frame(body, {"jump_pressed": true})
	expect("second air jump rejected", body.velocity.y == -510)
	frame(body, {"special_pressed": true})
	expect("air recovery consumed/locks actions", not body.view().recovery_available and body.view().recovery_locked and body.velocity.y == -770)
	frame(body, {"jump_pressed": true, "horizontal": 1.0})
	expect("recovery forbids jumping but steers", body.velocity.y == -740 and body.velocity.x > 0)
	repeat(body, 20, {"horizontal": 1.0})
	expect("recovery steering speed", body.velocity.x == 180)
	body.apply_event_group({"being_hit": true, "hitstun": 2})
	expect("hit unlocks without replenishing resources", not body.view().recovery_locked and not body.view().air_jump_available and not body.view().recovery_available)
	var vx := body.velocity.x
	frame(body, {"horizontal": -1.0, "jump_pressed": true})
	expect("hitstun forbids steering/jump", body.velocity.x == vx)
	body.apply_event_group({"hitstun": 0, "velocity": Vector2(0, 900)})
	repeat(body, 100)
	expect("landing replenishes both resources", body.view().air_jump_available and body.view().recovery_available and not body.view().recovery_locked)
	frame(body, {"special_pressed": true})
	expect("ground recovery launches/consumes", body.velocity.y == -770 and not body.view().recovery_available and not body.view().grounded)
	body.respawn(Vector2(640, 100))
	expect("respawn fresh resources/buffers", body.view().air_jump_available and body.view().recovery_available and body.view().buffer_steps == 0)
	frame(body, {"jump_pressed": true, "attack_pressed": true, "special_pressed": true})
	expect("simultaneous buffered priority special before attack/jump", body.view().recovery_locked and body.view().air_jump_available)
	reset(body, Vector2(640, 100))
	body.apply_event_group({"committed": true})
	frame(body, {"jump_pressed": true})
	frame(body, {"attack_pressed": true})
	expect("latest action replaces buffered jump", body.view().buffer_kind == "attack")
	# Buffer threshold: press step plus next five eligible preparations.
	for wait_steps in [5, 6]:
		reset(body, Vector2(640, 100))
		body.apply_event_group({"committed": true})
		frame(body, {"jump_pressed": true, "jump_held": true})
		repeat(body, wait_steps - 1, {"jump_held": true})
		body.apply_event_group({"committed": false})
		frame(body, {"jump_held": true})
		expect("buffer threshold %d" % wait_steps, (body.velocity.y < 0) == (wait_steps == 5), body.view())
	# Leave a real edge, then wait exactly to either side of the grace threshold.
	for wait_steps in [4, 5]:
		reset(body, Vector2(1038, 537.98), Vector2(320, 0))
		# Wait for the first preparation that actually observes lost support;
		# the editor surface shape extends fourteen units beyond the body origin.
		for i in 8:
			frame(body, {"horizontal": 1.0})
			if not body.view().grounded:
				break
		repeat(body, wait_steps - 1, {"horizontal": 1.0})
		frame(body, {"jump_pressed": true, "jump_held": true})
		expect("edge grace threshold %d" % wait_steps, body.view().air_jump_available == (wait_steps == 4), body.view())

func one_way_checks(body: Character) -> void:
	reset(body, Vector2(1800, 500), Vector2(0, -900))
	repeat(body, 17, {"jump_held": true})
	expect("rise through stacked native platforms", body.global_position.y < 330 and body.velocity.y < 0, body.view())
	repeat(body, 70)
	expect("land on upper one-way", body.view().grounded and absf(body.global_position.y - 332) < 0.5, body.view())
	frame(body, {"down_pressed": true, "down_held": true})
	expect("fresh down removes only supporting platform", not body.view().grounded and body.velocity.y > 0)
	repeat(body, 40, {"down_held": true})
	expect("held down lands/stays on lower platform", body.view().grounded and absf(body.global_position.y - 412) < 0.5, body.view())
	body.apply_event_group({"committed": true})
	frame(body, {"down_pressed": true})
	expect("commitment prevents drop", body.view().grounded)
	body.apply_event_group({"committed": false, "hitstun": 2})
	frame(body, {"down_pressed": true})
	expect("hitstun prevents drop", body.view().grounded)
	body.apply_event_group({"hitstun": 0})
	frame(body, {"down_pressed": true})
	repeat(body, 40)
	expect("fresh second down drops lower to solid floor", body.global_position.y > 500 and body.view().grounded)
	frame(body, {"down_pressed": true})
	expect("solid ground never drops", body.view().grounded)

func reach_checks(body: Character, arena: Arena) -> void:
	var name: String = body.prepared.identity().character_id
	for x in [440, 840]:
		reset(body, Vector2(x, 510))
		repeat(body, 30)
		frame(body, {"jump_pressed": true, "jump_held": true})
		repeat(body, 15, {"jump_held": true})
		frame(body, {"jump_pressed": true, "jump_held": true})
		repeat(body, 90, {"jump_held": true})
		expect("%s reaches platform %d" % [name, x], body.view().grounded and body.global_position.y < 400, body.view())
	for side in [-1, 1]:
		var marker: Marker2D = arena.get_node("RecoveryMarkers/%sModest" % ("Left" if side == -1 else "Right"))
		reset(body, marker.global_position)
		frame(body, {"jump_pressed": true, "jump_held": true, "horizontal": -side})
		repeat(body, 12, {"jump_held": true, "horizontal": -side})
		frame(body, {"special_pressed": true, "horizontal": -side})
		repeat(body, 55, {"horizontal": -side})
		repeat(body, 55)
		expect("%s modest recovery side %d" % [name, side], body.view().grounded and body.global_position.y < 560, body.view())
	var deep: Marker2D = arena.get_node("RecoveryMarkers/LeftDeep")
	reset(body, deep.global_position)
	frame(body, {"jump_pressed": true, "jump_held": true, "horizontal": 1})
	repeat(body, 18, {"jump_held": true, "horizontal": 1})
	frame(body, {"special_pressed": true, "horizontal": 1})
	repeat(body, 100, {"horizontal": 1})
	expect("%s deep recovery fails" % name, not body.view().grounded and arena.is_out(body.global_position), body.view())

func isolation_checks() -> void:
	for body in bodies:
		reset(body, Vector2(640, 100))
	var untouched := bodies[2].view()
	frame(bodies[0], {"jump_pressed": true, "jump_held": true, "horizontal": 1})
	expect("same-character runtime independent", bodies[2].view() == untouched)
	expect("four independent native bodies", bodies.size() == 4 and bodies[0].get_rid() != bodies[2].get_rid())
	for body in bodies:
		reset(body, Vector2(640, 200))
		frame(body, {"horizontal": 1})
	expect("characters pass through same pose", bodies[0].global_position == bodies[2].global_position)
	bodies[0].apply_event_group({"frozen": true, "pending_launch": Vector2(0, 300)})
	var at := bodies[0].global_position
	frame(bodies[0], {"jump_pressed": true})
	expect("frozen stationary vulnerable snapshot and frozen buffer", bodies[0].global_position == at and bodies[0].view().buffer_steps == 6)
	bodies[0].apply_event_group({"surface": [{"normal": Vector2.UP}]})
	expect("surface constrains pending launch", bodies[0].view().pending_launch == Vector2.ZERO)

func diagnostic_checks(body: Character) -> void:
	reset(body, Vector2(1200, 100))
	body.prepare_step({})
	body.rotation = 0.1
	expect("runtime rotation rejected", body.predict_interval().get("error") == "unsupported_character_transform")
	body.rotation = 0
	var malformed := StaticBody2D.new()
	world.add_child(malformed)
	for offset in [Vector2.ZERO, Vector2(20, 20)]:
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.position = offset
		malformed.add_child(shape)
	expect("multi-shape static body rejected explicitly", not Arena.validate_surface(malformed).ok)
	malformed.free()
	var unsupported := StaticBody2D.new()
	unsupported.position = Vector2(1200, 132)
	var circle := CollisionShape2D.new()
	circle.shape = CircleShape2D.new()
	unsupported.add_child(circle)
	world.add_child(unsupported)
	reset(body, Vector2(1200, 100))
	var preparation := body.prepare_step({})
	expect("unsupported support fails preparation diagnostically", preparation.get("error") == "unsupported_arena_surface", preparation)
	expect("failed support preparation is incomplete", body.finish_step().get("error") == "incomplete_step")
	unsupported.free()
	var rectangle := StaticBody2D.new()
	var rectangle_shape := CollisionShape2D.new()
	rectangle_shape.shape = RectangleShape2D.new()
	rectangle.add_child(rectangle_shape)
	world.add_child(rectangle)
	for bad_transform in [Transform2D(0.1, Vector2.ZERO), Transform2D(0, Vector2(2, 1), 0, Vector2.ZERO)]:
		rectangle_shape.transform = bad_transform
		expect("rotated/scaled arena shape rejected", not Arena.validate_surface(rectangle).ok)
	rectangle_shape.transform = Transform2D.IDENTITY
	rectangle.constant_linear_velocity = Vector2.RIGHT
	expect("conveyor surface rejected", not Arena.validate_surface(rectangle).ok)
	rectangle.free()
	var moving_surface := AnimatableBody2D.new()
	world.add_child(moving_surface)
	expect("moving arena body rejected", not Arena.validate_surface(moving_surface).ok)
	moving_surface.free()
	var crowded := Node2D.new()
	world.add_child(crowded)
	for index in Character.QUERY_BUDGET:
		var surface := StaticBody2D.new()
		surface.position = Vector2(1200, 150)
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		(shape.shape as RectangleShape2D).size = Vector2(100, 10)
		surface.add_child(shape)
		crowded.add_child(surface)
	reset(body, Vector2(1200, 100))
	body.prepare_step({})
	body.apply_event_group({"velocity": Vector2(0, 3000)})
	var plan := body.predict_interval()
	print("TRACE native budget error=%s slot=%s revision=%s time=%s position=%s velocity=%s attempts=%s contacts=%s" % [
		plan.get("error"), plan.get("slot_id"), plan.get("revision"), plan.get("cursor"),
		plan.get("position"), plan.get("velocity"), plan.get("details", {}).get("body_attempts"),
		plan.get("details", {}).get("contacts", []).size()])
	expect("query budget fails diagnostically with trace", plan.get("error") == "native_query_budget_exhausted" and plan.has("details"), plan.get("error"))
	expect("exhausted query does not commit partial success", body.view().cursor == 0 and body.finish_step().get("error") == "incomplete_step")
	crowded.free()
