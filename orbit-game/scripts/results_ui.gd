extends Control
## The sheet shown when a round ends: the podium, your place and the coins
## you earned, with the option to double them by watching an ad.

signal next_pressed
signal menu_pressed

const C = preload("res://scripts/config.gd")
const W = preload("res://scripts/widgets.gd")
const Art = preload("res://scripts/art.gd")

var font: Font
var _title: Label
var _sub: Label
var _podium: Control
var _lines: VBoxContainer
var _total: Label
var _double: Button
var _next_map: Label
var _data := {}
var _time := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func setup(game_font: Font) -> void:
	font = game_font
	add_child(W.backdrop(Color(0.08, 0.05, 0.2, 0.82)))
	var col := W.vbox(10)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(col)

	_title = W.label("", 80, C.GOLD, 18)
	col.add_child(_title)
	_sub = W.label("", 28, Color.WHITE, 6)
	col.add_child(_sub)
	_podium = Control.new()
	_podium.custom_minimum_size = Vector2(0, 370)
	_podium.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_podium.draw.connect(_draw_podium)
	col.add_child(_podium)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", W.card(26))
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size = Vector2(520, 0)
	col.add_child(card)
	var sheet := W.vbox(4)
	card.add_child(sheet)
	_lines = W.vbox(0)
	sheet.add_child(_lines)
	_total = W.label("+0", 58, Color("e8780c"))
	sheet.add_child(W.coin_amount(_total, 52.0))

	_double = W.button("Double it!  (ad)", W.ORANGE, 34)
	_double.pressed.connect(func() -> void: Ads.show_rewarded(_doubled))
	col.add_child(_double)
	var next := W.button("Next round", W.GREEN, 52)
	next.custom_minimum_size = Vector2(420, 0)
	next.pressed.connect(func() -> void: next_pressed.emit())
	col.add_child(next)
	_next_map = W.label("", 26, Color(1, 1, 1, 0.9), 6)
	col.add_child(_next_map)
	var menu := W.button("Menu", W.PURPLE, 28)
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	col.add_child(menu)


## data: standings (planets, best first), place, score, new_best, map_name,
## next_map, rewards ([[text, coins], ...]) and total (coins).
func open(data: Dictionary) -> void:
	_data = data
	var place: int = data.place
	_title.text = "You won!" if place == 1 else "%s place" % W.ordinal(place)
	_sub.text = "%s  -  %d points%s" % [data.map_name, data.score, "  -  new best!" if data.new_best else ""]
	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	for reward: Array in data.rewards:
		var row := HBoxContainer.new()
		var what := W.label(reward[0], 26, Color(C.INK, 0.75))
		what.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(what)
		row.add_child(W.label("+%d" % reward[1], 26, C.INK))
		_lines.add_child(row)
	_total.text = "+%d" % data.total
	_double.visible = data.total > 0
	_next_map.text = "Next map: %s" % data.next_map
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if visible:
		_time += delta
		_podium.queue_redraw()


func _doubled(granted: bool) -> void:
	if not granted or not visible:
		return
	var total: int = _data.total
	Profile.add_coins(total)
	_total.text = "+%d" % (total * 2)
	_double.visible = false
	Sfx.play("coin")


func _draw_podium() -> void:
	if not _data.has("standings"):
		return
	var standings: Array = _data.standings
	var floor_y := _podium.size.y - 6.0
	# Which finisher stands where: [place index, x offset, step height, colour].
	var steps := [[1, -186.0, 100.0, Color("cfd6ea")], [0, 0.0, 140.0, C.GOLD], [2, 186.0, 70.0, Color("e8a26b")]]
	for step: Array in steps:
		var idx: int = step[0]
		if idx >= standings.size():
			continue
		var p = standings[idx]
		var x: float = _podium.size.x * 0.5 + step[1]
		var h: float = step[2]
		var col: Color = step[3]
		Art.box(_podium, Rect2(x - 88.0, floor_y - h, 176.0, h), col.darkened(0.25))
		Art.box(_podium, Rect2(x - 88.0, floor_y - h, 176.0, h - 10.0), col)
		Art.text(_podium, font, Vector2(x, floor_y - h + 32.0), W.ordinal(idx + 1), 28, C.INK, 0)
		Art.text(_podium, font, Vector2(x, floor_y - h + 58.0), str(p.score), 22, Color(C.INK, 0.75), 0)

		var r := 44.0
		var centre := Vector2(x, floor_y - h - r - 4.0 + sin(_time * 2.0 + idx) * 3.0)
		Art.planet(_podium, centre, r, p.color, Vector2(0, 0.3), fmod(_time + idx, 3.5) < 0.12, 0.0, false, p.style, p.hat)
		var name_y: float = centre.y - r * (1.0 + Art.hat_height(p.hat)) - 12.0
		if idx == 0:
			Art.crown(_podium, Vector2(x, name_y - 28.0), 14.0)
		Art.text(_podium, font, Vector2(x, name_y), p.pname, 26, C.GOLD if p.is_player else Color.WHITE)
