extends Node2D
## The game world: moves every planet, handles pickups, bumps and map
## hazards, and draws everything. The player and bots share the same rules;
## only their steering differs, which is what will make real multiplayer easy
## to add later. Rounds (timer, results) are run by main.gd.

signal player_popped(by_name: String)

const C = preload("res://scripts/config.gd")
const Maps = preload("res://scripts/maps.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Planet = preload("res://scripts/planet.gd")
const Art = preload("res://scripts/art.gd")
const Bot = preload("res://scripts/bot_brain.gd")

# Stardust is sorted into a grid of square cells so each planet only has to
# look at the few pieces near it instead of all of them (much faster).
const DUST_CELL := 200.0
# Black hole map.
const HOLE_CORE := 95.0       # touching this part costs moons
const HOLE_REACH := 1100.0    # how far away the pull is felt
const HOLE_PULL := 150.0      # strongest pull, right at the middle (pixels per second)
const ROCK_TINT := Color("8f98b8")

var font: Font
var map: Dictionary = Maps.MAPS[0]
var arena_r := 1900.0
var frozen := false               # true once a round has ended: nothing moves
var planets: Array[Planet] = []
var player: Planet = null
var move_input := Vector2.ZERO    # set by main.gd from the joystick
var autopilot := false            # lets a bot brain steer the player (demo mode)
var rock_pos := PackedVector2Array()   # asteroids: where they are...
var rock_r := PackedFloat32Array()     # ...and how big

var dust_pos := PackedVector2Array()
var dust_col := PackedColorArray()
var dust_phase := PackedFloat32Array()
var _dust_cells := {}                  # Vector2i cell -> Array of dust indexes
var _dust_cell: Array[Vector2i] = []   # which cell each piece is in
var loose: Array[Dictionary] = []      # knocked-off moons and dropped stardust
var particles: Array[Dictionary] = []
var texts: Array[Dictionary] = []

var cam: Camera2D
var time := 0.0
var shake := 0.0
var leader: Planet = null         # top of the leaderboard, wears the crown
var _grip := 7.0
var _player_name := ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	load_map(Maps.MAPS[0])
	for i in C.BOT_COUNT:
		var bot := Planet.new()
		planets.append(bot)
		_new_bot(bot)
		# The menu shows a game that is already in full swing.
		bot.set_moons(_rng.randi_range(1, 6))
		bot.score = bot.moons * 6 + _rng.randi_range(0, 10)
	cam.position = planets[0].pos


# ------------------------------------------------------------ maps, rounds --

## Switches to a map: new arena size, asteroids and freshly scattered stardust.
func load_map(m: Dictionary) -> void:
	map = m
	arena_r = m.radius
	_grip = m.grip
	loose.clear()
	particles.clear()
	texts.clear()

	rock_pos.clear()
	rock_r.clear()
	var rock_count: int = m.rocks
	for i in rock_count:
		for attempt in 20:
			var r := _rng.randf_range(55.0, 115.0)
			var at := Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf()) * (arena_r - r - 160.0)
			var fits := at.length() > 260.0
			for k in rock_pos.size():
				if at.distance_to(rock_pos[k]) < r + rock_r[k] + 200.0:
					fits = false
			if fits:
				rock_pos.append(at)
				rock_r.append(r)
				break

	var count: int = m.dust
	dust_pos.resize(count)
	dust_col.resize(count)
	dust_phase.resize(count)
	_dust_cells.clear()
	_dust_cell.clear()
	for i in count:
		_dust_cell.append(Vector2i(999999, 999999))
		_move_dust(i, _random_point(40.0))
		dust_col[i] = C.DUST_COLORS[_rng.randi() % C.DUST_COLORS.size()]
		dust_phase[i] = _rng.randf() * TAU


## Starts a fresh round on a map: everyone begins at zero.
func start_round(m: Dictionary, pname: String, outfit: Dictionary) -> void:
	remove_player()
	load_map(m)
	frozen = false
	leader = null
	_player_name = pname
	for p in planets:
		_new_bot(p)
	player = Planet.new()
	player.is_player = true
	player.pname = pname
	player.apply_look(outfit)
	_place(player)
	planets.append(player)
	cam.position = player.pos


## Brings the player back after being popped (score is kept).
func respawn_player() -> void:
	if player != null and not player.alive:
		_place(player)


func remove_player() -> void:
	if player != null:
		planets.erase(player)
		if leader == player:
			leader = null
		player = null
	move_input = Vector2.ZERO


