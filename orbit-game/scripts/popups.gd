extends Control
## Small pop-up cards shown on top of everything: questions, the daily gift,
## the name editor, the country list, and short "toast" messages.

const C = preload("res://scripts/config.gd")
const W = preload("res://scripts/widgets.gd")
const Catalog = preload("res://scripts/catalog.gd")
const NameFilter = preload("res://scripts/name_filter.gd")

var _dim: ColorRect
var _center: CenterContainer
var _card: PanelContainer
var _box: VBoxContainer
var _toast: Label
var _toast_tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup() -> void:
	_dim = W.backdrop(Color(0.06, 0.04, 0.18, 0.72))
	_dim.visible = false
	add_child(_dim)
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.visible = false
	add_child(_center)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", W.card())
	_card.custom_minimum_size = Vector2(560, 0)
	_center.add_child(_card)
	_box = W.vbox(16)
	_card.add_child(_box)

	_toast = W.label("", 36, Color.WHITE, 12)
	_toast.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toast.offset_top = -330.0
	_toast.offset_bottom = -270.0
	_toast.modulate.a = 0.0
	add_child(_toast)


func is_open() -> bool:
	return _center.visible


func close() -> void:
	_dim.visible = false
	_center.visible = false


## Short message near the bottom that fades away by itself.
func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


## A question with two buttons. on_ok runs for the big button, on_cancel
## (optional) for the small one.
func confirm(title: String, text: String, ok_text: String, on_ok: Callable,
		on_cancel := Callable(), cancel_text := "Cancel") -> void:
	_start()
	_box.add_child(W.label(title, 48, C.INK))
	_box.add_child(_body(text))
	_box.add_child(W.spacer(4))
	var ok := _wide(W.button(ok_text, W.GREEN, 40))
	ok.pressed.connect(func() -> void:
		close()
		on_ok.call())
	var no := _wide(W.button(cancel_text, W.GREY, 30))
	no.pressed.connect(func() -> void:
		close()
		if on_cancel.is_valid():
			on_cancel.call())
	_show()


## The 7-day gift calendar.
func daily_gift() -> void:
	_start()
	_box.add_child(W.label("Daily gift", 56, W.PINK))
	_box.add_child(_body("Come back every day. The gifts get bigger!"))
	var is_ready := Profile.daily_ready()
	var step := Profile.daily_next_step()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for i in C.DAILY_COINS.size():
		var claimed := i < step
		var today := i == step and is_ready
		var style := W.flat(Color("ffe98a") if today else (Color("ddd5c6") if claimed else Color("f3e8d5")), 18)
		style.set_content_margin_all(8)
		style.set_border_width_all(4)
		style.border_color = W.ORANGE if today else Color(0, 0, 0, 0)
		var day := PanelContainer.new()
		day.add_theme_stylebox_override("panel", style)
		day.custom_minimum_size = Vector2(110, 96)
		var col := W.vbox(2)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		day.add_child(col)
		col.add_child(W.label("Day %d" % (i + 1), 22, Color(C.INK, 0.65)))
		col.add_child(W.coin_amount(W.label("Got it" if claimed else str(C.DAILY_COINS[i]), 26, Color(C.INK, 0.5 if claimed else 1.0)), 26.0))
		grid.add_child(day)
	_box.add_child(grid)
	_box.add_child(W.spacer(4))
	if is_ready:
		var claim := _wide(W.button("Claim +%d" % C.DAILY_COINS[step], W.GREEN, 40))
		claim.pressed.connect(func() -> void:
			var got := Profile.claim_daily()
			close()
			if got > 0:
				Sfx.play("coin")
				toast("+%d coins" % got))
	else:
		_box.add_child(W.label("Your next gift is ready tomorrow", 28, C.INK))
	var later := _wide(W.button("Close", W.GREY, 30))
	later.pressed.connect(close)
	_show()


## Name editor for phones and computers. (The browser test page uses its own
## text box instead, because typing into a game canvas is unreliable there.)
func edit_name() -> void:
	_start()
	_box.add_child(W.label("Your name", 52, C.INK))
	var input := LineEdit.new()
	input.text = Profile.player_name
	input.max_length = NameFilter.MAX_LENGTH
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.custom_minimum_size = Vector2(440, 88)
	input.add_theme_font_size_override("font_size", 44)
	input.add_theme_color_override("font_color", C.INK)
	input.add_theme_color_override("caret_color", C.INK)
	var style := W.flat(Color.WHITE, 22)
	style.set_border_width_all(4)
	style.border_color = W.PURPLE
	style.set_content_margin_all(14)
	input.add_theme_stylebox_override("normal", style)
	input.add_theme_stylebox_override("focus", style)
	_box.add_child(input)
	_box.add_child(_body("%d to %d letters or numbers" % [NameFilter.MIN_LENGTH, NameFilter.MAX_LENGTH]))
	var save := _wide(W.button("Save", W.GREEN, 40))
	save.pressed.connect(func() -> void:
		if apply_name(input.text):
			close())
	input.text_submitted.connect(func(typed: String) -> void:
		if apply_name(typed):
			close())
	var random := _wide(W.button("Surprise me", W.PURPLE, 30))
	random.pressed.connect(func() -> void:
		input.text = C.NAMES[randi() % C.NAMES.size()])
	var cancel := _wide(W.button("Cancel", W.GREY, 30))
	cancel.pressed.connect(close)
	_show()
	input.grab_focus.call_deferred()


## Checks a typed name and stores it. False (with a message) if it is not allowed.
func apply_name(raw: String) -> bool:
	var cleaned := NameFilter.clean(raw)
	if not NameFilter.is_ok(cleaned):
		toast("Please pick a different name")
		return false
	Profile.set_player_name(cleaned)
	toast("Hello, %s!" % cleaned)
	return true


func pick_country() -> void:
	_start()
	_box.add_child(W.label("Your country", 48, C.INK))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 700)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := W.vbox(4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var plain := _row_style(Color(0, 0, 0, 0.05))
	var active := _row_style(Color(W.PURPLE, 0.35))
	var chosen := _row_style(Color(C.GOLD, 0.7))
	for pair: Array in Catalog.countries():
		var code: String = pair[0]
		var b := Button.new()
		b.text = pair[1]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 30)
		for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(key, C.INK)
		b.add_theme_stylebox_override("normal", chosen if code == Profile.country else plain)
		b.add_theme_stylebox_override("hover", active)
		b.add_theme_stylebox_override("pressed", active)
		b.pressed.connect(func() -> void:
			Profile.set_country(code)
			close())
		list.add_child(b)
	_box.add_child(scroll)
	var cancel := _wide(W.button("Cancel", W.GREY, 30))
	cancel.pressed.connect(close)
	_show()


# ------------------------------------------------------------------ helpers --

## Empties the card and shows the dimmed background.
func _start() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_dim.visible = true
	_center.visible = true
	_card.modulate.a = 0.0


## Little pop-in animation once the card has its final size.
func _show() -> void:
	await get_tree().process_frame
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.85, 0.85)
	var tw := create_tween().set_parallel()
	tw.tween_property(_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.15)


func _body(text: String) -> Label:
	var l := W.label(text, 28, Color(C.INK, 0.75))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(460, 0)
	return l


## Adds a button to the card, stretched to the card's width.
func _wide(b: Button) -> Button:
	b.size_flags_horizontal = Control.SIZE_FILL
	_box.add_child(b)
	return b


func _row_style(color: Color) -> StyleBoxFlat:
	var s := W.flat(color, 14)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s
