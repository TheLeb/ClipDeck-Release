extends Node2D
## The game world: moves every planet, handles pickups and bumps, and draws
## everything. The player and bots share the same rules; only their steering
## differs, which is what will make real multiplayer easy to add later.

signal player_popped(by_name: String)

const C = preload("res://scripts/config.gd")
const Planet = preload("res://scripts/planet.gd")
const Art = preload("res://scripts/art.gd")
const Bot = preload("res://scripts/bot_brain.gd")

var font: Font
var planets: Array[Planet] = []
var player: Planet = null
var move_input := Vector2.ZERO    # set by main.gd from the joystick
var autopilot := false            # lets a bot brain steer the player (demo mode)

var dust_pos := PackedVector2Array()
var dust_col := PackedColorArray()
var dust_phase := PackedFloat32Array()
# Stardust is sorted into a grid of square cells so each planet only has to
# look at the few pieces near it instead of all of them (much faster).
const DUST_CELL := 200.0
var _dust_cells := {}                  # Vector2i cell -> Array of dust indexes
var _dust_cell: Array[Vector2i] = []   # which cell each piece is in
var loose: Array[Dictionary] = []      # knocked-off moons and dropped stardust
var particles: Array[Dictionary] = []
var texts: Array[Dictionary] = []

var cam: Camera2D
var time := 0.0
var shake := 0.0
var leader: Planet = null         # top of the leaderboard, wears the crown
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	for i in C.DUST_COUNT:
		dust_pos.append(Vector2.ZERO)
		_dust_cell.append(Vector2i(999999, 999999))
		_move_dust(i, _random_point(40.0))
		dust_col.append(C.DUST_COLORS[_rng.randi() % C.DUST_COLORS.size()])
		dust_phase.append(_rng.randf() * TAU)
	for i in C.BOT_COUNT:
		var bot := Planet.new()
		planets.append(bot)
		_reset_bot(bot, _rng.randi_range(1, 6))
		bot.score = bot.moons * 6 + _rng.randi_range(0, 10)
	cam.position = planets[0].pos


# ------------------------------------------------------------------ player --

func spawn_player(pname: String, color: Color) -> void:
	remove_player()
	player = Planet.new()
	player.is_player = true
	player.pname = pname
	player.color = color
	player.pos = _safe_spawn_point()
	player.set_moons(C.START_MOONS)
	player.shield = C.SPAWN_SHIELD_TIME
	planets.append(player)
	cam.position = player.pos


func revive_player() -> void:
	if player == null:
		return
	player.alive = true
	player.vel = Vector2.ZERO
	player.knock = Vector2.ZERO
	player.dizzy = 0.0
	player.set_moons(C.START_MOONS)
	player.shield = C.SPAWN_SHIELD_TIME + 1.0


func remove_player() -> void:
	if player != null:
		planets.erase(player)
		player = null
	move_input = Vector2.ZERO


## Player pressed DASH. Returns false while it is still recharging.
func dash_player() -> bool:
	if player == null or not player.try_dash():
		return false
	Sfx.play("dash")
	return true


## Alive planets, best score first.
func leaderboard() -> Array[Planet]:
	var list: Array[Planet] = []
	for p in planets:
		if p.alive:
			list.append(p)
	list.sort_custom(func(a: Planet, b: Planet) -> bool: return a.score > b.score)
	return list


# -------------------------------------------------------------- simulation --

func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)
	time += delta
	_step(delta)
	_update_camera(delta)
	queue_redraw()


