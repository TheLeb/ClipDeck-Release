extends CanvasLayer
## All menus and on-screen displays, built in code so there are no scene
## files to keep in sync. Three screens: menu, HUD (while playing), game over.

signal play_pressed
signal revive_pressed
signal again_pressed
signal menu_pressed
signal new_name_pressed
signal skin_picked(index: int)
signal sound_toggled

const C = preload("res://scripts/config.gd")
const Art = preload("res://scripts/art.gd")

var font: Font

var _root: Control
var _menu: Control
var _hud: Control
var _over: Control
var _joy: Control

var _preview: Control
var _name_label: Label
var _best_label: Label
var _sound_btn: Button
var _swatches: Array[Button] = []
var _skin_color := Color.WHITE

var _score_label: Label
var _moon_label: Label
var _moon_bar: ProgressBar
var _board_rows: Array[Label] = []

var _over_card: Control
var _over_by: Label
var _over_score: Label
var _over_best: Label
var _revive_btn: Button

var _joy_on := false
var _joy_origin := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _time := 0.0


func setup(game_font: Font) -> void:
	font = game_font
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 32
	_root = Control.new()
	_root.theme = theme
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_build_joystick()
	_build_hud()
	_build_menu()
	_build_over()
	show_menu()


func _process(delta: float) -> void:
	_time += delta
	if _menu.visible:
		_preview.queue_redraw()


# ------------------------------------------------------------------ screens --

func show_menu() -> void:
	_menu.visible = true
	_hud.visible = false
	_over.visible = false
	set_joystick(false, Vector2.ZERO, Vector2.ZERO)


func show_hud() -> void:
	_menu.visible = false
	_hud.visible = true
	_over.visible = false


func show_over(score: int, best: int, new_best: bool, by_name: String, can_revive: bool) -> void:
	set_joystick(false, Vector2.ZERO, Vector2.ZERO)
	_over.visible = true
	_over_by.text = "%s bumped you!" % by_name
	_over_score.text = str(score)
	_over_best.text = "New best score!" if new_best else "Best: %d" % best
	_over_best.add_theme_color_override("font_color", Color("ff5a8a") if new_best else Color(C.INK, 0.6))
	_revive_btn.visible = can_revive
	_over_card.scale = Vector2(0.7, 0.7)
	_over_card.modulate.a = 0.0
	await get_tree().process_frame
	_over_card.pivot_offset = _over_card.size * 0.5
	var tw := create_tween().set_parallel()
	tw.tween_property(_over_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_over_card, "modulate:a", 1.0, 0.2)


func set_profile(pname: String, skin: int, best: int, sound_on: bool) -> void:
	_name_label.text = pname
	_skin_color = C.SKINS[skin]
	_best_label.text = "Best score: %d" % best if best > 0 else "Collect stardust. Grow moons. Bump!"
	_sound_btn.text = "Sound: On" if sound_on else "Sound: Off"
	for i in _swatches.size():
		_swatches[i].add_theme_stylebox_override("normal", _swatch_style(C.SKINS[i], i == skin))
		_swatches[i].add_theme_stylebox_override("hover", _swatch_style(C.SKINS[i], i == skin))
		_swatches[i].add_theme_stylebox_override("pressed", _swatch_style(C.SKINS[i], true))


func update_hud(me, board: Array) -> void:
	_score_label.text = str(me.score)
	_moon_label.text = "Moons %d/%d" % [me.moons, C.MAX_MOONS]
	_moon_bar.value = C.DUST_PER_MOON if me.moons >= C.MAX_MOONS else me.dust_progress
	var my_rank := board.find(me)
	for i in _board_rows.size():
		var row := _board_rows[i]
		var idx := i
		if i == _board_rows.size() - 1 and my_rank > i:
			idx = my_rank   # last row always shows the player
		if idx < 0 or idx >= board.size():
			row.text = ""
			continue
		var p = board[idx]
		row.text = "%d. %s  %d" % [idx + 1, p.pname, p.score]
		row.add_theme_color_override("font_color", C.GOLD if p == me else Color.WHITE)


