class_name CharacterCatalog
extends RefCounted
## The sole content-loading boundary. Each call rereads disk, validates all slots,
## and returns either all prepared selections or diagnostics (never fallback stats).

const MOVE_IDS := [&"ground_neutral", &"ground_up", &"ground_down", &"aerial_neutral", &"aerial_up", &"aerial_down", &"recovery_special"]
const SCHEMA := {
	"schema_version": "version", "mass": "positive",
	"movement": {"ground_speed": "positive", "ground_acceleration": "nonnegative", "ground_deceleration": "nonnegative", "ground_attack_speed_multiplier": "fraction", "air_speed": "positive", "air_acceleration": "nonnegative"},
	"jumping": {"ground_jump_speed": "positive", "air_jump_speed": "positive", "jump_release_multiplier": "fraction"},
	"falling": {"gravity": "positive", "max_fall_speed": "positive", "fast_fall_speed": "positive"},
	"recovery": {"up_speed": "positive", "air_speed": "nonnegative"},
	"attack_damage": {"ground_neutral": "nonnegative", "ground_up": "nonnegative", "ground_down": "nonnegative", "aerial_neutral": "nonnegative", "aerial_up": "nonnegative", "aerial_down": "nonnegative", "recovery_special": "nonnegative"}
}

func prepare_match(definitions: Array) -> Dictionary:
	var errors: Array[String] = []
	var prepared: Array[PreparedCharacter] = []
	if definitions.is_empty():
		errors.append("selections: expected at least one character")
	for index in definitions.size():
		var definition = definitions[index]
		if not definition is CharacterDefinition:
			errors.append("selections[%d]: expected CharacterDefinition" % index)
			continue
		var before := errors.size()
		var file: String = definition.tuning_path
		var source: String = definition.resource_path if not definition.resource_path.is_empty() else "selections[%d]" % index
		var settings := _read_settings(file, errors)
		if definition.character_id.is_empty():
			errors.append(source + ": character_id: required")
		if definition.display_name.strip_edges().is_empty():
			errors.append(source + ": display_name: required")
		var moves := _read_moves(definition.moves, source, errors)
		var content := _read_scene(definition.character_scene, source, errors)
		if errors.size() == before:
			prepared.append(PreparedCharacter.new({"character_id": definition.character_id, "display_name": definition.display_name}, settings, moves, content.geometry, content.scene))
	# Atomic selection: even one invalid slot prevents a match from starting.
	if not errors.is_empty():
		prepared.clear()
	return {"ok": errors.is_empty(), "characters": prepared, "errors": errors}

