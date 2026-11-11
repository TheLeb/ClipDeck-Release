extends RefCounted
## One planet in the arena. The player and the bots are all Planets;
## the only difference is who fills in `input_dir` every frame.

const C = preload("res://scripts/config.gd")

var is_player := false
var pname := ""
var color := Color.WHITE

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var knock := Vector2.ZERO        # push from bumps, fades out quickly
var input_dir := Vector2.ZERO    # where this planet wants to go (length 0..1)

var alive := true
var score := 0
var dust_progress := 0
var shield := 0.0
var respawn_timer := 0.0
var dash_t := 0.0                # > 0 while dashing
var dash_cd := 0.0               # > 0 while dash is recharging
var dash_dir := Vector2.RIGHT

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


func target_radius() -> float:
	return C.PLANET_BASE_RADIUS + C.PLANET_RADIUS_PER_MOON * moons


func target_ring() -> float:
	return target_radius() + C.RING_BASE_GAP + C.RING_GAP_PER_MOON * moons


func max_speed() -> float:
	return lerpf(C.SPEED_SMALL, C.SPEED_BIG, float(moons) / C.MAX_MOONS)


func add_moon() -> bool:
	if moons >= C.MAX_MOONS:
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
	dash_cd = C.DASH_COOLDOWN
	return true


func tick(delta: float) -> void:
	dash_cd = maxf(0.0, dash_cd - delta)
	if dash_t > 0.0:
		dash_t -= delta
		vel = dash_dir * C.DASH_SPEED
	else:
		var target := input_dir.limit_length(1.0) * max_speed()
		vel = vel.lerp(target, 1.0 - exp(-7.0 * delta))
	knock = knock.lerp(Vector2.ZERO, 1.0 - exp(-5.0 * delta))
	pos += (vel + knock) * delta
	var limit := C.ARENA_RADIUS - radius
	if pos.length() > limit:
		pos = pos.normalized() * limit

	var ease_t := 1.0 - exp(-6.0 * delta)
	radius = lerpf(radius, target_radius(), ease_t)
	ring_r = lerpf(ring_r, target_ring(), ease_t)
	orbit_angle = fposmod(orbit_angle + C.MOON_LINEAR_SPEED / ring_r * delta, TAU)
	var n := moons
	for k in n:
		moon_ang[k] = lerp_angle(moon_ang[k], TAU * k / n, ease_t)
		moon_scale[k] = move_toward(moon_scale[k], 1.0, delta * 5.0)

	shield = maxf(0.0, shield - delta)
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
