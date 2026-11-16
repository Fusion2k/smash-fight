class_name HitDetection
extends RefCounted
## Swept rectangles from real native motion plans, restricted to their safe prefix.
const EPSILON := Character.TIME_EPSILON

static func next_contacts(plans: Array, until: float) -> Dictionary:
	var earliest := until
	var contacts: Array = []
	for attack in plans:
		if not attack.combat.active:
			continue
		var move: Dictionary = attack.combat.move
		var offset: Vector2 = move.hitbox_offset
		offset.x *= attack.facing
		var center: Vector2 = attack.from.origin + offset
		for target in plans:
			if target.slot_id == attack.slot_id or not target.combat.vulnerable or target.slot_id in attack.combat.targets:
				continue
			var first := INF
			for path in target.geometry:
				if not str(path).begins_with("Hurtboxes/"):
					continue
				var hurt: Dictionary = target.geometry[path]
				var half: Vector2 = (move.hitbox.size + hurt.shape.size) * 0.5
				var relative: Vector2 = center - (target.from.origin + hurt.offset)
				var speed: Vector2 = (attack.velocity - target.velocity) * Character.STEP_SECONDS
				var time := _sweep(relative, speed, half, until - attack.start)
				first = minf(first, attack.start + time)
			if first == INF:
				continue
			if first < earliest - EPSILON:
				earliest = first
				contacts.clear()
			if absf(first - earliest) <= EPSILON:
				contacts.append({"attacker": attack.slot_id, "target": target.slot_id,
					"attack_id": attack.combat.attack_id, "damage": attack.combat.attack_damage,
					"direction": Vector2(move.launch_direction.x * attack.facing, move.launch_direction.y),
					"strength": move.launch_strength})
	return {"time": earliest, "contacts": contacts}

static func _sweep(origin: Vector2, speed: Vector2, half: Vector2, duration: float) -> float:
	var enter := 0.0
	var leave := duration
	for axis in 2:
		if speed[axis] == 0:
			if absf(origin[axis]) > half[axis]:
				return INF
		else:
			var a: float = (-half[axis] - origin[axis]) / speed[axis]
			var b: float = (half[axis] - origin[axis]) / speed[axis]
			enter = maxf(enter, minf(a, b))
			leave = minf(leave, maxf(a, b))
			if enter > leave:
				return INF
	return enter if enter <= duration and leave >= 0 else INF