func set_joystick(on: bool, origin: Vector2, knob: Vector2) -> void:
	_joy_on = on
	_joy_origin = origin
	_joy_knob = knob
	_joy.queue_redraw()


# ----------------------------------------------------------------- building --

func _build_joystick() -> void:
	_joy = Control.new()
	_joy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_joy)
	_joy.draw.connect(func() -> void:
		if not _joy_on:
			return
		_joy.draw_circle(_joy_origin, 90.0, Color(1, 1, 1, 0.10), true, -1.0, true)
		_joy.draw_arc(_joy_origin, 90.0, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 4.0, true)
		_joy.draw_circle(_joy_knob, 38.0, Color(1, 1, 1, 0.55), true, -1.0, true))


func _build_hud() -> void:
	_hud = _full_rect()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)
	var top := 24.0 + _safe_top()

	var left := PanelContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_stylebox_override("panel", _pill_style())
	left.position = Vector2(20, top)
	_hud.add_child(left)
	var lbox := VBoxContainer.new()
	lbox.add_theme_constant_override("separation", 2)
	left.add_child(lbox)
	_score_label = _label("0", 56, C.GOLD, 8)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbox.add_child(_score_label)
	_moon_label = _label("Moons 2/14", 24, Color.WHITE, 4)
	_moon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbox.add_child(_moon_label)
	_moon_bar = ProgressBar.new()
	_moon_bar.max_value = C.DUST_PER_MOON
	_moon_bar.show_percentage = false
	_moon_bar.custom_minimum_size = Vector2(170, 14)
	_moon_bar.add_theme_stylebox_override("background", _flat(Color(1, 1, 1, 0.2), 7))
	_moon_bar.add_theme_stylebox_override("fill", _flat(C.GOLD, 7))
	lbox.add_child(_moon_bar)

	var right := PanelContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_stylebox_override("panel", _pill_style())
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.position = Vector2(-20, top)
	_hud.add_child(right)
	var rbox := VBoxContainer.new()
	rbox.add_theme_constant_override("separation", 0)
	right.add_child(rbox)
	for i in 6:
		var row := _label("", 24, Color.WHITE, 4)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(210, 0)
		rbox.add_child(row)
		_board_rows.append(row)