func _step(delta: float) -> void:
	for p in planets:
		if not p.alive:
			if not p.is_player:
				p.respawn_timer -= delta
				if p.respawn_timer <= 0.0:
					_reset_bot(p, C.START_MOONS)
			continue
		if p.is_player and not autopilot:
			p.input_dir = move_input
		else:
			p.think_t -= delta
			p.chase_cd -= delta
			if p.think_t <= 0.0:
				p.think_t = 0.2
				Bot.think(p, self)
			p.input_dir = p.input_dir.lerp(p.steer, 1.0 - exp(-6.0 * delta))
			if p.want_dash:
				p.want_dash = false
				p.input_dir = p.steer
				if p.try_dash() and _on_screen(p.pos):
					Sfx.play("dash", 1.1, -10.0)
		p.tick(delta)
		if p.dash_t > 0.0 and _on_screen(p.pos):
			particles.append({
				"pos": p.pos - p.dash_dir * p.radius, "vel": Vector2.ZERO,
				"color": p.color.lightened(0.3), "life": 0.3, "max": 0.3, "size": p.radius * 0.7,
			})
		if leader == null or not leader.alive or p.score > leader.score:
			leader = p

	_collect_dust(delta)
	_update_loose(delta)

	var n := planets.size()
	for i in n:
		for j in range(i + 1, n):
			if planets[i].alive and planets[j].alive:
				_fight(planets[i], planets[j])

	_update_effects(delta)


func _collect_dust(delta: float) -> void:
	for p in planets:
		if not p.alive:
			continue
		var grab := p.radius + 12.0
		var pull := p.radius + 70.0   # must stay smaller than DUST_CELL
		var c := _cell_of(p.pos)
		for cx in range(c.x - 1, c.x + 2):
			for cy in range(c.y - 1, c.y + 2):
				var cell: Array = _dust_cells.get(Vector2i(cx, cy), [])
				for k in range(cell.size() - 1, -1, -1):
					var i: int = cell[k]
					var d := p.pos.distance_to(dust_pos[i])
					if d < grab:
						_burst(dust_pos[i], dust_col[i], 4, 90.0)
						_move_dust(i, _random_point(40.0))
						_gain_dust(p, 1)
					elif d < pull:
						_move_dust(i, dust_pos[i].move_toward(p.pos, 260.0 * delta))


func _cell_of(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / DUST_CELL), floori(at.y / DUST_CELL))


## Move one piece of stardust and keep the grid up to date.
func _move_dust(i: int, to: Vector2) -> void:
	dust_pos[i] = to
	var c := _cell_of(to)
	if c == _dust_cell[i]:
		return
	if _dust_cells.has(_dust_cell[i]):
		_dust_cells[_dust_cell[i]].erase(i)
	if not _dust_cells.has(c):
		_dust_cells[c] = []
	_dust_cells[c].append(i)
	_dust_cell[i] = c


func _gain_dust(p: Planet, amount: int) -> void:
	p.score += C.SCORE_DUST * amount
	p.dust_progress += amount
	var grew := false
	while p.dust_progress >= C.DUST_PER_MOON and p.moons < C.MAX_MOONS:
		p.dust_progress -= C.DUST_PER_MOON
		p.add_moon()
		grew = true
	if p.moons >= C.MAX_MOONS:
		p.dust_progress = 0
	if p.is_player:
		if grew:
			Sfx.play("moon")
			_float_text(p.pos + Vector2(0, -p.radius - 40.0), "New moon!", C.GOLD)
		else:
			Sfx.play("pickup", 0.9 + 0.08 * p.dust_progress, -6.0)


func _update_loose(delta: float) -> void:
	var limit := C.ARENA_RADIUS - 20.0
	for i in range(loose.size() - 1, -1, -1):
		var item := loose[i]
		var ip: Vector2 = item.pos
		var iv: Vector2 = item.vel
		ip += iv * delta
		if ip.length() > limit:
			ip = ip.normalized() * limit
		item.pos = ip
		item.vel = iv.lerp(Vector2.ZERO, 1.0 - exp(-3.0 * delta))
		item.age += delta
		if item.age > item.life:
			loose.remove_at(i)
			continue
		if item.age < 0.45:
			continue
		for p in planets:
			if item.get("owner") == p and item.age < 2.5:
				continue   # no instantly grabbing back the moons you just lost
			if p.alive and p.pos.distance_to(ip) < p.radius + 16.0:
				if item.kind == "moon":
					p.add_moon()
					p.score += C.SCORE_LOOSE_MOON
					if p.is_player:
						Sfx.play("moon", 1.2)
						_float_text(ip, "+%d" % C.SCORE_LOOSE_MOON, C.GOLD)
				else:
					_gain_dust(p, 2)
				_burst(ip, item.color, 6, 120.0)
				loose.remove_at(i)
				break


