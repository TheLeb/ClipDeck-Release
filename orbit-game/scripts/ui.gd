extends CanvasLayer
## The main menu and the in-game display (HUD). It also owns the other
## screens, each in its own file: shop, round results, ranks and pop-ups.
## Everything is built in code, so there are no scene files to keep in sync.

signal play_pressed
signal next_round_pressed
signal quit_round_pressed    # "Menu" on the results sheet
signal pause_pressed

const C = preload("res://scripts/config.gd")
const Art = preload("res://scripts/art.gd")
const W = preload("res://scripts/widgets.gd")
const Maps = preload("res://scripts/maps.gd")
const NameFilter = preload("res://scripts/name_filter.gd")
const Popups = preload("res://scripts/popups.gd")
const ShopUI = preload("res://scripts/shop_ui.gd")
const ResultsUI = preload("res://scripts/results_ui.gd")
const RanksUI = preload("res://scripts/ranks_ui.gd")

var font: Font
var popups: Popups
var shop: ShopUI
var results: ResultsUI
var ranks: RanksUI

var _root: Control
var _menu: Control
var _hud: Control
var _joy: Control

var _preview: Control
var _name_label: Label
var _coins: Label
var _gift_btn: Button
var _map_btn: Button
var _best_label: Label
var _sound_btn: Button

var _score_label: Label
var _moon_label: Label
var _moon_bar: ProgressBar
var _board_rows: Array[Label] = []
var _timer: Label
var _pause_btn: Button
var _hint: Label
var _center: Label
var _dash: Control
var _dash_ready := 1.0

var _joy_on := false
var _joy_knob := Vector2.ZERO
var _time := 0.0
var _name_callback: JavaScriptObject   # kept so the browser can call us back


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

	# Later children are drawn on top of earlier ones.
	results = ResultsUI.new()
	shop = ShopUI.new()
	ranks = RanksUI.new()
	popups = Popups.new()
	for screen: Control in [results, shop, ranks, popups]:
		_root.add_child(screen)
	popups.setup()
	results.setup(font)
	shop.setup(popups)
	ranks.setup(popups)
	results.next_pressed.connect(func() -> void: next_round_pressed.emit())
	results.menu_pressed.connect(func() -> void: quit_round_pressed.emit())
	Profile.changed.connect(_refresh_menu)
	show_menu()


func _process(delta: float) -> void:
	_time += delta
	if _menu.visible:
		_preview.queue_redraw()


# ------------------------------------------------------------------ screens --

func show_menu() -> void:
	_menu.visible = true
	_hud.visible = false
	results.close()
	set_joystick(false, Vector2.ZERO)
	_refresh_menu()


func show_hud() -> void:
	_menu.visible = false
	_hud.visible = true
	results.close()
	set_center("")
	set_hint("")
	set_joystick(true, Vector2.ZERO)


func show_results(data: Dictionary) -> void:
	set_joystick(false, Vector2.ZERO)
	results.open(data)


# ---------------------------------------------------------------------- HUD --

func update_hud(me, board: Array) -> void:
	_score_label.text = str(me.score)
	_moon_label.text = "Moons %d/%d" % [me.moons, me.max_moons] if me.moons > 0 else "No moons - careful!"
	_moon_label.add_theme_color_override("font_color", Color.WHITE if me.moons > 0 else Color("ff9ec4"))
	_moon_bar.max_value = me.dust_per_moon
	_moon_bar.value = me.dust_per_moon if me.moons >= me.max_moons else me.dust_progress
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


## Time left in the round; turns pink for the last ten seconds.
func set_timer(seconds: float) -> void:
	var whole := maxi(0, ceili(seconds))
	_timer.text = "%d:%02d" % [whole / 60, whole % 60]
	_timer.add_theme_color_override("font_color", Color("ff9ec4") if whole <= 10 else Color.WHITE)


## Short tip shown near the top while playing ("" hides it).
func set_hint(text: String) -> void:
	_hint.text = text


## Big message in the middle of the screen ("" hides it).
func set_center(text: String) -> void:
	_center.text = text


## ready: 0 = just used, 1 = can dash again.
func set_dash(ready: float) -> void:
	if not is_equal_approx(ready, _dash_ready):
		_dash_ready = ready
		_dash.queue_redraw()