## Player pressed DASH. Returns false while it is still recharging.
func dash_player() -> bool:
	if frozen or player == null or not player.try_dash():
		return false
	Sfx.play("dash")
	return true


## Every planet, best score first.
func standings() -> Array[Planet]:
	var list: Array[Planet] = []
	list.assign(planets)
	list.sort_custom(func(a: Planet, b: Planet) -> bool: return a.score > b.score)
	return list


# -------------------------------------------------------------- simulation --

func _process(delta: float) -> void:
	# On a slow frame, run several small steps instead of one, so the game
	# keeps its real speed even when the frame rate drops.
	delta = minf(delta, 4.0 / 30.0)
	var steps := clampi(ceili(delta * 30.0), 1, 4)
	for i in steps:
		if frozen:
			_update_effects(delta / steps)
		else:
			_step(delta / steps)
	time += delta
	_update_camera(delta)
	queue_redraw()


func _step(delta: float) -> void:
	for p in planets:
		if not p.alive:
			if not p.is_player:
				p.respawn_timer -= delta
				if p.respawn_timer <= 0.0:
					_place(p)
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
		p.tick(delta, arena_r, _grip)
		_apply_hazards(p, delta)
		if not p.alive:
			continue
		if _on_screen(p.pos):
			if p.dash_t > 0.0:
				particles.append({
					"pos": p.pos - p.dash_dir * p.radius, "vel": Vector2.ZERO,
					"color": p.color.lightened(0.3), "life": 0.3, "max": 0.3, "size": p.radius * 0.7,
				})
			if p.trail != "trail_none" and p.vel.length() > 80.0:
				p.trail_t -= delta
				if p.trail_t <= 0.0:
					p.trail_t = 0.07
					_emit_trail(p)
		if leader == null or p.score > leader.score:
			leader = p

	_collect_dust(delta)
	_update_loose(delta)

	var n := planets.size()
	for i in n:
		for j in range(i + 1, n):
			if planets[i].alive and planets[j].alive:
				_fight(planets[i], planets[j])

	_update_effects(delta)


## Asteroids block the way; the black hole pulls and bites.
func _apply_hazards(p: Planet, delta: float) -> void:
	for k in rock_pos.size():
		var to := p.pos - rock_pos[k]
		var d := to.length()
		var min_d := rock_r[k] + p.radius
		if d < min_d and d > 0.01:
			var n := to / d
			p.pos = rock_pos[k] + n * min_d
			var into := p.vel.dot(n)
			if into < 0.0:
				p.vel -= n * into
			into = p.knock.dot(n)
			if into < 0.0:
				p.knock -= n * into * 1.6
	if map.hole and p.dash_t <= 0.0:
		var d := p.pos.length()
		if d > 1.0 and d < HOLE_REACH:
			p.pos -= p.pos / d * HOLE_PULL * pow(1.0 - d / HOLE_REACH, 1.5) * delta
		if d < HOLE_CORE + p.radius * 0.5 and p.shield <= 0.0:
			_hole_bite(p)


## The black hole swallows half of a planet's moons and spits the planet out.
func _hole_bite(p: Planet) -> void:
	var out := p.pos.normalized() if p.pos.length() > 1.0 else Vector2.from_angle(_rng.randf() * TAU)
	_burst(p.pos, Color("c08bff"), 14, 260.0)
	if p.moons == 0:
		_pop(p, null, "The black hole")
		return
	var lost := maxi(1, ceili(p.moons * C.HIT_LOSS))
	for k in lost:
		p.remove_moon(p.moons - 1)
	p.knock = out * 900.0
	p.shield = 1.0
	p.squash = 1.0
	if p.is_player:
		shake = 12.0
		_float_text(p.pos + Vector2(0, -p.radius - 40.0), "Gulp! -%d" % lost, Color("ff9ec4"))
	if _on_screen(p.pos):
		Sfx.play("hit", 0.7, 0.0 if p.is_player else -8.0)


func _collect_dust(delta: float) -> void:
	for p in planets:
		if not p.alive:
			continue
		var grab := p.radius + 12.0
		var pull := p.radius + 70.0 * p.pull_mul   # must stay smaller than DUST_CELL
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
	while p.dust_progress >= p.dust_per_moon and p.moons < p.max_moons:
		p.dust_progress -= p.dust_per_moon
		p.add_moon()
		grew = true
	if p.moons >= p.max_moons:
		p.dust_progress = 0
	if p.is_player:
		if grew:
			Sfx.play("moon")
			_float_text(p.pos + Vector2(0, -p.radius - 40.0), "New moon!", C.GOLD)
		else:
			Sfx.play("pickup", 0.9 + 0.08 * p.dust_progress, -6.0)


