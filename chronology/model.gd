extends RefCounted
# THROWAWAY: positions/velocities are pixels per one normalized 60 Hz step.
const TIE_EPS = 0.0000001
const HALF = Vector2(1, 1)

static func body(id: String, p: Vector2, v: Vector2, launch := Vector2.ZERO, damage := 0.0) -> Dictionary:
	return {"id":id, "p":p, "v":v, "launch":launch, "attack_damage":damage, "damage":0.0, "active":damage > 0, "start":0.0, "end":1.0, "history":[], "paused":false}

static func entry(a: Dictionary, b: Dictionary, duration: float) -> float:
	var p: Vector2 = a.p - b.p
	var v: Vector2 = a.v - b.v
	var lo := 0.0
	var hi := duration
	for axis in range(2):
		if abs(v[axis]) < 1e-12:
			if abs(p[axis]) > 2.0: return INF
		else:
			var first: float = (-2.0 - p[axis]) / v[axis]
			var last: float = (2.0 - p[axis]) / v[axis]
			lo = max(lo, min(first, last))
			hi = min(hi, max(first, last))
	if lo > hi or hi < 0.0: return INF
	return lo

static func candidates(bs: Array, now: float, until: float) -> Array:
	var out := []
	for a in bs:
		if not a.active or a.paused: continue
		for b in bs:
			if a.id == b.id or b.id in a.history: continue
			var begin: float = max(now, a.start)
			var finish: float = min(until, a.end)
			if begin >= finish: continue
			var aa: Dictionary = a.duplicate(true)
			var bb: Dictionary = b.duplicate(true)
			aa.p += a.v * (begin - now)
			bb.p += b.v * (begin - now)
			var contact := entry(aa, bb, finish - begin)
			if is_finite(contact) and begin + contact < finish:
				out.append({"time":begin + contact,"attacker":a.id,"target":b.id})
	out.sort_custom(func(a,b): return a.time < b.time)
	return out

static func find(bs: Array, id: String) -> Dictionary:
	for b in bs:
		if b.id == id: return b
	return {}

static func simulate(initial: Array, pause_hits := false, boundary := {}) -> Dictionary:
	var bs := initial.duplicate(true)
	var now := 0.0
	var events := []
	var frames := [{"time":0.0,"bodies":bs.duplicate(true)}]
	var first_candidates := candidates(bs, 0.0, 1.0)
	var pending := not boundary.is_empty()
	for iteration in range(40):
		var stop: float = boundary.time if pending else 1.0
		var cs := candidates(bs, now, stop)
		var next: float = cs[0].time if not cs.is_empty() else stop
		for b in bs: b.p += b.v * (next - now)
		now = next
		if cs.is_empty():
			if pending:
				var changed := find(bs, boundary.id)
				changed.v = boundary.velocity
				if boundary.get("landing",false): changed.active = false
				events.append({"time":now,"kind":"landing" if boundary.get("landing",false) else "wall", "id":changed.id})
				pending = false
			else:
				frames.append({"time":now,"bodies":bs.duplicate(true)})
				break
		else:
			var group := []
			for c in cs:
				if abs(c.time - now) <= TIE_EPS: group.append(c)
			var totals := {}
			for c in group:
				var a := find(bs,c.attacker)
				if not totals.has(c.target): totals[c.target] = {"damage":0.0,"launch":Vector2.ZERO}
				totals[c.target].damage += a.attack_damage
			# All contributions share post-group damage; provisional factor 1 + damage/100.
			for c in group:
				var a := find(bs,c.attacker)
				var b := find(bs,c.target)
				totals[c.target].launch += a.launch * (1.0 + (b.damage + totals[c.target].damage) / 100.0)
				a.history.append(b.id)
			for id in totals:
				var b := find(bs,id)
				b.damage += totals[id].damage
				b.v = totals[id].launch
				b.active = false
				if pause_hits: b.paused = true; b.v = Vector2.ZERO
			if pause_hits:
				for c in group:
					var a := find(bs,c.attacker)
					a.paused = true
					a.v = Vector2.ZERO
			events.append({"time":now,"kind":"hits","contacts":group,"results":totals})
		frames.append({"time":now,"bodies":bs.duplicate(true)})
	return {"initial_candidates":first_candidates,"events":events,"frames":frames,"final":bs,"end_time":now,"completed":now >= 1.0}

static func fixtures() -> Array:
	var target := body("Target",Vector2.ZERO,Vector2.ZERO)
	var left := body("Left",Vector2(-6,0),Vector2(10,0),Vector2(1,-1),10)
	var right := body("Right",Vector2(8,0),Vector2(-10,0),Vector2(-1,-1),10)
	# Attacks also have hurtboxes; vertical separation avoids incidental attack-vs-attack contact.
	left.p.y = -1.5
	right.p.y = 1.5
	var simultaneous := right.duplicate(true)
	simultaneous.p.x = 6
	var near := simultaneous.duplicate(true)
	near.p.x += 0.001
	var parallel_a := body("Attack",Vector2.ZERO,Vector2(10,0),Vector2.RIGHT,10)
	var parallel_b := body("Target",Vector2(5,0),Vector2(10,0))
	var startup := left.duplicate(true)
	startup.start = 0.9
	var inactive := left.duplicate(true)
	inactive.end = 0.3
	var first_active := left.duplicate(true)
	first_active.start = 0.2
	first_active.end = 0.5
	var early := body("Early",Vector2(-6,0),Vector2(20,0),Vector2.RIGHT,10)
	var later := body("Later",Vector2(0,0),Vector2(10,0),Vector2.RIGHT,10)
	var other := body("Other",Vector2(9,0),Vector2.ZERO)
	var wall_a := body("Attack",Vector2.ZERO,Vector2(10,10),Vector2.RIGHT,10)
	var wall_target := body("Target",Vector2(5.9,6),Vector2.ZERO)
	var land_a := body("Attack",Vector2.ZERO,Vector2(10,10),Vector2.RIGHT,10)
	return [
		{"name":"Distinct hits", "bodies":[left,right,target]},
		{"name":"Distinct hits with per-character pause", "bodies":[left,right,target],"pause":true},
		{"name":"Distinct hits reversed", "bodies":[target,right,left]},
		{"name":"True tie: opposing launches", "bodies":[left,simultaneous,target]},
		{"name":"True tie reversed", "bodies":[target,simultaneous,left]},
		{"name":"Near tie: 0.0001 step apart", "bodies":[left,near,target]},
		{"name":"Parallel negative control", "bodies":[parallel_a,parallel_b]},
		{"name":"Startup excluded", "bodies":[startup,target]},
		{"name":"Inactive excluded", "bodies":[inactive,target]},
		{"name":"First active interval crossing", "bodies":[first_active,target]},
		{"name":"Early interruption invalidates later", "bodies":[early,later,other]},
		{"name":"Early hit pause invalidates later", "bodies":[early,later,other],"pause":true},
		{"name":"Wall piecewise path", "bodies":[wall_a,wall_target],"boundary":{"time":0.4,"id":"Attack","velocity":Vector2(0,10)}},
		{"name":"Contact before landing retained", "bodies":[land_a,body("Target",Vector2(4,4),Vector2.ZERO)],"boundary":{"time":0.5,"id":"Attack","velocity":Vector2(10,0),"landing":true}},
		{"name":"Contact after landing rejected", "bodies":[land_a,body("Target",Vector2(8,5),Vector2.ZERO)],"boundary":{"time":0.5,"id":"Attack","velocity":Vector2(10,0),"landing":true}}
	]