func dash_center() -> Vector2:
	return _hud.size - Vector2(120, 190)


## True if a touch at this position is on the DASH button.
func dash_hit(at: Vector2) -> bool:
	return at.distance_to(dash_center()) < 100.0


## True if a touch at this position is on the pause button.
func pause_hit(at: Vector2) -> bool:
	return _pause_btn.get_global_rect().grow(10.0).has_point(at)


## The steering stick sits in a fixed spot, bottom left.
func joy_center() -> Vector2:
	return Vector2(150, _hud.size.y - 190)


## on: show the stick. knob: how far the thumb pad is pushed from the centre.
func set_joystick(on: bool, knob: Vector2) -> void:
	_joy_on = on
	_joy_knob = knob
	_joy.queue_redraw()


# --------------------------------------------------------------------- menu --

func _refresh_menu() -> void:
	_coins.text = str(Profile.coins)
	_name_label.text = Profile.player_name
	_sound_btn.text = "Sound: On" if Profile.sound_on else "Sound: Off"
	var gift := Profile.daily_ready()
	W.paint(_gift_btn, "Gift!" if gift else "Gift", W.PINK if gift else W.GREY, 34)
	var choice := Profile.map_choice
	var map_name: String = "Random" if choice == "random" else Maps.by_id(choice).name
	_map_btn.text = "Map: %s" % map_name
	if Profile.rounds > 0:
		_best_label.text = "Best %d      Wins %d" % [Profile.best, Profile.wins]
	else:
		_best_label.text = "Collect stardust. Grow moons. Bump!"


## The map button steps through: Random, then each map.
func _next_map_choice() -> void:
	var choices: Array[String] = ["random"]
	for m in Maps.MAPS:
		choices.append(m.id)
	Profile.set_map_choice(choices[(choices.find(Profile.map_choice) + 1) % choices.size()])


func _on_edit_name() -> void:
	# The browser test page brings its own text box (see dev/test_page.html);
	# everywhere else the game's own name editor is used.
	if OS.has_feature("web") and JavaScriptBridge.eval("typeof window.orbitEditName === 'function'", true):
		_name_callback = JavaScriptBridge.create_callback(_on_web_name)
		JavaScriptBridge.get_interface("window").orbitEditName(Profile.player_name, NameFilter.MAX_LENGTH, _name_callback)
	else:
		popups.edit_name()


func _on_web_name(args: Array) -> void:
	if args.size() > 0 and args[0] != null:
		popups.apply_name(str(args[0]))


func _draw_preview() -> void:
	var c := _preview.size * 0.5 + Vector2(0, 22.0 + sin(_time * 2.0) * 5.0)
	Art.avatar(_preview, c, 78.0, Profile.look(), _time, 5, 142.0)


# ----------------------------------------------------------------- building --

func _build_joystick() -> void:
	_joy = Control.new()
	_joy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_joy)
	_joy.draw.connect(func() -> void:
		if not _joy_on:
			return
		var c := joy_center()
		Art.disc(_joy, c, 90.0, Color(1, 1, 1, 0.10))
		_joy.draw_arc(c, 90.0, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 4.0, true)
		Art.disc(_joy, c + _joy_knob, 38.0, Color(1, 1, 1, 0.55)))