func _read_settings(path: String, errors: Array[String]) -> Dictionary:
	if path.is_empty():
		errors.append("character definition: tuning_path: required JSON file reference")
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("%s: file: cannot read (%s)" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		errors.append("%s: syntax line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return {}
	_validate_object(parser.data, SCHEMA, path + ": ", "", errors)
	if not parser.data is Dictionary:
		return {}
	var data: Dictionary = parser.data
	var falling = data.get("falling")
	if falling is Dictionary and _number(falling.get("max_fall_speed")) and _number(falling.get("fast_fall_speed")):
		if falling.fast_fall_speed <= falling.max_fall_speed:
			errors.append(path + ": falling.fast_fall_speed: must exceed falling.max_fall_speed")
	return data

func _validate_object(value: Variant, schema: Dictionary, file: String, field: String, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append(file + (field if not field.is_empty() else "root") + ": expected object")
		return
	for key in value:
		if not schema.has(key):
			errors.append(file + field + str(key) + ": unknown field")
	for key in schema:
		var name: String = field + key
		if not value.has(key):
			errors.append(file + name + ": required field missing")
		elif schema[key] is Dictionary:
			_validate_object(value[key], schema[key], file, name + ".", errors)
		else:
			var rule: String = schema[key]
			var number = value[key]
			var valid := _number(number)
			if valid:
				match rule:
					"version": valid = number == 1 and floor(number) == number
					"positive": valid = number > 0
					"nonnegative": valid = number >= 0
					"fraction": valid = number >= 0 and number < 1
			if not valid:
				var requirement := "integer schema version 1" if rule == "version" else "finite number (" + rule + ")"
				errors.append(file + name + ": expected " + requirement)

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _read_moves(definitions: Array[MoveDefinition], source: String, errors: Array[String]) -> Dictionary:
	var moves := {}
	for index in definitions.size():
		var move := definitions[index]
		var field := source + ": moves[%d]" % index
		if move == null:
			errors.append(field + ": required MoveDefinition")
			continue
		field += "." + str(move.move_id)
		if not MOVE_IDS.has(move.move_id):
			errors.append(field + ": unknown move_id")
		if moves.has(move.move_id):
			errors.append(field + ": duplicate move_id")
		_validate_shape(move.hitbox, field + ".hitbox", errors)
		if not move.hitbox_offset.is_finite():
			errors.append(field + ".hitbox_offset: expected finite vector")
		if move.startup_steps < 0 or move.active_steps < 1 or move.recovery_steps < 0:
			errors.append(field + ".timing: startup/recovery must be nonnegative integer steps; active must be at least one step")
		if not move.launch_direction.is_finite() or move.launch_direction.is_zero_approx():
			errors.append(field + ".launch_direction: expected finite nonzero vector")
		if not is_finite(move.launch_strength) or move.launch_strength <= 0:
			errors.append(field + ".launch_strength: expected positive finite number")
		moves[move.move_id] = {"hitbox": move.hitbox, "hitbox_offset": move.hitbox_offset, "startup_steps": move.startup_steps, "active_steps": move.active_steps, "recovery_steps": move.recovery_steps, "launch_direction": move.launch_direction.normalized(), "launch_strength": move.launch_strength, "pose_name": move.pose_name}
	for move_id in MOVE_IDS:
		if not moves.has(move_id):
			errors.append(source + ": moves." + str(move_id) + ": required matching editor move missing")
	return moves

func _validate_shape(shape: Shape2D, field: String, errors: Array[String]) -> void:
	if not shape is RectangleShape2D:
		errors.append(field + ": expected RectangleShape2D (fixed translation-only combat geometry)")
	elif not shape.size.is_finite() or shape.size.x <= 0 or shape.size.y <= 0:
		errors.append(field + ".size: expected positive finite dimensions")

func _read_scene(scene: PackedScene, source: String, errors: Array[String]) -> Dictionary:
	var result := {"geometry": {}, "scene": null}
	if scene == null or not scene.can_instantiate():
		errors.append(source + ": character_scene: required instantiable scene")
		return result
	var instance := scene.instantiate()
	if not instance is CharacterBody2D:
		errors.append(source + ": character_scene: root must be CharacterBody2D")
	elif not instance.transform.is_equal_approx(Transform2D.IDENTITY):
		errors.append(source + ": character_scene.transform: root must have identity transform; position belongs to the match")
	var surface := instance.get_node_or_null("SurfaceShape") as CollisionShape2D
	var hurtboxes := instance.get_node_or_null("Hurtboxes")
	if surface == null:
		errors.append(source + ": character_scene.SurfaceShape: required CollisionShape2D")
	else:
		_read_scene_shape(surface, instance, source, result.geometry, errors)
	if hurtboxes == null or hurtboxes.get_child_count() == 0:
		errors.append(source + ": character_scene.Hurtboxes: required nonempty hurtbox container")
	else:
		for child in hurtboxes.get_children():
			if not child is CollisionShape2D:
				errors.append(source + ": character_scene.Hurtboxes: expected CollisionShape2D children")
			else:
				_read_scene_shape(child, instance, source, result.geometry, errors)
	# Pack detached native shapes so saved editor edits cannot change this snapshot.
	PreparedCharacter.copy_scene_shapes(instance)
	var snapshot := PackedScene.new()
	if snapshot.pack(instance) != OK:
		errors.append(source + ": character_scene: could not prepare scene snapshot")
	result.scene = snapshot
	instance.free()
	return result

func _read_scene_shape(node: CollisionShape2D, root: Node, source: String, geometry: Dictionary, errors: Array[String]) -> void:
	var path := str(root.get_path_to(node))
	var field := source + ": character_scene." + path
	_validate_shape(node.shape, field, errors)
	var transform := node.transform
	var parent := node.get_parent() as Node2D
	while parent != root and parent != null:
		transform = parent.transform * transform
		parent = parent.get_parent() as Node2D
	if not transform.origin.is_finite() or not transform.x.is_equal_approx(Vector2.RIGHT) or not transform.y.is_equal_approx(Vector2.DOWN) or node.disabled:
		errors.append(field + ": expected enabled unrotated unscaled shape with finite offset")
	geometry[path] = {"shape": node.shape, "offset": transform.origin}
