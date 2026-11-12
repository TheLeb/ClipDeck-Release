extends RefCounted
## Small building blocks shared by all screens (labels, candy buttons, cards),
## so every screen looks the same and the screen files stay short.

const C = preload("res://scripts/config.gd")
const Art = preload("res://scripts/art.gd")

const PINK := Color("ff5a8a")
const GREEN := Color("3ecf6e")
const ORANGE := Color("ffa552")
const BLUE := Color("5cb8ff")
const PURPLE := Color("a98bff")
const GREY := Color("8e93b0")
const GOOD := Color("9dffb5")    # text colour for an advantage
const BAD := Color("ffa3c6")     # text colour for a drawback
const SCREEN := Color(0.10, 0.07, 0.28)   # backdrop of full screens


static func full_rect() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


static func backdrop(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	return r


static func spacer(height: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


static func vbox(separation: int) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


static func hbox(separation: int) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_theme_constant_override("separation", separation)
	return b


static func label(text: String, size: int, color: Color, outline := 0) -> Label:
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


## Chunky "candy" button with a click sound.
static func button(text: String, color: Color, size: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	paint(b, text, color, size)
	b.pressed.connect(func() -> void: Sfx.play("click"))
	return b


## (Re)colours a button; used when a button changes meaning, e.g. Buy -> Use.
static func paint(b: Button, text: String, color: Color, size: int) -> void:
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", _button_style(color, false, size))
	b.add_theme_stylebox_override("hover", _button_style(color.lightened(0.08), false, size))
	b.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.08), true, size))
	b.add_theme_stylebox_override("disabled", _button_style(color, false, size))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(key, Color.WHITE)
	b.add_theme_color_override("font_outline_color", color.darkened(0.5))
	b.add_theme_constant_override("outline_size", maxi(4, size / 7))


## A button showing a coin and a price.
static func price_button(price: int, color: Color, size: int) -> Button:
	var b := button(" ", color, size)
	var amount := label(str(price), size, Color.WHITE, maxi(4, size / 7))
	amount.add_theme_color_override("font_outline_color", color.darkened(0.5))
	var middle := CenterContainer.new()
	middle.set_anchors_preset(Control.PRESET_FULL_RECT)
	middle.offset_bottom = -maxi(6, size / 6)   # sit on the button's face, above its lip
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(coin_amount(amount, size * 1.1))
	b.add_child(middle)
	return b


static func _button_style(color: Color, pressed: bool, size: int) -> StyleBoxFlat:
	var lip := maxi(6, size / 6)
	var s := flat(color, mini(44, size))
	s.border_color = color.darkened(0.3)
	s.border_width_bottom = lip / 3 if pressed else lip
	s.content_margin_left = size * 0.9
	s.content_margin_right = size * 0.9
	s.content_margin_top = size * 0.3 + (lip * 0.6 if pressed else 0.0)
	s.content_margin_bottom = size * 0.3 + lip - (lip * 0.6 if pressed else 0.0)
	return s


static func flat(color: Color, corner: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(corner)
	s.anti_aliasing = true
	return s


## Dark see-through pill used for small info boxes over the game.
static func pill() -> StyleBoxFlat:
	var s := flat(Color(0.08, 0.05, 0.22, 0.45), 26)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 14
	return s


## Cream card with a soft shadow (pop-ups, result sheet).
static func card(margin := 40) -> StyleBoxFlat:
	var s := flat(C.CREAM, 44)
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 24
	s.shadow_offset = Vector2(0, 12)
	return s


## See-through tile for list entries; `selected` adds a gold frame.
static func tile(selected := false) -> StyleBoxFlat:
	var s := flat(Color(1, 1, 1, 0.16 if selected else 0.09), 28)
	s.set_content_margin_all(14)
	s.set_border_width_all(4)
	s.border_color = C.GOLD if selected else Color(1, 1, 1, 0.0)
	return s


## Small drawn coin.
static func coin_icon(size: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: Art.coin(c, c.size * 0.5, size * 0.48))
	return c


## A coin followed by an amount; pass in the label so you can update it later.
static func coin_amount(amount: Label, icon_size: float) -> HBoxContainer:
	var row := hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(coin_icon(icon_size))
	row.add_child(amount)
	return row


## The player's coins in a dark pill (top corner of menus).
static func coin_pill(amount: Label) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", pill())
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(coin_amount(amount, 36.0))
	return p


## Title row of a full screen: big title, optional coin pill, close button.
static func header(title: String, coins: Label, on_close: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var t := label(title, 64, C.GOLD, 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	if coins != null:
		row.add_child(coin_pill(coins))
	var close := button("Back", PINK, 30)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(on_close)
	row.add_child(close)
	return row


## Extra space at the top on phones with a notch / camera cut-out.
static func safe_top(viewport: Viewport) -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var window_h := float(DisplayServer.window_get_size().y)
	if window_h <= 0.0:
		return 0.0
	return DisplayServer.get_display_safe_area().position.y * viewport.get_visible_rect().size.y / window_h


static func ordinal(n: int) -> String:
	if n % 100 >= 11 and n % 100 <= 13:
		return "%dth" % n
	match n % 10:
		1:
			return "%dst" % n
		2:
			return "%dnd" % n
		3:
			return "%drd" % n
	return "%dth" % n