func _build_hud() -> void:
	_hud = W.full_rect()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)
	var top := 24.0 + W.safe_top(get_viewport())

	var left := PanelContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_stylebox_override("panel", W.pill())
	left.position = Vector2(20, top)
	_hud.add_child(left)
	var lbox := W.vbox(2)
	left.add_child(lbox)
	_score_label = W.label("0", 56, C.GOLD, 8)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbox.add_child(_score_label)
	_moon_label = W.label("", 24, Color.WHITE, 4)
	_moon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbox.add_child(_moon_label)
	_moon_bar = ProgressBar.new()
	_moon_bar.max_value = C.DUST_PER_MOON
	_moon_bar.show_percentage = false
	_moon_bar.custom_minimum_size = Vector2(170, 14)
	_moon_bar.add_theme_stylebox_override("background", W.flat(Color(1, 1, 1, 0.2), 7))
	_moon_bar.add_theme_stylebox_override("fill", W.flat(C.GOLD, 7))
	lbox.add_child(_moon_bar)

	_timer = W.label("", 50, Color.WHITE, 10)
	_timer.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_timer.position = Vector2(0, top)
	_hud.add_child(_timer)

	_pause_btn = W.button("II", Color("6c5fb0"), 22)
	_pause_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_pause_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pause_btn.position = Vector2(0, top + 72.0)
	_pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	_hud.add_child(_pause_btn)

	_hint = W.label("", 34, Color.WHITE, 10)
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.position = Vector2(0, top + 230.0)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_child(_hint)

	_center = W.label("", 58, C.GOLD, 14)
	_center.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	_center.offset_top = -340.0
	_center.offset_bottom = -170.0
	_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_child(_center)

	_dash = W.full_rect()
	_dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_dash)
	_dash.draw.connect(func() -> void:
		var c := dash_center()
		var ready := _dash_ready >= 1.0
		Art.disc(_dash, c, 80.0, Color(1, 1, 1, 0.18 if ready else 0.07))
		_dash.draw_arc(c, 80.0, -PI * 0.5, -PI * 0.5 + TAU * _dash_ready, 48, C.GOLD if ready else Color(1, 1, 1, 0.5), 8.0, true)
		Art.text(_dash, font, c + Vector2(0, 11), "DASH", 30, Color(1, 1, 1, 1.0 if ready else 0.45)))

	var right := PanelContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_stylebox_override("panel", W.pill())
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.position = Vector2(-20, top)
	_hud.add_child(right)
	var rbox := W.vbox(0)
	right.add_child(rbox)
	for i in 6:
		var row := W.label("", 24, Color.WHITE, 4)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(210, 0)
		rbox.add_child(row)
		_board_rows.append(row)


func _build_menu() -> void:
	_menu = W.full_rect()
	_root.add_child(_menu)
	_menu.add_child(W.backdrop(Color(0.1, 0.07, 0.3, 0.72)))   # fades the live game behind
	var top := 24.0 + W.safe_top(get_viewport())

	var box := W.vbox(16)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(box)

	var title := W.label("ORBIT", 150, C.GOLD, 26)
	title.add_theme_color_override("font_shadow_color", Color(0.1, 0.05, 0.25, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 12)
	box.add_child(title)

	_preview = Control.new()
	_preview.custom_minimum_size = Vector2(0, 340)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.draw.connect(_draw_preview)
	box.add_child(_preview)

	var name_row := W.hbox(14)
	_name_label = W.label("", 50, Color.WHITE, 10)
	name_row.add_child(_name_label)
	var edit := W.button("Edit", W.PURPLE, 24)
	edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	edit.pressed.connect(_on_edit_name)
	name_row.add_child(edit)
	box.add_child(name_row)

	var row := W.hbox(14)
	var shop_btn := W.button("Shop", W.ORANGE, 34)
	shop_btn.pressed.connect(func() -> void: shop.open("skin"))
	row.add_child(shop_btn)
	var ranks_btn := W.button("Ranks", W.BLUE, 34)
	ranks_btn.pressed.connect(func() -> void: ranks.open())
	row.add_child(ranks_btn)
	_gift_btn = W.button("Gift", W.PINK, 34)
	_gift_btn.pressed.connect(func() -> void: popups.daily_gift())
	row.add_child(_gift_btn)
	box.add_child(row)

	_map_btn = W.button("Map: Random", W.PURPLE, 26)
	_map_btn.pressed.connect(_next_map_choice)
	box.add_child(_map_btn)

	var play := W.button("PLAY", W.GREEN, 76)
	play.custom_minimum_size = Vector2(400, 0)
	play.pressed.connect(func() -> void: play_pressed.emit())
	box.add_child(play)

	_best_label = W.label("", 28, Color(1, 1, 1, 0.9), 6)
	box.add_child(_best_label)

	# Top corners: sound switch and the coin counter (tap it for the coin shop).
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 20.0
	bar.offset_right = -20.0
	bar.offset_top = top
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(bar)
	_sound_btn = W.button("Sound: On", W.BLUE, 22)
	_sound_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sound_btn.pressed.connect(func() -> void: Profile.toggle_sound())
	bar.add_child(_sound_btn)
	var gap := W.spacer(0)
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	_coins = W.label("0", 36, C.GOLD, 6)
	var pill := W.coin_pill(_coins)
	pill.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			Sfx.play("click")
			shop.open("pack"))
	bar.add_child(pill)
