class_name FighterVisual
extends Node2D
## Read-only projection of Character state. No clock, collisions or gameplay writes.
@export var guardian := false
@export var poses: Array[FighterPose] = []
var snapshot := {}
var tint := Color.WHITE

func present(state: Dictionary, player_color: Color, move: Dictionary = {}) -> void:
	snapshot = state.duplicate(true)
	tint = player_color
	# Mirror artwork only; the Character root and all collision shapes stay fixed.
	scale.x = state.facing
	var weapon := get_node("Weapon") as Node2D
	var feet := get_node("Feet") as Node2D
	var attacking: bool = state.phase != "idle"
	weapon.transform = Transform2D(0.3, Vector2(0, -5))
	feet.position.y = 0
	rotation = 0
	if attacking:
		for pose in poses:
			if pose.pose_name == move.get("pose_name", &""):
				match state.phase:
					"startup":
						weapon.transform = pose.startup
						feet.position.y = pose.feet_y.x
					"active":
						weapon.transform = pose.active
						feet.position.y = pose.feet_y.y
					"recovery":
						weapon.transform = pose.recovery
						feet.position.y = pose.feet_y.z
				break
	elif state.hitstun > 0:
		rotation = -0.25
		weapon.rotation = -1.7
	elif not state.grounded:
		feet.position.y = 3
		weapon.rotation = -0.5
	else:
		# Position-driven stride cannot advance during either kind of pause.
		feet.position.y = absf(sin(state.position.x * 0.16)) * minf(absf(state.velocity.x) / 70, 3)
		weapon.rotation = 0.3
	modulate = Color(1.6, 1.6, 1.6) if state.hit_pause > 0 else Color.WHITE
	if state.protection > 0:
		modulate.a = 0.65 + 0.25 * absf(sin(state.protection * 0.13))
	queue_redraw()

func _draw() -> void:
	if snapshot.is_empty():
		return
	var radius := 34.0 if guardian else 27.0
	# Player color is separate from the orange courier / wooden guardian identity.
	draw_arc(Vector2(0, 3), radius, 0.1, PI - 0.1, 20, tint, 3)
	if snapshot.protection > 0:
		draw_arc(Vector2.ZERO, radius + 10, 0, TAU, 40, Color(tint, 0.75), 2)
	if snapshot.phase == "active":
		var angle: float = get_node("Weapon").rotation
		draw_arc(Vector2(2, -5), radius + 5, angle - 0.55, angle + 0.55, 12, Color("fff3bf"), 4)
	if snapshot.move_id == "recovery_special" and snapshot.phase != "idle":
		if guardian:
			for strand in [-1, 0, 1]:
				draw_polyline(PackedVector2Array([Vector2(strand * 7, 24), Vector2(strand * 12, 36), Vector2(strand * 16 + 4, 51)]), Color("a5e5ce"), 3)
		else:
			var points := PackedVector2Array([Vector2(-12, 24), Vector2(-7, 31), Vector2(7, 36), Vector2(-7, 41), Vector2(7, 46), Vector2(0, 53)])
			draw_polyline(points, Color("ffe3a3"), 3)
	if snapshot.hitstun > 0:
		var direction := launch_direction()
		var tip := direction * 70
		draw_line(direction * 32, tip, tint, 4)
		draw_line(tip, tip - direction.rotated(0.55) * 13, tint, 4)
		draw_line(tip, tip - direction.rotated(-0.55) * 13, tint, 4)
		if snapshot.hit_pause > 0:
			for ray in 8:
				var direction2 := Vector2.RIGHT.rotated(ray * TAU / 8)
				draw_line(direction2 * 23, direction2 * 36, Color("fff3bf"), 3)

func launch_direction() -> Vector2:
	var launch: Vector2 = snapshot.pending_launch if snapshot.pending_launch != Vector2.ZERO else snapshot.velocity
	# Full inverse basis preserves world launch through artwork tilt and mirroring.
	return global_transform.affine_inverse().basis_xform(launch).normalized()

func detach_visual_content() -> void:
	var detached: Array[FighterPose] = []
	for pose in poses:
		if pose != null:
			detached.append(pose.duplicate(true) as FighterPose)
	poses = detached

func validate_content(moves: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var names := {}
	for pose in poses:
		if pose == null:
			errors.append("presentation.poses: missing FighterPose Resource")
			continue
		if pose.pose_name.is_empty() or names.has(pose.pose_name):
			errors.append("presentation.poses: expected unique nonempty pose_name")
		names[pose.pose_name] = true
		for artwork in [pose.startup, pose.active, pose.recovery]:
			if not artwork.x.is_finite() or not artwork.y.is_finite() or not artwork.origin.is_finite():
				errors.append("presentation.poses.%s: expected finite artwork transforms" % pose.pose_name)
		if not pose.feet_y.is_finite():
			errors.append("presentation.poses.%s: expected finite feet offsets" % pose.pose_name)
	for move in moves.values():
		if not names.has(move.pose_name):
			errors.append("presentation.poses: missing move pose_name '%s'" % move.pose_name)
	return errors
