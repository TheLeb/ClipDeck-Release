extends RefCounted
## One planet in the arena. The player and the bots are all Planets;
## the only difference is who fills in `input_dir` every frame.

const C = preload("res://scripts/config.gd")

var is_player := false
var pname := ""

# Look (see catalog.gd).
var color := Color.WHITE
var style := "plain"
var hat := "hat_none"
var trail := "trail_none"
var moon_style := "moon_round"

# Stats; the equipped skin can nudge these a little.
var speed_mul := 1.0
var max_moons := C.MAX_MOONS
var start_moons := C.START_MOONS
var pull_mul := 1.0
var dash_cd_mul := 1.0
var shield_mul := 1.0
var orbit_mul := 1.0
var dust_per_moon := C.DUST_PER_MOON
var coin_mul := 1.0

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var knock := Vector2.ZERO        # push from bumps, fades out quickly
var input_dir := Vector2.ZERO    # where this planet wants to go (length 0..1)

var alive := true
var score := 0
var pops := 0                    # planets popped this round
var dust_progress := 0
var shield := 0.0
var respawn_timer := 0.0
var dizzy := 0.0                 # > 0 while slowed after being hit
var dash_t := 0.0                # > 0 while dashing
var dash_cd := 0.0               # > 0 while dash is recharging
var dash_dir := Vector2.RIGHT
var trail_t := 0.0

var orbit_angle := 0.0
var moon_ang: Array[float] = []   # each moon's slot on the ring
var moon_scale: Array[float] = [] # 0..1 pop-in animation
var moon_pos := PackedVector2Array()
var radius := C.PLANET_BASE_RADIUS
var ring_r := 80.0

# Face animation
var look := Vector2.RIGHT
var blink_t := 2.0
var squash := 0.0

# Bot brain state (unused for the player)
var steer := Vector2.ZERO
var think_t := 0.0
var aggression := 0.5
var chase_t := 0.0
var chase_cd := 0.0
var want_dash := false

var moons: int:
	get:
		return moon_ang.size()


## Dresses the planet. `outfit` is {skin, hat, trail, moon}; skin is a catalog entry.
func apply_look(outfit: Dictionary) -> void:
	var skin: Dictionary = outfit.skin
	color = skin.color
	style = skin.style
	hat = outfit.hat
	trail = outfit.trail
	moon_style = outfit.moon
	var stats: Dictionary = skin.get("stats", {})
	speed_mul = stats.get("speed", 1.0)
	pull_mul = stats.get("pull", 1.0)
	dash_cd_mul = stats.get("dash_cd", 1.0)
	shield_mul = stats.get("shield", 1.0)
	orbit_mul = stats.get("orbit", 1.0)
	coin_mul = stats.get("coins", 1.0)
	max_moons = C.MAX_MOONS + int(stats.get("max_moons", 0))
	start_moons = C.START_MOONS + int(stats.get("start_moons", 0))
	dust_per_moon = C.DUST_PER_MOON + int(stats.get("dust_per_moon", 0))


func target_radius() -> float:
	return C.PLANET_BASE_RADIUS + C.PLANET_RADIUS_PER_MOON * moons


func target_ring() -> float:
	return target_radius() + C.RING_BASE_GAP + C.RING_GAP_PER_MOON * moons


func max_speed() -> float:
	var speed := lerpf(C.SPEED_SMALL, C.SPEED_BIG, float(moons) / C.MAX_MOONS) * speed_mul
	return speed * C.HIT_DIZZY_SPEED if dizzy > 0.0 else speed


func add_moon() -> bool:
	if moons >= max_moons:
		return false
	var n := moons
	moon_ang.append(TAU * n / (n + 1))
	moon_scale.append(0.0)
	refresh_moon_pos()
	return true


func remove_moon(i: int) -> void:
	moon_ang.remove_at(i)
	moon_scale.remove_at(i)
	refresh_moon_pos()


func set_moons(n: int) -> void:
	moon_ang.clear()
	moon_scale.clear()
	for k in n:
		moon_ang.append(TAU * k / n)
		moon_scale.append(0.0)
	radius = target_radius()
	ring_r = target_ring()
	refresh_moon_pos()


## Start a dash in the direction we are steering (or facing). False if recharging.
func try_dash() -> bool:
	if not alive or dash_cd > 0.0:
		return false
	dash_dir = input_dir.normalized() if input_dir.length() > 0.2 else look.normalized()
	dash_t = C.DASH_TIME
	dash_cd = C.DASH_COOLDOWN * dash_cd_mul
	return true


## Moves the planet. arena_r is the size of the arena; grip says how quickly
## it changes direction (lower = slippery).
func tick(delta: float, arena_r: float, grip: float) -> void:
	dash_cd = maxf(0.0, dash_cd - delta)
	if dash_t > 0.0:
		dash_t -= delta
		vel = dash_dir * C.DASH_SPEED
	else:
		var target := input_dir.limit_length(1.0) * max_speed()
		vel = vel.lerp(target, 1.0 - exp(-grip * delta))
	knock = knock.lerp(Vector2.ZERO, 1.0 - exp(-5.0 * delta))
	pos += (vel + knock) * delta
	var limit := arena_r - radius
	if pos.length() > limit:
		pos = pos.normalized() * limit

	var ease_t := 1.0 - exp(-6.0 * delta)
	radius = lerpf(radius, target_radius(), ease_t)
	ring_r = lerpf(ring_r, target_ring(), ease_t)
	orbit_angle = fposmod(orbit_angle + C.MOON_LINEAR_SPEED * orbit_mul / ring_r * delta, TAU)
	var n := moons
	for k in n:
		moon_ang[k] = lerp_angle(moon_ang[k], TAU * k / n, ease_t)
		moon_scale[k] = move_toward(moon_scale[k], 1.0, delta * 5.0)

	shield = maxf(0.0, shield - delta)
	dizzy = maxf(0.0, dizzy - delta)
	squash = maxf(0.0, squash - delta * 2.5)
	if vel.length() > 20.0:
		look = look.lerp(vel.normalized(), 1.0 - exp(-8.0 * delta))
	blink_t -= delta
	if blink_t < 0.0:
		blink_t = randf_range(2.0, 5.0)
	refresh_moon_pos()


func refresh_moon_pos() -> void:
	var n := moons
	moon_pos.resize(n)
	for k in n:
		moon_pos[k] = pos + Vector2.from_angle(orbit_angle + moon_ang[k]) * ring_r
