extends RefCounted
## All drawing helpers. The game needs no image files: at start-up it paints
## a few white shapes (circle, ring, sparkle, smile, triangle, square,
## diamond, hoop) into one small texture, and everything on screen is a
## tinted, stretched copy of those. Drawing copies of one texture is something
## phones do extremely fast, because the graphics chip receives them all in a
## single batch. Keep new art to these shapes and it stays fast.

const C = preload("res://scripts/config.gd")

# Where each shape sits inside the shared texture.
const _CIRCLE := Rect2(0, 0, 128, 128)       # filled disc, radius 58
const _SPARKLE := Rect2(128, 0, 64, 64)      # four-point star, tips at 28
const _SMILE := Rect2(192, 0, 64, 64)        # curved mouth
const _RING := Rect2(256, 0, 256, 256)       # thin circle outline, radius 122
const _TRI := Rect2(0, 128, 64, 64)          # triangle pointing up
const _BOX := Rect2(72, 136, 48, 48)         # solid square (middle of its tile)
const _DIAMOND := Rect2(128, 128, 64, 64)    # diamond, tips at 27
const _HOOP := Rect2(192, 128, 64, 64)       # thick ring, radius 22

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
	var mouth_centre := Vector2(32, 20)
	var mouth_a := mouth_centre + Vector2.from_angle(PI * 0.12) * 22.0
	var mouth_b := mouth_centre + Vector2.from_angle(PI * 0.88) * 22.0
	for y in 64:
		for x in 64:
			var p := Vector2(x + 0.5, y + 0.5)
			var dx := absf(p.x - 32.0)
			var dy := absf(p.y - 32.0)

			# Sparkle: 3x3 samples per pixel for smooth edges.
			var hits := 0
			for sy in 3:
				for sx in 3:
					var u := absf(x + (sx + 0.5) / 3.0 - 32.0) / 28.0
					var v := absf(y + (sy + 0.5) / 3.0 - 32.0) / 28.0
					if sqrt(u) + sqrt(v) < 1.0:
						hits += 1
			if hits > 0:
				img.set_pixel(128 + x, y, Color(1, 1, 1, hits / 9.0))

			# Smile.
			var to_mouth := p - mouth_centre
			var ang := to_mouth.angle()
			var d := absf(to_mouth.length() - 22.0) if ang > PI * 0.12 and ang < PI * 0.88 else minf(p.distance_to(mouth_a), p.distance_to(mouth_b))
			var a := clampf(4.0 - d, 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(192 + x, y, Color(1, 1, 1, a))

			# Triangle: tip at the top middle, flat base at the bottom.
			a = clampf(minf(59.0 - p.y, ((p.y - 5.0) * 0.5 - dx) * 0.894) + 0.5, 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, 128 + y, Color(1, 1, 1, a))

			# Diamond.
			a = clampf((27.0 - dx - dy) * 0.707 + 0.5, 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(128 + x, 128 + y, Color(1, 1, 1, a))

			# Hoop.
			a = clampf(4.0 - absf(Vector2(dx, dy).length() - 22.0), 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(192 + x, 128 + y, Color(1, 1, 1, a))
	img.fill_rect(Rect2i(66, 130, 60, 60), Color.WHITE)   # square
	img.generate_mipmaps()
	_atlas = ImageTexture.create_from_image(img)


# ------------------------------------------------------------ basic shapes --

## Filled circle.
static func disc(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	var h := r * (64.0 / 58.0)
	ci.draw_texture_rect_region(_atlas, Rect2(pos.x - h, pos.y - h, h * 2.0, h * 2.0), _CIRCLE, col)


## Filled ellipse.
static func oval(ci: CanvasItem, pos: Vector2, rx: float, ry: float, col: Color) -> void:
	var hx := rx * (64.0 / 58.0)
	var hy := ry * (64.0 / 58.0)
	ci.draw_texture_rect_region(_atlas, Rect2(pos.x - hx, pos.y - hy, hx * 2.0, hy * 2.0), _CIRCLE, col)


## Thin circle outline (orbit rings).
static func ring(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	var h := r * (128.0 / 122.0)
	ci.draw_texture_rect_region(_atlas, Rect2(pos.x - h, pos.y - h, h * 2.0, h * 2.0), _RING, col)


## Thick ring that may be squashed into an ellipse (halo).
static func hoop(ci: CanvasItem, pos: Vector2, rx: float, ry: float, col: Color) -> void:
	var hx := rx * (32.0 / 22.0)
	var hy := ry * (32.0 / 22.0)
	ci.draw_texture_rect_region(_atlas, Rect2(pos.x - hx, pos.y - hy, hx * 2.0, hy * 2.0), _HOOP, col)


## Solid rectangle.
static func box(ci: CanvasItem, rect: Rect2, col: Color) -> void:
	ci.draw_texture_rect_region(_atlas, rect, _BOX, col)


## Triangle pointing up, filling the rectangle.
static func tri(ci: CanvasItem, rect: Rect2, col: Color) -> void:
	ci.draw_texture_rect_region(_atlas, rect, _TRI, col)


## Diamond.
static func gem(ci: CanvasItem, pos: Vector2, rx: float, ry: float, col: Color) -> void:
	var hx := rx * (32.0 / 27.0)
	var hy := ry * (32.0 / 27.0)
	ci.draw_texture_rect_region(_atlas, Rect2(pos.x - hx, pos.y - hy, hx * 2.0, hy * 2.0), _DIAMOND, col)


## Four-point star.
static func star(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	var h := r * (32.0 / 28.0)
	ci.draw_texture_rect_region(_atlas, Rect2(pos.x - h, pos.y - h, h * 2.0, h * 2.0), _SPARKLE, col)


# ----------------------------------------------------------------- planets --

## style is the skin's pattern (see catalog.gd), hat a hat id such as "hat_party".
static func planet(ci: CanvasItem, pos: Vector2, r: float, col: Color, look: Vector2, blinking: bool, squash: float,
		scared := false, style := "plain", hat := "hat_none") -> void:
	if hat == "hat_cat" or hat == "hat_bobble":
		_hat_behind(ci, pos, r, col, hat)
	disc(ci, pos, r + 3.5, col.darkened(0.55))
	disc(ci, pos, r, col.darkened(0.25))
	disc(ci, pos + Vector2(-r, -r) * 0.07, r * 0.91, col)
	_marks(ci, pos, r, col, style)
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
		ci.draw_texture_rect_region(_atlas, Rect2(top.x, top.y, 64.0 * s, -64.0 * s), _SMILE, C.INK)
		disc(ci, pos + Vector2(r * 0.74, -r * 0.42), r * 0.11, Color("8fdcff"))
	else:
		ci.draw_texture_rect_region(_atlas, Rect2(mouth - Vector2(32, 20) * s, Vector2(64, 64) * s), _SMILE, C.INK)

	if hat != "hat_none":
		_hat(ci, pos, r, hat)


## The pattern that makes each skin recognisable. Everything stays inside the body.
static func _marks(ci: CanvasItem, pos: Vector2, r: float, col: Color, style: String) -> void:
	match style:
		"comet":
			oval(ci, pos + Vector2(0.3, -0.64) * r, r * 0.34, r * 0.07, Color(1, 1, 1, 0.65))
			oval(ci, pos + Vector2(0.52, -0.44) * r, r * 0.22, r * 0.06, Color(1, 1, 1, 0.65))
			oval(ci, pos + Vector2(-0.3, 0.7) * r, r * 0.3, r * 0.06, Color(1, 1, 1, 0.5))
		"rocky":
			for crater: Vector3 in [Vector3(-0.5, -0.5, 0.17), Vector3(0.56, -0.44, 0.12), Vector3(0.36, 0.6, 0.15), Vector3(-0.42, 0.62, 0.1)]:
				disc(ci, pos + Vector2(crater.x, crater.y) * r, r * crater.z, col.darkened(0.28))
				disc(ci, pos + Vector2(crater.x + 0.02, crater.y + 0.03) * r, r * crater.z * 0.7, col.darkened(0.14))
		"magnet":
			oval(ci, pos + Vector2(0, -0.74) * r, r * 0.5, r * 0.17, Color("fff8ee"))
			oval(ci, pos + Vector2(0, 0.78) * r, r * 0.44, r * 0.13, Color("c9d6ff"))
		"zippy":
			oval(ci, pos + Vector2(0, -0.8) * r, r * 0.44, r * 0.07, Color("ff8a2a"))
			oval(ci, pos + Vector2(0, -0.58) * r, r * 0.66, r * 0.07, Color("ff8a2a"))
			oval(ci, pos + Vector2(0, 0.76) * r, r * 0.5, r * 0.07, Color("ff8a2a"))
		"gold":
			oval(ci, pos + Vector2(-0.15, -0.66) * r, r * 0.46, r * 0.17, Color(1, 1, 1, 0.45))
			star(ci, pos + Vector2(0.56, -0.5) * r, r * 0.24, Color.WHITE)
			star(ci, pos + Vector2(-0.6, 0.52) * r, r * 0.17, Color.WHITE)
		"bubble":
			oval(ci, pos + Vector2(-0.2, -0.6) * r, r * 0.52, r * 0.24, Color(1, 1, 1, 0.45))
			disc(ci, pos + Vector2(0.56, 0.52) * r, r * 0.1, Color(1, 1, 1, 0.65))
			disc(ci, pos + Vector2(0.36, 0.72) * r, r * 0.05, Color(1, 1, 1, 0.65))
		"swirl":
			disc(ci, pos + Vector2(0.38, -0.52) * r, r * 0.3, col.lightened(0.5))
			disc(ci, pos + Vector2(0.47, -0.43) * r, r * 0.25, col)
			disc(ci, pos + Vector2(-0.5, 0.52) * r, r * 0.22, col.lightened(0.5))
			disc(ci, pos + Vector2(-0.43, 0.59) * r, r * 0.18, col)
		_:
			disc(ci, pos + Vector2(r * 0.42, r * 0.5), r * 0.13, col.darkened(0.12))
			disc(ci, pos + Vector2(-r * 0.55, r * 0.5), r * 0.08, col.darkened(0.12))


## How far a hat sticks out above the planet, as a share of the planet's radius.
static func hat_height(hat: String) -> float:
	match hat:
		"hat_party":
			return 0.9
		"hat_top":
			return 0.7
		"hat_bobble":
			return 0.75
		"hat_halo":
			return 0.45
		"hat_cat":
			return 0.4
		"hat_bow":
			return 0.3
		"hat_flower":
			return 0.15
	return 0.0


## Hat parts that sit behind the head.
static func _hat_behind(ci: CanvasItem, pos: Vector2, r: float, col: Color, hat: String) -> void:
	if hat == "hat_cat":
		for sx: float in [-1.0, 1.0]:
			var x := pos.x + sx * r * 0.56
			tri(ci, Rect2(x - r * 0.36, pos.y - r * 1.42, r * 0.72, r * 0.86), col.darkened(0.55))
			tri(ci, Rect2(x - r * 0.26, pos.y - r * 1.28, r * 0.52, r * 0.66), col)
			tri(ci, Rect2(x - r * 0.14, pos.y - r * 1.12, r * 0.28, r * 0.4), Color("ffb3d1"))
	else:
		box(ci, Rect2(pos.x - r * 0.04, pos.y - r * 1.5, r * 0.08, r * 0.7), C.INK)
		disc(ci, pos + Vector2(0, -1.56) * r, r * 0.19, C.INK)
		disc(ci, pos + Vector2(0, -1.56) * r, r * 0.14, Color("ff5a8a"))
		disc(ci, pos + Vector2(-0.05, -1.61) * r, r * 0.045, Color(1, 1, 1, 0.8))


## Hat parts that sit on top of the head.
static func _hat(ci: CanvasItem, pos: Vector2, r: float, hat: String) -> void:
	match hat:
		"hat_party":
			tri(ci, Rect2(pos.x - r * 0.48, pos.y - r * 1.9, r * 0.96, r * 1.1), C.INK)
			tri(ci, Rect2(pos.x - r * 0.38, pos.y - r * 1.76, r * 0.76, r * 0.9), Color("ff5a8a"))
			oval(ci, pos + Vector2(0, -0.9) * r, r * 0.42, r * 0.1, Color("ffd93d"))
			disc(ci, pos + Vector2(0, -1.74) * r, r * 0.14, Color("ffd93d"))
		"hat_top":
			oval(ci, pos + Vector2(0, -0.88) * r, r * 0.68, r * 0.14, C.INK)
			box(ci, Rect2(pos.x - r * 0.42, pos.y - r * 1.62, r * 0.84, r * 0.76), C.INK)
			box(ci, Rect2(pos.x - r * 0.42, pos.y - r * 1.12, r * 0.84, r * 0.14), Color("ff5a8a"))
		"hat_halo":
			hoop(ci, pos + Vector2(0, -1.24) * r, r * 0.52, r * 0.17, Color("ffd93d"))
		"hat_bow":
			var knot := pos + Vector2(0, -1.02) * r
			for sx: float in [-1.0, 1.0]:
				gem(ci, knot + Vector2(sx * 0.3 * r, 0), r * 0.34, r * 0.27, C.INK)
				gem(ci, knot + Vector2(sx * 0.3 * r, 0), r * 0.26, r * 0.2, Color("ff5a8a"))
			disc(ci, knot, r * 0.13, Color("d93a6e"))
		"hat_flower":
			var middle := pos + Vector2(0.56, -0.84) * r
			for i in 5:
				disc(ci, middle + Vector2.from_angle(TAU * i / 5.0 - PI * 0.5) * r * 0.18, r * 0.14, Color.WHITE)
			disc(ci, middle, r * 0.12, Color("ffd93d"))


## A planet for menus and the shop: wears `look` ({skin, hat, trail, moon})
## and can have a few moons circling it (moon_r 0 = sized to fit the planet).
static func avatar(ci: CanvasItem, pos: Vector2, r: float, look: Dictionary, t: float, moons := 0, ring_r := 0.0, moon_r := 0.0) -> void:
	var skin: Dictionary = look.skin
	var col: Color = skin.color
	var moon_style: String = look.moon
	if moons > 0:
		ring(ci, pos, ring_r, Color(col, 0.4))
		for k in moons:
			moon(ci, pos + Vector2.from_angle(t * 1.3 + TAU * k / moons) * ring_r, moon_r if moon_r > 0.0 else r * 0.24, col, 1.0, moon_style)
	var gaze := Vector2.from_angle(t * 0.7) * 0.8
	var style: String = skin.style
	var hat: String = look.hat
	planet(ci, pos, r, col, gaze, fmod(t, 3.5) < 0.12, 0.0, false, style, hat)


## Little crown worn by whoever is first on the leaderboard.
static func crown(ci: CanvasItem, pos: Vector2, s: float) -> void:
	box(ci, Rect2(pos.x - s * 1.12, pos.y - s * 0.62, s * 2.24, s * 0.74), C.INK)
	for i in 3:
		var x := pos.x + (i - 1) * s * 0.72
		tri(ci, Rect2(x - s * 0.52, pos.y - s * 1.36, s * 1.04, s * 1.0), C.INK)
	box(ci, Rect2(pos.x - s, pos.y - s * 0.5, s * 2.0, s * 0.5), C.GOLD)
	for i in 3:
		var x := pos.x + (i - 1) * s * 0.72
		tri(ci, Rect2(x - s * 0.36, pos.y - s * 1.12, s * 0.72, s * 0.76), C.GOLD)


# ------------------------------------------------------------ other things --

static func moon(ci: CanvasItem, pos: Vector2, r: float, col: Color, alpha := 1.0, style := "moon_round") -> void:
	var body := Color(col.lightened(0.3), alpha)
	var edge := Color(col.darkened(0.5), alpha)
	match style:
		"moon_star":
			star(ci, pos, r * 2.0, edge)
			star(ci, pos, r * 1.5, body)
			disc(ci, pos, r * 0.36, Color(1, 1, 1, 0.85 * alpha))
		"moon_donut":
			disc(ci, pos, r + 2.5, edge)
			disc(ci, pos, r, body)
			disc(ci, pos, r * 0.42, edge)
			disc(ci, pos + Vector2(-r, -r) * 0.45, r * 0.16, Color(1, 1, 1, 0.7 * alpha))
		"moon_gem":
			gem(ci, pos, r * 1.5, r * 1.5, edge)
			gem(ci, pos, r * 1.15, r * 1.15, body)
			gem(ci, pos + Vector2(-r, -r) * 0.22, r * 0.36, r * 0.36, Color(1, 1, 1, 0.7 * alpha))
		_:
			disc(ci, pos, r + 2.5, edge)
			disc(ci, pos, r, Color(body.darkened(0.15), alpha))
			disc(ci, pos + Vector2(-r, -r) * 0.1, r * 0.85, body)
			disc(ci, pos + Vector2(-r, -r) * 0.35, r * 0.22, Color(1, 1, 1, 0.7 * alpha))


static func sparkle(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	disc(ci, pos, r * 1.6, Color(col, 0.16 * col.a))
	star(ci, pos, r, col)
	disc(ci, pos, r * 0.25, Color(1, 1, 1, 0.9 * col.a))


static func shield(ci: CanvasItem, pos: Vector2, r: float, time: float) -> void:
	var pulse := 0.5 + 0.5 * sin(time * 9.0)
	disc(ci, pos, r + 2.0, Color(0.8, 0.97, 1.0, 0.45 + 0.25 * pulse))
	disc(ci, pos, r - 1.5, Color(0.45, 0.6, 0.95, 0.5))


## Asteroid obstacle.
static func rock(ci: CanvasItem, pos: Vector2, r: float, tint: Color) -> void:
	disc(ci, pos, r + 4.0, tint.darkened(0.62))
	disc(ci, pos, r, tint.darkened(0.28))
	disc(ci, pos + Vector2(-r, -r) * 0.06, r * 0.93, tint)
	disc(ci, pos + Vector2(-0.34, -0.3) * r, r * 0.22, tint.darkened(0.2))
	disc(ci, pos + Vector2(0.42, 0.08) * r, r * 0.16, tint.darkened(0.2))
	disc(ci, pos + Vector2(-0.1, 0.52) * r, r * 0.19, tint.darkened(0.2))
	disc(ci, pos + Vector2(-0.5, -0.52) * r, r * 0.1, Color(1, 1, 1, 0.3))


static func coin(ci: CanvasItem, pos: Vector2, r: float) -> void:
	disc(ci, pos, r, Color("b9770e"))
	disc(ci, pos, r * 0.86, Color("ffd93d"))
	disc(ci, pos, r * 0.58, Color("ffe98a"))
	disc(ci, pos + Vector2(-r, -r) * 0.3, r * 0.16, Color(1, 1, 1, 0.85))


static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, col: Color, outline := 6) -> void:
	var w := 400.0
	var at := pos - Vector2(w * 0.5, 0)
	if outline > 0:
		ci.draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, outline, Color(C.INK, col.a))
	ci.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)
