extends RefCounted
## Actual simulation to presentation seam; no golden colors or art assertions.
var failures := 0
var checks := 0
func expect(label: String, passed: bool) -> void:
	checks += 1
	print("CHECK presentation %s actual=%s" % [label, passed])
	if not passed:
		failures += 1
		push_error(label)

func run(tree: SceneTree) -> int:
	var prepared := CharacterCatalog.new().prepare_match([load("res://characters/zip/zip.tres"), load("res://characters/bramble/bramble.tres")])
	var authored_scene := load("res://characters/zip/zip.tscn").instantiate() as Character
	var source_pose: FighterPose = authored_scene.get_node("Visual").poses[0]
	var saved_pose := source_pose.startup
	source_pose.startup = Transform2D(0.6, Vector2(80, 80))
	var first := prepared.characters[0].instantiate_scene() as Character
	var second := prepared.characters[0].instantiate_scene() as Character
	var first_pose: FighterPose = first.get_node("Visual").poses[0]
	var second_pose: FighterPose = second.get_node("Visual").poses[0]
	expect("prepared artwork survives source Resource edit", first_pose.startup == saved_pose)
	first_pose.startup = Transform2D(0.8, Vector2(120, 120))
	expect("same-character pose Resources independent", second_pose.startup == saved_pose)
	var third := prepared.characters[0].instantiate_scene() as Character
	expect("instance edit cannot mutate prepared artwork", third.get_node("Visual").poses[0].startup == saved_pose)
	expect("instance edit cannot mutate source artwork", source_pose.startup == Transform2D(0.6, Vector2(80, 80)))
	source_pose.startup = saved_pose
	for instance in [authored_scene, first, second, third]:
		instance.free()
	var broken_definition := load("res://characters/zip/zip.tres").duplicate() as CharacterDefinition
	var broken_scene := load("res://characters/zip/zip.tscn").instantiate() as Character
	broken_scene.get_node("Visual").poses.remove_at(0)
	var packed := PackedScene.new()
	packed.pack(broken_scene)
	broken_definition.character_scene = packed
	var rejected := CharacterCatalog.new().prepare_match([broken_definition])
	expect("missing editor pose prevents match with useful diagnostic", not rejected.ok and str(rejected.errors).contains("missing move pose_name"))
	broken_scene.free()
	var game := Match.new()
	tree.root.add_child(game)
	game.start({"characters": prepared.characters, "positions": [Vector2(500, 538), Vector2(900, 530)]})
	await tree.physics_frame
	for settle in 4:
		game.step()
	for index in 2:
		var body := game.characters[index]
		var visual := body.get_node("Visual") as FighterVisual
		var original := body.view()
		visual.present(original, Color.CYAN, body.prepared.move(StringName(original.move_id)))
		visual.present(original, Color.CYAN, body.prepared.move(StringName(original.move_id)))
		expect("projection leaves gameplay untouched %d" % index, body.view() == original)
		var poses := {}
		for tick in 50:
			game.step({body.slot_id: {"attack_pressed": tick == 0, "horizontal": -1 if tick > 0 else 1}})
			var state := body.view()
			visual.present(state, Color.CYAN, body.prepared.move(StringName(state.move_id)))
			if state.phase != "idle":
				poses[state.phase] = visual.get_node("Weapon").transform
				if not poses.has("facing_checked"):
					expect("art and combat facing agree %d" % index, visual.scale.x == state.facing)
					poses["facing_checked"] = true
				if state.phase == "active":
					var held: Transform2D = visual.get_node("Weapon").transform
					game.set_paused(true)
					game.step({body.slot_id: {"special_pressed": true}})
					visual.present(body.view(), Color.CYAN, body.prepared.move(StringName(body.view().move_id)))
					expect("full pause holds pose %d" % index, visual.get_node("Weapon").transform == held)
					game.set_paused(false)
		expect("all attack phases presented %d" % index, poses.has("startup") and poses.has("active") and poses.has("recovery"))
		expect("startup active recovery visibly differ %d" % index, poses.startup != poses.active and poses.active != poses.recovery)
		body.apply_event_group({"hit_pause": 3})
		game.step()
		visual.present(body.view(), Color.CYAN, body.prepared.move(StringName(body.view().move_id)))
		var held := visual.transform
		var weapon: Transform2D = visual.get_node("Weapon").transform
		game.step()
		visual.present(body.view(), Color.CYAN, body.prepared.move(StringName(body.view().move_id)))
		expect("local hit pause holds artwork %d" % index, visual.transform == held and visual.get_node("Weapon").transform == weapon)
		for facing in [-1, 1]:
			var struck := body.view()
			struck.facing = facing
			struck.hitstun = 12
			struck.pending_launch = Vector2(250, -180)
			struck.phase = "idle"
			visual.present(struck, Color.CYAN)
			var world_direction := visual.global_transform.basis_xform(visual.launch_direction()).normalized()
			expect("launch arrow preserves world direction facing %d character %d" % [facing, index], world_direction.is_equal_approx(struck.pending_launch.normalized()))
		var authored := FighterPose.new()
		authored.pose_name = &"custom_editor_pose"
		authored.active = Transform2D(0.77, Vector2(12, -19))
		visual.poses.append(authored)
		var projected := body.view()
		projected.phase = "active"
		var unchanged := body.view()
		visual.present(projected, Color.CYAN, {"pose_name": &"custom_editor_pose"})
		expect("move pose_name selects editor Resource %d" % index, visual.get_node("Weapon").transform == authored.active)
		expect("editor artwork change leaves gameplay untouched %d" % index, body.view() == unchanged)
		expect("art never transforms collision root %d" % index, body.scale == Vector2.ONE and body.rotation == 0)
	game.free()
	if failures == 0:
		print("CHECKS_PASSED presentation (%d checks)" % checks)
	return failures
