extends Node2D
## Night-sky backdrop: a colour gradient and twinkling stars
## that drift slower than the game world (parallax) to give a feeling of depth.

const C = preload("res://scripts/config.gd")
const Art = preload("res://scripts/art.gd")

var cam_pos := Vector2.ZERO
var top := Color("1c1a52")      # current sky colours (they glide to the target)
var bottom := Color("5a2a8a")
var _target_top := top
var _target_bottom := bottom
var _time := 0.0
var _stars: Array[Dictionary] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 70:
		_stars.append({
			"p": Vector2(rng.randf(), rng.randf()),
			"size": rng.randf_range(1.5, 4.0),
			"depth": rng.randf_range(0.08, 0.35),
			"phase": rng.randf() * TAU,
			"col": C.DUST_COLORS[rng.randi() % C.DUST_COLORS.size()],
		})


## Each map has its own sky; the colours fade over smoothly.
func set_sky(sky_top: Color, sky_bottom: Color) -> void:
	_target_top = sky_top
	_target_bottom = sky_bottom


func _process(delta: float) -> void:
	_time += delta
	var t := 1.0 - exp(-3.0 * delta)
	top = top.lerp(_target_top, t)
	bottom = bottom.lerp(_target_bottom, t)
	queue_redraw()


func _draw() -> void:
	var s := get_viewport_rect().size
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([top, top, bottom, bottom]))

	var wrap := s + Vector2(200, 200)
	for st: Dictionary in _stars:
		var base: Vector2 = st.p
		var depth: float = st.depth
		var p := Vector2(
			fposmod(base.x * wrap.x - cam_pos.x * depth, wrap.x),
			fposmod(base.y * wrap.y - cam_pos.y * depth, wrap.y)) - Vector2(100, 100)
		var phase: float = st.phase
		var twinkle := 0.55 + 0.45 * sin(_time * 2.0 + phase)
		var col: Color = st.col
		var size: float = st.size
		Art.disc(self, p, size, Color(col, 0.25 + 0.6 * twinkle))