func _build_menu() -> void:
	_menu = _full_rect()
	_root.add_child(_menu)
	var dim := ColorRect.new()   # fades the live game that plays behind the menu
	dim.color = Color(0.1, 0.07, 0.3, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(dim)
	var box := _center_column(_menu, 18)

	var title := _label("ORBIT", 170, C.GOLD, 28)
	title.add_theme_color_override("font_shadow_color", Color(0.1, 0.05, 0.25, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 12)
	box.add_child(title)

	_preview = Control.new()
	_preview.custom_minimum_size = Vector2(0, 360)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.draw.connect(_draw_preview)
	box.add_child(_preview)

	_name_label = _label("Luna", 54, Color.WHITE, 10)
	box.add_child(_name_label)
	var name_btn := _button("New name", Color("a98bff"), 28)
	name_btn.pressed.connect(func() -> void: new_name_pressed.emit())
	box.add_child(name_btn)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for i in C.SKINS.size():
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(64, 64)
		sw.focus_mode = Control.FOCUS_NONE
		sw.pressed.connect(func() -> void:
			Sfx.play("click", 1.3)
			skin_picked.emit(i))
		row.add_child(sw)
		_swatches.append(sw)

	box.add_child(_spacer(10))
	var play := _button("PLAY", Color("3ecf6e"), 76)
	play.custom_minimum_size = Vector2(400, 0)
	play.pressed.connect(func() -> void: play_pressed.emit())
	box.add_child(play)

	_best_label = _label("", 30, Color(1, 1, 1, 0.9), 6)
	box.add_child(_best_label)

	_sound_btn = _button("Sound: On", Color("5cb8ff"), 24)
	_sound_btn.pressed.connect(func() -> void: sound_toggled.emit())
	box.add_child(_sound_btn)


func _build_over() -> void:
	_over = _full_rect()
	_root.add_child(_over)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.05, 0.2, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.add_child(center)
	var card := PanelContainer.new()
	var style := _flat(C.CREAM, 48)
	style.set_content_margin_all(44)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 24
	style.shadow_offset = Vector2(0, 12)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(540, 0)
	center.add_child(card)
	_over_card = card

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	box.add_child(_label("POP!", 110, Color("ff5a8a"), 0))
	_over_by = _label("", 32, Color(C.INK, 0.75), 0)
	box.add_child(_over_by)
	box.add_child(_label("Score", 30, Color(C.INK, 0.6), 0))
	_over_score = _label("0", 120, C.INK, 0)
	box.add_child(_over_score)
	_over_best = _label("", 32, Color(C.INK, 0.6), 0)
	box.add_child(_over_best)
	box.add_child(_spacer(12))

	_revive_btn = _button("Keep going!  (ad)", Color("ffa552"), 40)
	_revive_btn.pressed.connect(func() -> void: revive_pressed.emit())
	box.add_child(_revive_btn)
	var again := _button("Play again", Color("3ecf6e"), 48)
	again.pressed.connect(func() -> void: again_pressed.emit())
	box.add_child(again)
	var home := _button("Menu", Color("a98bff"), 30)
	home.pressed.connect(func() -> void: menu_pressed.emit())
	box.add_child(home)
	for b: Button in [_revive_btn, again, home]:
		b.size_flags_horizontal = Control.SIZE_FILL


func _draw_preview() -> void:
	var c := _preview.size * 0.5
	var ring := 150.0
	var look := Vector2.from_angle(_time * 0.7) * 0.8
	_preview.draw_arc(c, ring, 0.0, TAU, 64, Color(_skin_color, 0.25), 3.0, true)
	for k in 5:
		Art.moon(_preview, c + Vector2.from_angle(_time * 1.3 + TAU * k / 5.0) * ring, 20.0, _skin_color)
	Art.planet(_preview, c + Vector2(0, sin(_time * 2.0) * 6.0), 84.0, _skin_color, look, fmod(_time, 3.5) < 0.12, 0.0)


# ------------------------------------------------------------------ helpers --

func _full_rect() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


func _center_column(parent: Control, separation: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box


func _spacer(height: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s


func _label(text: String, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", C.INK)
	return l


func _button(text: String, color: Color, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", _button_style(color, false, size))
	b.add_theme_stylebox_override("hover", _button_style(color.lightened(0.08), false, size))
	b.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.08), true, size))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, Color.WHITE)
	b.add_theme_color_override("font_outline_color", color.darkened(0.5))
	b.add_theme_constant_override("outline_size", maxi(4, size / 7))
	b.pressed.connect(func() -> void: Sfx.play("click"))
	return b


## Chunky "candy" button: rounded, with a darker lip along the bottom.
func _button_style(color: Color, pressed: bool, size: int) -> StyleBoxFlat:
	var lip := maxi(6, size / 6)
	var s := _flat(color, mini(44, size))
	s.border_color = color.darkened(0.3)
	s.border_width_bottom = lip / 3 if pressed else lip
	s.content_margin_left = size * 0.9
	s.content_margin_right = size * 0.9
	s.content_margin_top = size * 0.3 + (lip * 0.6 if pressed else 0.0)
	s.content_margin_bottom = size * 0.3 + lip - (lip * 0.6 if pressed else 0.0)
	return s


func _swatch_style(color: Color, selected: bool) -> StyleBoxFlat:
	var s := _flat(color, 32)
	s.set_border_width_all(6 if selected else 3)
	s.border_color = Color.WHITE if selected else color.darkened(0.45)
	return s


func _pill_style() -> StyleBoxFlat:
	var s := _flat(Color(0.08, 0.05, 0.22, 0.45), 26)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 14
	return s


func _flat(color: Color, corner: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(corner)
	s.anti_aliasing = true
	return s


## Extra space at the top on phones with a notch / camera cut-out.
func _safe_top() -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var window_h := float(DisplayServer.window_get_size().y)
	if window_h <= 0.0:
		return 0.0
	return DisplayServer.get_display_safe_area().position.y * get_viewport().get_visible_rect().size.y / window_h
