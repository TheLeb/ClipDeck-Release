extends RefCounted
## All drawing helpers. The game needs no image files: at start-up it paints
## a few white shapes (circle, ring, sparkle, smile) into one small texture,
## and everything on screen is a tinted, stretched copy of those. Drawing
## copies of one texture is something phones can do extremely fast, because
## the graphics chip receives them all in a single batch.

const C = preload("res://scripts/config.gd")

# Where each shape sits inside the shared texture.
const _CIRCLE := Rect2(0, 0, 128, 128)     # filled disc, radius 58
const _SPARKLE := Rect2(128, 0, 64, 64)    # four-point star, tips at 28
const _SMILE := Rect2(192, 0, 64, 64)      # curved mouth
const _RING := Rect2(256, 0, 256, 256)     # thin circle outline, radius 122

static var _atlas: ImageTexture


## Call once before anything is drawn.
static func setup() -> void:
	if _atlas != null:
		return
	var img := Image.create(512, 256, true, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for y in 128:
		for x in 128:
			var a := clampf(58.5 - Vector2(x - 63.5, y - 63.5).length(), 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, a))
	for y in 256:
		for x in 256:
			var a := clampf(1.6 - absf(Vector2(x - 127.5, y - 127.5).length() - 122.0), 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(256 + x, y, Color(1, 1, 1, a))
	for y in 64:
		for x in 64:
			var hits := 0
			for sy in 3:
				for sx in 3:
					var u := absf(x + (sx + 0.5) / 3.0 - 32.0) / 28.0
					var v := absf(y + (sy + 0.5) / 3.0 - 32.0) / 28.0
					if sqrt(u) + sqrt(v) < 1.0:
						hits += 1
			if hits > 0:
				img.set_pixel(128 + x, y, Color(1, 1, 1, hits / 9.0))
	var centre := Vector2(32, 20)
	var end_a := centre + Vector2.from_angle(PI * 0.12) * 22.0
	var end_b := centre + Vector2.from_angle(PI * 0.88) * 22.0
	for y in 64:
		for x in 64:
			var p := Vector2(x + 0.5, y + 0.5)
			var v := p - centre
			var ang := v.angle()
			var d := absf(v.length() - 22.0) if ang > PI * 0.12 and ang < PI * 0.88 else minf(p.distance_to(end_a), p.distance_to(end_b))
			var a := clampf(4.0 - d, 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(192 + x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_atlas = ImageTexture.create_from_image(img)


## Filled circle.
static func disc(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	var h := r * (64.0 / 58.0)
	ci.draw_texture_rect_region(_atlas, Rect2(pos.x - h, pos.y - h, h * 2.0, h * 2.0), _CIRCLE, col)


## Thin circle outline (orbit rings).
static func ring(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	var h := r * (128.0 / 122.0)
	ci.draw_texture_rect_region(_atlas, Rect2(pos.x - h, pos.y - h, h * 2.0, h * 2.0), _RING, col)


static func planet(ci: CanvasItem, pos: Vector2, r: float, col: Color, look: Vector2, blinking: bool, squash: float, scared := false) -> void:
	disc(ci, pos, r + 3.5, col.darkened(0.55))
	disc(ci, pos, r, col.darkened(0.25))
	disc(ci, pos + Vector2(-r, -r) * 0.07, r * 0.91, col)
	disc(ci, pos + Vector2(r * 0.42, r * 0.5), r * 0.13, col.darkened(0.12))
	disc(ci, pos + Vector2(-r * 0.55, r * 0.5), r * 0.08, col.darkened(0.12))
	disc(ci, pos + Vector2(-r * 0.4, -r * 0.48), r * 0.15, Color(1, 1, 1, 0.55))

	var shift := look * r * 0.12
	for sx: float in [-1.0, 1.0]:
		var eye := pos + Vector2(sx * r * 0.34, -r * 0.08) + shift
		disc(ci, pos + Vector2(sx * r * 0.58, r * 0.24) + shift * 0.5, r * 0.12, Color(1.0, 0.4, 0.55, 0.5))
		if squash > 0.0:
			# Bumped: squeezed-shut eyes  > <
			var a := eye + Vector2(-sx * r * 0.14, 0)
			ci.draw_line(a, eye + Vector2(sx * r * 0.12, -r * 0.13), C.INK, maxf(2.0, r * 0.08), true)
			ci.draw_line(a, eye + Vector2(sx * r * 0.12, r * 0.13), C.INK, maxf(2.0, r * 0.08), true)
		elif blinking:
			ci.draw_line(eye - Vector2(r * 0.15, 0), eye + Vector2(r * 0.15, 0), C.INK, maxf(2.0, r * 0.08), true)
		else:
			disc(ci, eye, r * 0.21, Color.WHITE)
			var pupil := eye + look * r * 0.07
			disc(ci, pupil, r * 0.12, C.INK)
			disc(ci, pupil + Vector2(-r, -r) * 0.045, r * 0.045, Color.WHITE)

	var mouth := pos + Vector2(0, r * 0.26) + shift
	var s := r * 0.2 / 22.0   # mouth size: screen units per texture pixel
	if squash > 0.0:
		disc(ci, mouth + Vector2(0, r * 0.08), r * 0.11, C.INK)
	elif scared:
		# No moons left: worried frown (the smile upside down) and a sweat drop.
		var top := mouth + Vector2(0, r * 0.24) - Vector2(32, 44) * s
		ci.draw_texture_rect_region(_atlas, Rect2(top.x, top.y + 64.0 * s, 64.0 * s, -64.0 * s), _SMILE, C.INK)
		disc(ci, pos + Vector2(r * 0.74, -r * 0.42), r * 0.11, Color("8fdcff"))
	else:
		ci.draw_texture_rect_region(_atlas, Rect2(mouth - Vector2(32, 20) * s, Vector2(64, 64) * s), _SMILE, C.INK)


## Little crown worn by whoever is first on the leaderboard.
static func crown(ci: CanvasItem, pos: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	for v: Vector2 in [Vector2(-1, 0), Vector2(-1, -0.9), Vector2(-0.5, -0.4), Vector2(0, -1.1), Vector2(0.5, -0.4), Vector2(1, -0.9), Vector2(1, 0)]:
		pts.append(pos + v * s)
	ci.draw_colored_polygon(pts, C.GOLD)
	pts.append(pts[0])
	ci.draw_polyline(pts, C.INK, 3.0, true)


static func moon(ci: CanvasItem, pos: Vector2, r: float, col: Color, alpha := 1.0) -> void:
	var body := col.lightened(0.3)
	disc(ci, pos, r + 2.5, Color(col.darkened(0.5), alpha))
	disc(ci, pos, r, Color(body.darkened(0.15), alpha))
	disc(ci, pos + Vector2(-r, -r) * 0.1, r * 0.85, Color(body, alpha))
	disc(ci, pos + Vector2(-r, -r) * 0.35, r * 0.22, Color(1, 1, 1, 0.7 * alpha))


static func sparkle(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	var h := r * (32.0 / 28.0)
	disc(ci, pos, r * 1.6, Color(col, 0.16 * col.a))
	ci.draw_texture_rect_region(_atlas, Rect2(pos.x - h, pos.y - h, h * 2.0, h * 2.0), _SPARKLE, col)
	disc(ci, pos, r * 0.25, Color(1, 1, 1, 0.9 * col.a))


static func shield(ci: CanvasItem, pos: Vector2, r: float, time: float) -> void:
	var pulse := 0.5 + 0.5 * sin(time * 9.0)
	disc(ci, pos, r + 2.0, Color(0.8, 0.97, 1.0, 0.45 + 0.25 * pulse))
	disc(ci, pos, r - 1.5, Color(0.45, 0.6, 0.95, 0.5))


static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, col: Color, outline := 6) -> void:
	var w := 400.0
	var at := pos - Vector2(w * 0.5, 0)
	ci.draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, outline, Color(C.INK, col.a))
	ci.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)
