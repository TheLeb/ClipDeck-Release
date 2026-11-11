extends RefCounted
## All drawing helpers. Everything is drawn with simple shapes, so the game
## needs no image files and runs well on cheap phones.

const C = preload("res://scripts/config.gd")


static func planet(ci: CanvasItem, pos: Vector2, r: float, col: Color, look: Vector2, blinking: bool, squash: float, scared := false) -> void:
	var outline := col.darkened(0.55)
	ci.draw_circle(pos, r + 3.5, outline, true, -1.0, true)
	ci.draw_circle(pos, r, col.darkened(0.25), true, -1.0, true)
	ci.draw_circle(pos + Vector2(-r, -r) * 0.07, r * 0.91, col, true, -1.0, true)
	ci.draw_circle(pos + Vector2(r * 0.42, r * 0.5), r * 0.13, col.darkened(0.12), true, -1.0, true)
	ci.draw_circle(pos + Vector2(-r * 0.55, r * 0.5), r * 0.08, col.darkened(0.12), true, -1.0, true)
	ci.draw_circle(pos + Vector2(-r * 0.4, -r * 0.48), r * 0.15, Color(1, 1, 1, 0.55), true, -1.0, true)

	var shift := look * r * 0.12
	for sx: float in [-1.0, 1.0]:
		var eye := pos + Vector2(sx * r * 0.34, -r * 0.08) + shift
		ci.draw_circle(pos + Vector2(sx * r * 0.58, r * 0.24) + shift * 0.5, r * 0.12, Color(1.0, 0.4, 0.55, 0.5), true, -1.0, true)
		if squash > 0.0:
			# Bumped: squeezed-shut eyes  > <
			var a := eye + Vector2(-sx * r * 0.14, 0)
			ci.draw_line(a, eye + Vector2(sx * r * 0.12, -r * 0.13), C.INK, maxf(2.0, r * 0.08), true)
			ci.draw_line(a, eye + Vector2(sx * r * 0.12, r * 0.13), C.INK, maxf(2.0, r * 0.08), true)
		elif blinking:
			ci.draw_line(eye - Vector2(r * 0.15, 0), eye + Vector2(r * 0.15, 0), C.INK, maxf(2.0, r * 0.08), true)
		else:
			ci.draw_circle(eye, r * 0.21, Color.WHITE, true, -1.0, true)
			var pupil := eye + look * r * 0.07
			ci.draw_circle(pupil, r * 0.12, C.INK, true, -1.0, true)
			ci.draw_circle(pupil + Vector2(-r, -r) * 0.045, r * 0.045, Color.WHITE, true, -1.0, true)

	var mouth := pos + Vector2(0, r * 0.26) + shift
	if squash > 0.0:
		ci.draw_circle(mouth + Vector2(0, r * 0.08), r * 0.11, C.INK, true, -1.0, true)
	elif scared:
		# No moons left: worried frown and a sweat drop.
		ci.draw_arc(mouth + Vector2(0, r * 0.24), r * 0.18, PI * 1.15, PI * 1.85, 12, C.INK, maxf(2.0, r * 0.075), true)
		ci.draw_circle(pos + Vector2(r * 0.74, -r * 0.42), r * 0.11, Color("8fdcff"), true, -1.0, true)
	else:
		ci.draw_arc(mouth, r * 0.2, PI * 0.12, PI * 0.88, 12, C.INK, maxf(2.0, r * 0.075), true)


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
	ci.draw_circle(pos, r + 2.5, Color(col.darkened(0.5), alpha), true, -1.0, true)
	ci.draw_circle(pos, r, Color(body.darkened(0.15), alpha), true, -1.0, true)
	ci.draw_circle(pos + Vector2(-r, -r) * 0.1, r * 0.85, Color(body, alpha), true, -1.0, true)
	ci.draw_circle(pos + Vector2(-r, -r) * 0.35, r * 0.22, Color(1, 1, 1, 0.7 * alpha), true, -1.0, true)


static func sparkle(ci: CanvasItem, pos: Vector2, r: float, col: Color, rot: float) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(pos + Vector2.from_angle(rot + k * PI / 4.0) * rr)
	ci.draw_circle(pos, r * 1.6, Color(col, 0.16))
	ci.draw_colored_polygon(pts, col)
	ci.draw_circle(pos, r * 0.28, Color(1, 1, 1, 0.9))


static func shield(ci: CanvasItem, pos: Vector2, r: float, time: float) -> void:
	var pulse := 0.5 + 0.5 * sin(time * 9.0)
	ci.draw_circle(pos, r, Color(0.7, 0.95, 1.0, 0.10 + 0.06 * pulse), true, -1.0, true)
	ci.draw_arc(pos, r, 0.0, TAU, 40, Color(0.8, 0.97, 1.0, 0.5 + 0.3 * pulse), 3.0, true)


static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, col: Color, outline := 6) -> void:
	var w := 400.0
	var at := pos - Vector2(w * 0.5, 0)
	ci.draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, outline, Color(C.INK, col.a))
	ci.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)