## Everything that can happen when two planets are close to each other.
func _fight(a: Planet, b: Planet) -> void:
	var d := a.pos.distance_to(b.pos)
	if d > a.ring_r + b.ring_r + C.MOON_RADIUS * 2.0 + 4.0:
		return

	# Planets bounce off each other. (Moons pass through other moons.)
	if d < a.radius + b.radius and d > 0.01:
		var n := (b.pos - a.pos) / d
		var overlap := a.radius + b.radius - d
		a.pos -= n * overlap * 0.5
		b.pos += n * overlap * 0.5
		a.knock -= n * 140.0
		b.knock += n * 140.0

	# A moon touching a planet bumps it.
	_moons_hit_planet(a, b)
	_moons_hit_planet(b, a)


func _moons_hit_planet(attacker: Planet, victim: Planet) -> void:
	if victim.shield > 0.0 or victim.dash_t > 0.0 or not attacker.alive or not victim.alive:
		return
	var reach := C.MOON_RADIUS + victim.radius
	for i in attacker.moons:
		if attacker.moon_pos[i].distance_to(victim.pos) < reach:
			_bump(victim, attacker, attacker.moon_pos[i])
			return


func _bump(victim: Planet, attacker: Planet, at: Vector2) -> void:
	var away := (victim.pos - attacker.pos).normalized()
	victim.knock += away * C.HIT_KNOCKBACK
	victim.squash = 1.0
	_burst(at, Color.WHITE, 10, 220.0)
	if victim.is_player:
		shake = 12.0
	if victim.moons == 0:
		_pop(victim, attacker)
		return
	# The lost moons fly back towards the attacker, who can scoop them up.
	var lost := maxi(1, ceili(victim.moons * C.HIT_LOSS))
	for k in lost:
		var last := victim.moons - 1
		var dir := (-away).rotated(_rng.randf_range(-1.3, 1.3))
		_drop_moon(victim.moon_pos[last], dir * _rng.randf_range(160.0, 300.0), victim.color, victim)
		victim.remove_moon(last)
	victim.shield = C.HIT_SHIELD_TIME
	victim.dizzy = C.HIT_DIZZY_TIME
	attacker.score += C.SCORE_HIT * lost
	if attacker.is_player:
		_float_text(at, "Hit! +%d" % (C.SCORE_HIT * lost), Color.WHITE)
	elif victim.is_player:
		_float_text(victim.pos + Vector2(0, -victim.radius - 40.0), "Ouch! -%d" % lost, Color("ff9ec4"))
	if _on_screen(at):
		Sfx.play("hit", _rng.randf_range(0.9, 1.1), 0.0 if (victim.is_player or attacker.is_player) else -8.0)


func _pop(victim: Planet, attacker: Planet) -> void:
	victim.alive = false
	victim.respawn_timer = C.BOT_RESPAWN_TIME
	attacker.score += C.SCORE_POP
	_burst(victim.pos, victim.color, 26, 380.0)
	_burst(victim.pos, Color.WHITE, 10, 260.0)
	var drops := clampi(victim.score / 6, 5, 16)
	for i in drops:
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		loose.append({
			"kind": "dust", "pos": victim.pos + dir * 10.0, "vel": dir * _rng.randf_range(120.0, 420.0),
			"color": C.DUST_COLORS[_rng.randi() % C.DUST_COLORS.size()], "age": 0.0, "life": 18.0,
		})
	if attacker.is_player:
		_float_text(victim.pos, "Pop! +%d" % C.SCORE_POP, C.GOLD)
	if _on_screen(victim.pos):
		Sfx.play("pop", 1.0, 0.0 if (victim.is_player or attacker.is_player) else -8.0)
	if victim.is_player:
		player_popped.emit(attacker.pname)


