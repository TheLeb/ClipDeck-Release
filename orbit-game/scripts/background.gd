extends Node2D
## Night-sky backdrop: a colour gradient, soft glows and twinkling stars
## that drift slower than the game world (parallax) to give a feeling of depth.

const C = preload("res://scripts/config.gd")

var cam_pos := Vector2.ZERO
var _time := 0.0
var _stars: Array[Dictionary] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 90:
		_stars.append({
			"p": Vector2(rng.randf(), rng.randf()),
			"size": rng.randf_range(1.5, 4.0),
			"depth": rng.randf_range(0.08, 0.35),
			"phase": rng.randf() * TAU,
			"col": C.DUST_COLORS[rng.randi() % C.DUST_COLORS.size()],
		})


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var s := get_viewport_rect().size
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([C.BG_TOP, C.BG_TOP, C.BG_BOTTOM, C.BG_BOTTOM]))

	var wrap := s + Vector2(200, 200)
	var glow := Vector2(fposmod(wrap.x * 0.3 - cam_pos.x * 0.04, wrap.x), fposmod(wrap.y * 0.35 - cam_pos.y * 0.04, wrap.y)) - Vector2(100, 100)
	for k in 14:
		draw_circle(glow, 440.0 - k * 28.0, Color(1.0, 0.5, 0.8, 0.008))
		draw_circle(s - glow, 400.0 - k * 26.0, Color(0.4, 0.9, 1.0, 0.007))

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
		draw_circle(p, size, Color(col, 0.25 + 0.6 * twinkle), true, -1.0, true)
