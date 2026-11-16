extends SceneTree
## Exercise the production boundary with real Resources, native shapes and disk IO.

var failures := 0
var checks := 0
var catalog := CharacterCatalog.new()
var zip: CharacterDefinition = load("res://characters/zip/zip.tres")
var bramble: CharacterDefinition = load("res://characters/bramble/bramble.tres")
var fixture_path := "user://catalog-check.physics.json"

func expect(label: String, condition: bool) -> void:
	checks += 1
	print("CHECK catalog %s expected=true actual=%s" % [label, condition])
	if not condition:
		failures += 1
		push_error("Check failed: " + label)

func has_error(result: Dictionary, fragment: String) -> bool:
	for message in result.errors:
		if fragment in message:
			return true
	return false

func write_text(content: String) -> void:
	var file := FileAccess.open(fixture_path, FileAccess.WRITE)
	file.store_string(content)

func fixture(data: Variant) -> CharacterDefinition:
	write_text(JSON.stringify(data))
	var definition := detached_definition()
	definition.tuning_path = fixture_path
	return definition

func detached_definition() -> CharacterDefinition:
	# Resource.duplicate(true) alone does not detach external Resources in arrays.
	var definition := zip.duplicate() as CharacterDefinition
	definition.moves = []
	for move in zip.moves:
		var copy := move.duplicate() as MoveDefinition
		copy.hitbox = move.hitbox.duplicate(true)
		definition.moves.append(copy)
	return definition