func _drop_moon(at: Vector2, vel: Vector2, color: Color, owner: Planet) -> void:
	loose.append({"kind": "moon", "pos": at, "vel": vel, "color": color, "age": 0.0, "life": 14.0, "owner": owner})


func _reset_bot(p: Planet, moon_count: int) -> void:
	var taken: Array[String] = []
	for o in planets:
		taken.append(o.pname)
	var pick := C.NAMES[_rng.randi() % C.NAMES.size()]
	while pick in taken:
		pick = C.NAMES[_rng.randi() % C.NAMES.size()]
	p.pname = pick
	p.color = C.SKINS[_rng.randi() % C.SKINS.size()].lerp(Color.WHITE, _rng.randf() * 0.15)
	p.pos = _safe_spawn_point()
	p.vel = Vector2.ZERO
	p.knock = Vector2.ZERO
	p.input_dir = Vector2.ZERO
	p.alive = true
	p.dizzy = 0.0
	p.score = 0
	p.dust_progress = 0
	p.orbit_angle = _rng.randf() * TAU
	p.aggression = _rng.randf() * C.BOT_BRAVERY
	p.think_t = _rng.randf() * 0.2
	p.set_moons(moon_count)
	p.shield = C.SPAWN_SHIELD_TIME


func _random_point(margin: float) -> Vector2:
	return Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf()) * (C.ARENA_RADIUS - margin)


## A random spot that is as far as possible from other planets.
func _safe_spawn_point() -> Vector2:
	var best := Vector2.ZERO
	var best_d := -1.0
	for attempt in 14:
		var pt := _random_point(160.0)
		var nearest := INF
		for o in planets:
			if o.alive:
				nearest = minf(nearest, o.pos.distance_to(pt))
		if nearest > best_d:
			best_d = nearest
			best = pt
	return best


# ----------------------------------------------------------------- effects --

func _burst(at: Vector2, color: Color, count: int, speed: float) -> void:
	if particles.size() > 260 or not _on_screen(at):
		return
	for i in count:
		var life := _rng.randf_range(0.3, 0.6)
		particles.append({
			"pos": at, "vel": Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.3, 1.0) * speed,
			"color": color, "life": life, "max": life, "size": _rng.randf_range(3.0, 7.0),
		})


func _float_text(at: Vector2, s: String, color: Color) -> void:
	texts.append({"pos": at, "text": s, "color": color, "life": 1.0})