func _update_loose(delta: float) -> void:
	var limit := arena_r - 20.0
	for i in range(loose.size() - 1, -1, -1):
		var item := loose[i]
		var ip: Vector2 = item.pos
		var iv: Vector2 = item.vel
		ip += iv * delta
		if ip.length() > limit:
			ip = ip.normalized() * limit
		for k in rock_pos.size():   # keep pickups out of asteroids
			if ip.distance_to(rock_pos[k]) < rock_r[k] + 16.0:
				ip = rock_pos[k] + (ip - rock_pos[k]).normalized() * (rock_r[k] + 16.0)
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
		_pop(victim, attacker, attacker.pname)
		return
	# The lost moons fly back towards the attacker, who can scoop them up.
	var lost := maxi(1, ceili(victim.moons * C.HIT_LOSS))
	for k in lost:
		var last := victim.moons - 1
		var dir := (-away).rotated(_rng.randf_range(-1.3, 1.3))
		_drop_moon(victim.moon_pos[last], dir * _rng.randf_range(160.0, 300.0), victim.color, victim)
		victim.remove_moon(last)
	victim.shield = C.HIT_SHIELD_TIME * victim.shield_mul
	victim.dizzy = C.HIT_DIZZY_TIME
	attacker.score += C.SCORE_HIT * lost
	if attacker.is_player:
		_float_text(at, "Hit! +%d" % (C.SCORE_HIT * lost), Color.WHITE)
	elif victim.is_player:
		_float_text(victim.pos + Vector2(0, -victim.radius - 40.0), "Ouch! -%d" % lost, Color("ff9ec4"))
	if _on_screen(at):
		Sfx.play("hit", _rng.randf_range(0.9, 1.1), 0.0 if (victim.is_player or attacker.is_player) else -8.0)


## attacker is null when the map itself (the black hole) did it.
func _pop(victim: Planet, attacker: Planet, by_name: String) -> void:
	victim.alive = false
	victim.respawn_timer = C.BOT_RESPAWN_TIME
	_burst(victim.pos, victim.color, 26, 380.0)
	_burst(victim.pos, Color.WHITE, 10, 260.0)
	var drops := clampi(victim.score / 6, 5, 16)
	for i in drops:
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		loose.append({
			"kind": "dust", "pos": victim.pos + dir * 10.0, "vel": dir * _rng.randf_range(120.0, 420.0),
			"color": C.DUST_COLORS[_rng.randi() % C.DUST_COLORS.size()], "age": 0.0, "life": 18.0,
		})
	var player_involved := victim.is_player
	if attacker != null:
		attacker.score += C.SCORE_POP
		attacker.pops += 1
		if attacker.is_player:
			player_involved = true
			_float_text(victim.pos, "Pop! +%d" % C.SCORE_POP, C.GOLD)
	if _on_screen(victim.pos):
		Sfx.play("pop", 1.0, 0.0 if player_involved else -8.0)
	if victim.is_player:
		player_popped.emit(by_name)


func _drop_moon(at: Vector2, vel: Vector2, color: Color, owner: Planet) -> void:
	loose.append({"kind": "moon", "pos": at, "vel": vel, "color": color, "age": 0.0, "life": 14.0, "owner": owner})


## A brand-new computer player: new name, new look, score zero.
func _new_bot(p: Planet) -> void:
	var taken: Array[String] = [_player_name]   # no bot shares the player's name
	for o in planets:
		if o != p:
			taken.append(o.pname)
	var pick := C.NAMES[_rng.randi() % C.NAMES.size()]
	while pick in taken:
		pick = C.NAMES[_rng.randi() % C.NAMES.size()]
	p.pname = pick
	p.apply_look(_random_outfit())
	p.color = p.color.lerp(Color.WHITE, _rng.randf() * 0.12)
	p.score = 0
	p.pops = 0
	p.aggression = _rng.randf() * C.BOT_BRAVERY
	p.think_t = _rng.randf() * 0.2
	_place(p)


