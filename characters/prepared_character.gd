class_name PreparedCharacter
extends RefCounted
## Read-only public interface. Getters return detached containers/native shapes.
## No live Character state belongs here. Do not access underscore storage directly.

var _settings: Dictionary
var _moves: Dictionary
var _geometry: Dictionary
var _scene: PackedScene
var _identity: Dictionary

func _init(identity: Dictionary, settings: Dictionary, moves: Dictionary, geometry: Dictionary, scene: PackedScene) -> void:
	_identity = identity.duplicate(true)
	_settings = settings.duplicate(true)
	_moves = _copy_shapes(moves)
	_geometry = _copy_shapes(geometry)
	_scene = scene

func identity() -> Dictionary:
	return _identity.duplicate(true)

func settings() -> Dictionary:
	return _settings.duplicate(true)

func move(move_id: StringName) -> Dictionary:
	return _copy_shapes(_moves.get(move_id, {}))

func geometry() -> Dictionary:
	return _copy_shapes(_geometry)

func instantiate_scene() -> CharacterBody2D:
	var instance := _scene.instantiate() as CharacterBody2D
	copy_scene_shapes(instance)
	return instance

static func copy_scene_shapes(node: Node) -> void:
	# Snapshot/instance boundary: visuals detach their own editor Resources.
	if node is FighterVisual:
		node.detach_visual_content()
	if node is CollisionShape2D and node.shape != null:
		node.shape = node.shape.duplicate(true)
	for child in node.get_children():
		copy_scene_shapes(child)

static func _copy_shapes(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	for key in result:
		if result[key] is Shape2D:
			result[key] = result[key].duplicate(true)
		elif result[key] is Dictionary:
			result[key] = _copy_shapes(result[key])
	return result