func _update_effects(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p := particles[i]
		p.life -= delta
		if p.life <= 0.0:
			particles.remove_at(i)
			continue
		var v: Vector2 = p.vel
		p.pos += v * delta
		p.vel = v.lerp(Vector2.ZERO, 1.0 - exp(-4.0 * delta))
	for i in range(texts.size() - 1, -1, -1):
		var t := texts[i]
		t.life -= delta
		t.pos += Vector2(0, -60.0) * delta
		if t.life <= 0.0:
			texts.remove_at(i)
	shake = maxf(0.0, shake - delta * 30.0)


func _update_camera(delta: float) -> void:
	var target := cam.position
	var zoom := C.ZOOM_SMALL
	var follow := 10.0
	if player != null:
		if player.alive:
			target = player.pos
		zoom = lerpf(C.ZOOM_SMALL, C.ZOOM_BIG, float(player.moons) / C.MAX_MOONS)
	else:
		# Menu: lazily follow whoever is winning.
		var board := leaderboard()
		if not board.is_empty():
			target = board[0].pos
		zoom = 0.8
		follow = 1.5
	cam.position = cam.position.lerp(target, 1.0 - exp(-follow * delta))
	cam.zoom = cam.zoom.lerp(Vector2(zoom, zoom), 1.0 - exp(-2.0 * delta))
	cam.offset = Vector2(_rng.randf_range(-shake, shake), _rng.randf_range(-shake, shake))


func _view_rect() -> Rect2:
	var size := get_viewport_rect().size / cam.zoom
	return Rect2(cam.position - size * 0.5, size)


func _on_screen(at: Vector2) -> bool:
	return _view_rect().grow(60.0).has_point(at)


# ----------------------------------------------------------------- drawing --

func _draw() -> void:
	var view := _view_rect().grow(40.0)

	# Arena floor, guide dots and the glowing wall.
	draw_circle(Vector2.ZERO, C.ARENA_RADIUS, Color(1, 1, 1, 0.045))
	var grid := 180.0
	var gx := floorf(view.position.x / grid) * grid
	while gx < view.end.x:
		var gy := floorf(view.position.y / grid) * grid
		while gy < view.end.y:
			if Vector2(gx, gy).length() < C.ARENA_RADIUS - 20.0:
				draw_circle(Vector2(gx, gy), 4.0, Color(1, 1, 1, 0.08))
			gy += grid
		gx += grid
	draw_arc(Vector2.ZERO, C.ARENA_RADIUS + 26.0, 0.0, TAU, 256, Color(C.GOLD, 0.18), 30.0, true)
	draw_arc(Vector2.ZERO, C.ARENA_RADIUS + 8.0, 0.0, TAU, 256, C.GOLD, 12.0, true)

	# Stardust.
	var c0 := _cell_of(view.position)
	var c1 := _cell_of(view.end)
	for cx in range(c0.x, c1.x + 1):
		for cy in range(c0.y, c1.y + 1):
			var cell: Array = _dust_cells.get(Vector2i(cx, cy), [])
			for i: int in cell:
				var ph := dust_phase[i]
				Art.sparkle(self, dust_pos[i], 9.0 + 2.0 * sin(time * 3.0 + ph), dust_col[i], time * 0.6 + ph)

	# Loose moons and dropped stardust (they blink before disappearing).
	for item in loose:
		var ip: Vector2 = item.pos
		if not view.has_point(ip):
			continue
		var left: float = item.life - item.age
		var alpha := 1.0 if left > 3.0 or fmod(left, 0.4) > 0.2 else 0.35
		var icol: Color = item.color
		if item.kind == "moon":
			draw_circle(ip, C.MOON_RADIUS * 2.0, Color(1, 1, 1, 0.12 * alpha))
			Art.moon(self, ip, C.MOON_RADIUS, icol, alpha)
		else:
			Art.sparkle(self, ip, 12.0, Color(icol, alpha), time * 2.0)

	# Orbit rings first so they sit underneath everything.
	for p in planets:
		if p.alive and view.grow(p.ring_r).has_point(p.pos):
			draw_arc(p.pos, p.ring_r, 0.0, TAU, 48, Color(p.color, 0.2), 2.0, true)

	for p in planets:
		if not p.alive or not view.grow(p.ring_r + 20.0).has_point(p.pos):
			continue
		for k in p.moons:
			Art.moon(self, p.moon_pos[k], C.MOON_RADIUS * (0.3 + 0.7 * p.moon_scale[k]), p.color)
		Art.planet(self, p.pos, p.radius, p.color, p.look, p.blink_t < 0.12, p.squash, p.moons == 0)
		if p.shield > 0.0:
			Art.shield(self, p.pos, p.radius + 9.0, time)
		var label_col := C.GOLD if p.is_player else Color.WHITE
		Art.text(self, font, p.pos + Vector2(0, -p.radius - 14.0), p.pname, 22, label_col)
		if p == leader:
			Art.crown(self, p.pos + Vector2(0, -p.radius - 44.0), 14.0)

	for pt in particles:
		var k: float = pt.life / pt.max
		var pc: Color = pt.color
		var size: float = pt.size
		draw_circle(pt.pos, size * k, Color(pc, k))
	for t in texts:
		var tc: Color = t.color
		var life: float = t.life
		Art.text(self, font, t.pos, t.text, 30, Color(tc, minf(1.0, life * 2.0)))