## Bots mostly wear the free colours; some show off things from the shop.
func _random_outfit() -> Dictionary:
	var skin: Dictionary = Catalog.SKINS[_rng.randi() % Catalog.SKINS.size()]
	var price: int = skin.price
	if price > 0 and _rng.randf() < 0.5:
		skin = Catalog.SKINS[_rng.randi() % 8]
	var outfit := {"skin": skin, "hat": "hat_none", "trail": "trail_none", "moon": "moon_round"}
	if _rng.randf() < 0.3:
		outfit.hat = Catalog.HATS[1 + _rng.randi() % (Catalog.HATS.size() - 1)].id
	if _rng.randf() < 0.12:
		outfit.trail = Catalog.TRAILS[1 + _rng.randi() % (Catalog.TRAILS.size() - 1)].id
	if _rng.randf() < 0.2:
		outfit.moon = Catalog.MOONS[1 + _rng.randi() % (Catalog.MOONS.size() - 1)].id
	return outfit


## Puts a planet into the arena at a safe spot with its starting moons.
func _place(p: Planet) -> void:
	p.pos = _safe_spawn_point(p)
	p.vel = Vector2.ZERO
	p.knock = Vector2.ZERO
	p.input_dir = Vector2.ZERO
	p.alive = true
	p.dizzy = 0.0
	p.dash_t = 0.0
	p.dash_cd = 0.0
	p.dust_progress = 0
	p.orbit_angle = _rng.randf() * TAU
	p.set_moons(p.start_moons)
	p.shield = C.SPAWN_SHIELD_TIME * p.shield_mul


## A random spot in the arena that is not inside an asteroid or the black hole.
func _random_point(margin: float) -> Vector2:
	var pt := Vector2.ZERO
	for attempt in 8:
		var t := _rng.randf()
		var dist := sqrt(t) * (arena_r - margin)
		if map.hole:   # more stardust near the middle: tempting but risky
			dist = lerpf(HOLE_CORE + 70.0, arena_r - margin, pow(t, 0.75))
		pt = Vector2.from_angle(_rng.randf() * TAU) * dist
		var free := true
		for k in rock_pos.size():
			if pt.distance_to(rock_pos[k]) < rock_r[k] + 30.0:
				free = false
		if free:
			break
	return pt


## A random spot that is as far as possible from the other planets.
func _safe_spawn_point(who: Planet) -> Vector2:
	var best := Vector2.ZERO
	var best_d := -1.0
	for attempt in 14:
		var pt := _random_point(160.0)
		if map.hole and pt.length() < 520.0:
			continue
		var nearest := INF
		for o in planets:
			if o.alive and o != who:
				nearest = minf(nearest, o.pos.distance_to(pt))
		for k in rock_pos.size():
			if pt.distance_to(rock_pos[k]) < rock_r[k] + 70.0:
				nearest = 0.0
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


