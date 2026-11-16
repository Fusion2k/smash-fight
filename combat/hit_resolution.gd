class_name HitResolution
extends RefCounted
## Resolve an entire contact-time group from pre-group snapshots.
const HIT_PAUSE_STEPS := 3
const MAX_HITSTUN := 60

static func resolve(contacts: Array, before: Dictionary) -> Dictionary:
	var results := {}
	# Stable numeric summation only; all candidates already share eligibility.
	contacts = contacts.duplicate()
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.attacker < b.attacker or (a.attacker == b.attacker and a.target < b.target))
	for hit in contacts:
		if not results.has(hit.attacker):
			results[hit.attacker] = {"hit_pause": HIT_PAUSE_STEPS, "targets": []}
		results[hit.attacker].targets.append(hit.target)
		if not results.has(hit.target):
			results[hit.target] = {"hit_pause": HIT_PAUSE_STEPS, "targets": []}
		var result: Dictionary = results[hit.target]
		result.damage = result.get("damage", before[hit.target].damage) + hit.damage
	for hit in contacts:
		var result: Dictionary = results[hit.target]
		var launch: Vector2 = hit.direction * hit.strength * (1.0 + result.damage / 100.0) / before[hit.target].mass
		result.pending_launch = result.get("pending_launch", Vector2.ZERO) + launch
	for slot in results:
		var result: Dictionary = results[slot]
		if result.has("pending_launch"):
			result.being_hit = true
			result.velocity = Vector2.ZERO
			result.hitstun = mini(MAX_HITSTUN, maxi(1, ceili(result.pending_launch.length() / 30.0)))
	return results
