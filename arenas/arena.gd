class_name Arena
extends Node2D

@export var ring_out_limits := Rect2(-160, -180, 1600, 1100)

func is_out(point: Vector2) -> bool:
	return point.x < ring_out_limits.position.x or point.x > ring_out_limits.end.x or point.y < ring_out_limits.position.y or point.y > ring_out_limits.end.y

func start_positions() -> Array[Vector2]:
	return _marker_positions($Starts)

func respawn_positions() -> Array[Vector2]:
	return _marker_positions($Respawns)

func _marker_positions(container: Node) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for child in container.get_children():
		if child is Marker2D:
			positions.append(child.global_position)
	return positions

func validate_surfaces() -> Dictionary:
	for body in find_children("*", "CollisionObject2D", true, false):
		var result := validate_surface(body)
		if not result.ok:
			return result
	return {"ok": true}

static func validate_surface(body: CollisionObject2D) -> Dictionary:
	# Native 2D reports a single shape per body. One rectangle per static body
	# lets Character gather a corner's complete normal set by excluding bodies.
	if body == null:
		return {"ok": false, "error": "unsupported_arena_surface", "expected": "scene-owned StaticBody2D"}
	var owners := body.get_shape_owners()
	if body is StaticBody2D and body.constant_linear_velocity == Vector2.ZERO and body.constant_angular_velocity == 0 and owners.size() == 1 and body.shape_owner_get_shape_count(owners[0]) == 1:
		var shape := body.shape_owner_get_owner(owners[0]) as CollisionShape2D
		if shape != null and shape.shape is RectangleShape2D and not shape.disabled:
			var pose := shape.global_transform
			if pose.x.is_equal_approx(Vector2.RIGHT) and pose.y.is_equal_approx(Vector2.DOWN):
				return {"ok": true}
	return {"ok": false, "error": "unsupported_arena_surface", "path": str(body.get_path()),
		"expected": "one enabled axis-aligned unscaled RectangleShape2D per stationary StaticBody2D"}