func _initialize() -> void:
	var valid := catalog.prepare_match([zip, bramble, zip])
	expect("both authored pairs and repeated selection prepare", valid.ok and valid.characters.size() == 3)
	if not valid.ok:
		print(valid.errors)
		quit(1)
		return
	var first: PreparedCharacter = valid.characters[0]
	var second: PreparedCharacter = valid.characters[2]
	var original := first.settings()
	var original_move := first.move(&"ground_neutral")
	var original_size: Vector2 = original_move.hitbox.size
	var detached := first.settings()
	detached.mass = 999
	detached.attack_damage.ground_neutral = 999
	var detached_move := first.move(&"ground_neutral")
	detached_move.hitbox.size = Vector2(999, 999)
	detached_move.active_steps = 999
	var detached_geometry := first.geometry()
	detached_geometry["SurfaceShape"].shape.size = Vector2(999, 999)
	expect("settings getters cannot alter active snapshot", first.settings() == original)
	expect("move getter shape and timing isolation", first.move(&"ground_neutral").hitbox.size == original_size and first.move(&"ground_neutral").active_steps == original_move.active_steps)
	expect("same-definition selections have independent snapshot containers", first != second and second.move(&"ground_neutral").hitbox.size == original_size and second.settings() == original)
	expect("geometry getter cannot alter snapshot", first.geometry()["SurfaceShape"].shape.size != Vector2(999, 999))
	expect("authored move shape unchanged", zip.moves[0].hitbox.size == original_size)
	var scene_a := first.instantiate_scene()
	var scene_b := second.instantiate_scene()
	var scene_old_size: Vector2 = scene_b.get_node("SurfaceShape").shape.size
	scene_a.get_node("SurfaceShape").shape.size = Vector2(777, 777)
	scene_a.get_node("Hurtboxes/Body").shape.size = Vector2(777, 777)
	expect("scene instances have independent native collision shapes", scene_b.get_node("SurfaceShape").shape.size == scene_old_size and scene_b.get_node("Hurtboxes/Body").shape.size != Vector2(777, 777))
	var authored := zip.character_scene.instantiate()
	expect("authored scene shape unchanged", authored.get_node("SurfaceShape").shape.size == scene_old_size)
	authored.free()
	scene_a.free()
	scene_b.free()

	var definition := fixture(original)
	var active := catalog.prepare_match([definition, bramble])
	var changed := original.duplicate(true)
	changed.mass = 1.1
	changed.attack_damage.ground_neutral = 12
	write_text(JSON.stringify(changed))
	var fresh := catalog.prepare_match([definition, bramble])
	expect("saved JSON reread without restart", fresh.ok and fresh.characters[0].settings().mass == 1.1 and fresh.characters[0].settings().attack_damage.ground_neutral == 12)
	expect("active settings retain original mass and damage", active.characters[0].settings() == original)
	expect("Bramble unaffected by Zip tuning", active.characters[1].settings() == fresh.characters[1].settings())
	var invalid := changed.duplicate(true)
	invalid.mass = -1
	invalid.movement.erase("air_speed")
	invalid.movement.air_speeed = 10
	invalid.attack_damage.ground_up = true
	invalid.falling.fast_fall_speed = invalid.falling.max_fall_speed
	invalid.hitbox = {"width": 100}
	definition = fixture(invalid)
	definition.moves[0].active_steps = 0
	definition.moves[1].hitbox = CircleShape2D.new()
	definition.moves[2].move_id = &"not_a_move"
	definition.moves[3].launch_direction = Vector2.ZERO
	definition.moves[4].launch_strength = INF
	definition.moves[5].hitbox_offset = Vector2(INF, 0)
	definition.moves[6] = definition.moves[0]
	var result := catalog.prepare_match([definition, bramble])
	expect("invalid selection returns no spawnable partial result", not result.ok and result.characters.is_empty())
	for fragment in ["mass:", "movement.air_speed:", "movement.air_speeed:", "attack_damage.ground_up:", "falling.fast_fall_speed:", "hitbox: unknown", ".timing:", ".hitbox: expected Rectangle", "unknown move_id", "duplicate move_id", "required matching editor move missing", ".launch_direction:", ".launch_strength:", ".hitbox_offset:"]:
		expect("aggregate diagnostic " + fragment, has_error(result, fragment))
	expect("diagnostics identify tuning file", has_error(result, fixture_path + ": mass:"))

	for version in [true, 2, 1.5, "1", null]:
		var data := original.duplicate(true)
		data.schema_version = version
		expect("unsupported/non-number version " + str(version), has_error(catalog.prepare_match([fixture(data)]), "schema_version:"))
	for value in [true, "320", null, -1]:
		var data := original.duplicate(true)
		data.movement.ground_speed = value
		expect("invalid physics numeric " + str(value), has_error(catalog.prepare_match([fixture(data)]), "movement.ground_speed:"))
	for field in ["mass", "movement", "attack_damage", "schema_version"]:
		var data := original.duplicate(true)
		data.erase(field)
		expect("required object/leaf " + field, has_error(catalog.prepare_match([fixture(data)]), field + ": required"))
	for data in [[], true, null]:
		expect("root object required " + str(data), has_error(catalog.prepare_match([fixture(data)]), "root: expected object"))
	var malformed := fixture(original)
	write_text("{\n\"mass\": , }")
	result = catalog.prepare_match([malformed])
	expect("syntax reports file and line", has_error(result, fixture_path + ": syntax line"))
	write_text(JSON.stringify(original).replace('"mass":0.8', '"mass":1e999'))
	expect("overflow/nonfinite JSON number rejected", not catalog.prepare_match([malformed]).ok)
	DirAccess.remove_absolute(fixture_path)
	expect("absent file fails usefully", has_error(catalog.prepare_match([malformed]), "file: cannot read"))
	malformed.tuning_path = "res://characters"
	expect("unreadable directory fails usefully", not catalog.prepare_match([malformed]).ok)
	malformed.tuning_path = fixture_path
	write_text(JSON.stringify(original))
	expect("corrected file retries successfully", catalog.prepare_match([malformed]).ok)

	# Corrupt native editor content through a detached scene, preserving authored data.
	var bad_scene := zip.character_scene.instantiate()
	bad_scene.scale = Vector2(2, 1)
	bad_scene.get_node("SurfaceShape").rotation = 0.5
	bad_scene.get_node("Hurtboxes/Body").shape = CircleShape2D.new()
	var packed := PackedScene.new()
	packed.pack(bad_scene)
	bad_scene.free()
	malformed.character_scene = packed
	result = catalog.prepare_match([malformed])
	expect("root transform rejected", has_error(result, "character_scene.transform:"))
	expect("scene rotation rejected", has_error(result, "SurfaceShape: expected enabled unrotated"))
	expect("scene hurtbox geometry rejected", has_error(result, "Hurtboxes/Body: expected Rectangle"))
	malformed.character_scene = null
	expect("missing scene rejected", has_error(catalog.prepare_match([malformed]), "character_scene:"))
	malformed = fixture(original)
	malformed.tuning_path = ""
	expect("missing Inspector JSON reference rejected", has_error(catalog.prepare_match([malformed]), "tuning_path:"))
	expect("empty selection rejected", not catalog.prepare_match([]).ok)
	expect("absent definition rejected", not catalog.prepare_match([null]).ok)

	# Editor edits are reflected on next prepare, never in an existing snapshot.
	var edited := detached_definition()
	var before_edit := catalog.prepare_match([edited])
	var edit_scene := edited.character_scene.instantiate()
	var authored_scene_size: Vector2 = edit_scene.get_node("SurfaceShape").shape.size
	# Change the actual referenced Resource after preparation, then restore it.
	edit_scene.get_node("SurfaceShape").shape.size = Vector2(40, 50)
	edited.moves[0].hitbox.size = Vector2(51, 19)
	edited.moves[0].active_steps = 1
	var edit_result := catalog.prepare_match([edited])
	expect("editor shape/timing edits visible next preparation", edit_result.ok and edit_result.characters[0].move(&"ground_neutral").hitbox.size == Vector2(51, 19) and edit_result.characters[0].move(&"ground_neutral").active_steps == 1)
	expect("source move Resource edits cannot change prepared data", before_edit.characters[0].move(&"ground_neutral").hitbox.size == original_size)
	var old_scene: CharacterBody2D = before_edit.characters[0].instantiate_scene()
	var new_scene: CharacterBody2D = edit_result.characters[0].instantiate_scene()
	expect("source scene shape edits apply only on next prepare", old_scene.get_node("SurfaceShape").shape.size == authored_scene_size and new_scene.get_node("SurfaceShape").shape.size == Vector2(40, 50))
	edit_scene.get_node("SurfaceShape").shape.size = authored_scene_size
	edit_scene.free()
	old_scene.free()
	new_scene.free()
	expect("active snapshot stable after editor edits", first.move(&"ground_neutral").hitbox.size == original_size and first.move(&"ground_neutral").active_steps == original_move.active_steps)
	expect("authored definition stays intact after detached edits", zip.moves[0].hitbox.size == original_size)
	DirAccess.remove_absolute(fixture_path)
	if failures:
		quit(1)
	else:
		print("CHECKS_PASSED catalog (%d checks)" % checks)
		quit(0)