## One puff of a cosmetic trail behind a moving planet.
func _emit_trail(p: Planet) -> void:
	if particles.size() > 220:
		return
	var at := p.pos - p.vel.normalized() * p.radius * 0.9
	at += Vector2(_rng.randf_range(-9.0, 9.0), _rng.randf_range(-9.0, 9.0))
	var puff := {"pos": at, "vel": Vector2.ZERO, "color": Color.WHITE, "life": 0.6, "max": 0.6, "size": 8.0}
	match p.trail:
		"trail_bubbles":
			puff.color = Color(0.78, 0.95, 1.0, 0.85)
			puff.size = _rng.randf_range(5.0, 10.0)
			puff.vel = Vector2(0, -30.0)
		"trail_stars":
			puff.color = C.DUST_COLORS[_rng.randi() % C.DUST_COLORS.size()]
			puff.size = 13.0
			puff.star = true
		"trail_rainbow":
			puff.color = Color.from_hsv(fmod(time * 0.9, 1.0), 0.55, 1.0)
			puff.size = 10.0
	particles.append(puff)


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
		if leader != null and leader.alive:
			target = leader.pos
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
	var wall: Color = map.wall

	# Arena floor, guide dots and the glowing wall.
	draw_circle(Vector2.ZERO, arena_r, Color(1, 1, 1, 0.045))
	var grid := 180.0
	var gx := floorf(view.position.x / grid) * grid
	while gx < view.end.x:
		var gy := floorf(view.position.y / grid) * grid
		while gy < view.end.y:
			if Vector2(gx, gy).length() < arena_r - 20.0:
				Art.disc(self, Vector2(gx, gy), 4.0, Color(1, 1, 1, 0.08))
			gy += grid
		gx += grid
	draw_arc(Vector2.ZERO, arena_r + 26.0, 0.0, TAU, 256, Color(wall, 0.18), 30.0, true)
	draw_arc(Vector2.ZERO, arena_r + 8.0, 0.0, TAU, 256, wall, 12.0, true)

	if map.hole and view.grow(700.0).has_point(Vector2.ZERO):
		_draw_black_hole()
	for k in rock_pos.size():
		if view.grow(rock_r[k]).has_point(rock_pos[k]):
			Art.rock(self, rock_pos[k], rock_r[k], ROCK_TINT)

	# Stardust.
	var c0 := _cell_of(view.position)
	var c1 := _cell_of(view.end)
	for cx in range(c0.x, c1.x + 1):
		for cy in range(c0.y, c1.y + 1):
			var cell: Array = _dust_cells.get(Vector2i(cx, cy), [])
			for i: int in cell:
				var ph := dust_phase[i]
				Art.sparkle(self, dust_pos[i], 9.0 + 2.5 * sin(time * 3.0 + ph), dust_col[i])

	# Loose moons and dropped stardust (they blink before disappearing).
	for item in loose:
		var ip: Vector2 = item.pos
		if not view.has_point(ip):
			continue
		var left: float = item.life - item.age
		var alpha := 1.0 if left > 3.0 or fmod(left, 0.4) > 0.2 else 0.35
		var icol: Color = item.color
		if item.kind == "moon":
			Art.disc(self, ip, C.MOON_RADIUS * 2.0, Color(1, 1, 1, 0.12 * alpha))
			Art.moon(self, ip, C.MOON_RADIUS, icol, alpha)
		else:
			Art.sparkle(self, ip, 12.0, Color(icol, alpha))

	# Orbit rings first so they sit underneath everything.
	for p in planets:
		if p.alive and view.grow(p.ring_r).has_point(p.pos):
			Art.ring(self, p.pos, p.ring_r, Color(p.color, 0.3))

	for p in planets:
		if not p.alive or not view.grow(p.ring_r + 20.0).has_point(p.pos):
			continue
		for k in p.moons:
			Art.moon(self, p.moon_pos[k], C.MOON_RADIUS * (0.3 + 0.7 * p.moon_scale[k]), p.color, 1.0, p.moon_style)
		if p.shield > 0.0:
			Art.shield(self, p.pos, p.radius + 9.0, time)
		Art.planet(self, p.pos, p.radius, p.color, p.look, p.blink_t < 0.12, p.squash, p.moons == 0, p.style, p.hat)

	for pt in particles:
		var k: float = pt.life / pt.max
		var pc: Color = pt.color
		var size: float = pt.size
		if pt.has("star"):
			Art.star(self, pt.pos, size * k, Color(pc, k))
		else:
			Art.disc(self, pt.pos, size * k, Color(pc, pc.a * k))

	# Names and the crown last, all together (keeps the shapes above in one batch).
	for p in planets:
		if not p.alive or not view.grow(p.ring_r + 20.0).has_point(p.pos):
			continue
		var name_y := -p.radius * (1.0 + Art.hat_height(p.hat)) - 14.0
		if p == leader:
			Art.crown(self, p.pos + Vector2(0, name_y - 26.0), 13.0)
		Art.text(self, font, p.pos + Vector2(0, name_y), p.pname, 22, C.GOLD if p.is_player else Color.WHITE)
	for t in texts:
		var tc: Color = t.color
		var life: float = t.life
		Art.text(self, font, t.pos, t.text, 30, Color(tc, minf(1.0, life * 2.0)))


func _draw_black_hole() -> void:
	# Rings drifting inwards show which way the pull goes.
	for i in 4:
		var travel := fposmod(i * 150.0 - time * 70.0, 600.0)
		Art.ring(self, Vector2.ZERO, HOLE_CORE + travel, Color(0.85, 0.65, 1.0, 0.32 * (1.0 - travel / 600.0)))
	Art.disc(self, Vector2.ZERO, HOLE_CORE + 46.0, Color(0.7, 0.4, 1.0, 0.16))
	Art.disc(self, Vector2.ZERO, HOLE_CORE + 18.0, Color(1.0, 0.6, 0.85, 0.3))
	Art.disc(self, Vector2.ZERO, HOLE_CORE, Color("12081f"))
	for i in 7:
		var a := time * 2.2 + TAU * i / 7.0
		Art.disc(self, Vector2.from_angle(a) * HOLE_CORE * 0.62, 5.0, Color(1.0, 0.8, 1.0, 0.7))
		Art.disc(self, Vector2.from_angle(-a * 0.7) * HOLE_CORE * 0.32, 3.5, Color(0.8, 0.7, 1.0, 0.6))
