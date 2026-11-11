extends RefCounted
## Simple computer players. Each bot decides a few times per second:
##   1. run away from stronger planets that are close,
##   2. otherwise chase a weaker planet (if it feels brave),
##   3. otherwise grab loose moons and stardust.
## They also dash now and then, to escape or to lunge at a target.

const C = preload("res://scripts/config.gd")


static func think(p, world) -> void:
	var my_moons: int = p.moons
	var danger := Vector2.ZERO
	var prey = null
	var prey_d := 520.0
	var brave_gap := 1 if p.aggression > 0.3 else 2

	for o in world.planets:
		if o == p or not o.alive:
			continue
		var to: Vector2 = o.pos - p.pos
		var d := to.length()
		var reach: float = p.ring_r + o.ring_r + 150.0
		if o.moons > 0 and (o.moons > my_moons or my_moons == 0) and d < reach:
			danger -= to / maxf(d, 1.0) * (1.5 - d / reach)
		elif my_moons - o.moons >= brave_gap and o.shield <= 0.0 and d < prey_d:
			prey = o
			prey_d = d

	var dir := Vector2.ZERO
	p.want_dash = false
	if danger != Vector2.ZERO:
		dir = danger.normalized()
		p.chase_t = 0.0
		p.want_dash = danger.length() > 0.8 and randf() < 0.35
	elif prey != null and p.aggression > 0.15 and p.chase_cd <= 0.0:
		dir = (prey.pos - p.pos).normalized()
		p.chase_t += 0.2
		p.want_dash = prey_d < p.ring_r + 240.0 and randf() < 0.5 * p.aggression
		if p.chase_t > 2.0 + p.aggression * 3.0:
			p.chase_t = 0.0
			p.chase_cd = 2.0
	else:
		dir = _nearest_pickup(p, world)

	# Stay away from the arena wall.
	var edge: float = p.pos.length() - (C.ARENA_RADIUS - 220.0)
	if edge > 0.0:
		dir = (dir - p.pos.normalized() * (0.6 + edge / 120.0)).normalized()
	p.steer = dir


static func _nearest_pickup(p, world) -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	for item: Dictionary in world.loose:
		var ip: Vector2 = item.pos
		var d: float = p.pos.distance_squared_to(ip)
		if item.kind == "moon":
			d *= 0.2   # loose moons are worth a detour
		if d < best_d:
			best_d = d
			best = ip
	var dust: PackedVector2Array = world.dust_pos
	for i in dust.size():
		var d: float = p.pos.distance_squared_to(dust[i])
		if d < best_d:
			best_d = d
			best = dust[i]
	if best_d == INF:
		return Vector2.ZERO
	return (best - p.pos).normalized()
