extends Control
## The Ranks screen, with Country and Global tabs. There is no online server
## yet (see leaderboard.gd), so for now both tabs show the player's own best
## rounds saved on this device, and say so.

const C = preload("res://scripts/config.gd")
const W = preload("res://scripts/widgets.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Board = preload("res://scripts/leaderboard.gd")
const Popups = preload("res://scripts/popups.gd")

var popups: Popups
var _scope := "country"
var _tab_buttons := {}
var _country_row: Control
var _country_label: Label
var _notice: Label
var _list: VBoxContainer
var _stats: Label
var _refresh_queued := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func setup(popups_node: Popups) -> void:
	popups = popups_node
	add_child(W.backdrop(W.SCREEN))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 24 + int(W.safe_top(get_viewport())))
	add_child(margin)
	var col := W.vbox(16)
	margin.add_child(col)
	col.add_child(W.header("Ranks", null, close))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	for tab: Array in [["country", "Country"], ["global", "Global"]]:
		var b := W.button(tab[1], W.PURPLE, 30)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select.bind(tab[0]))
		tabs.add_child(b)
		_tab_buttons[tab[0]] = b
	col.add_child(tabs)

	var notice_box := PanelContainer.new()
	notice_box.add_theme_stylebox_override("panel", W.tile())
	_notice = W.label("", 24, Color(1, 1, 1, 0.85))
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_box.add_child(_notice)
	col.add_child(notice_box)

	var country := HBoxContainer.new()
	country.add_theme_constant_override("separation", 12)
	_country_label = W.label("", 30, Color.WHITE, 6)
	_country_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_country_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	country.add_child(_country_label)
	var change := W.button("Change", W.BLUE, 26)
	change.pressed.connect(func() -> void: popups.pick_country())
	country.add_child(change)
	_country_row = country
	col.add_child(country)

	var heading := W.label("Your best rounds", 36, C.GOLD, 8)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = W.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_stats = W.label("", 26, Color(1, 1, 1, 0.9), 6)
	col.add_child(_stats)
	Profile.changed.connect(_refresh_soon)


func open() -> void:
	visible = true
	_refresh()


func close() -> void:
	visible = false


func _select(scope: String) -> void:
	_scope = scope
	_refresh()


## Rebuilds the list a moment later. Needed because a change is often caused
## by a button in this very list, which must not be removed while it is
## still handling its own press.
func _refresh_soon() -> void:
	if visible and not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not visible:
		return
	for key: String in _tab_buttons:
		var b: Button = _tab_buttons[key]
		W.paint(b, b.text, W.ORANGE if key == _scope else W.PURPLE, 30)
	var country_name := Catalog.country_name(Profile.country)
	_country_row.visible = _scope == "country"
	_country_label.text = "Country: %s" % (country_name if country_name != "" else "not chosen yet")
	var board := "%s ranking" % (country_name if _scope == "country" and country_name != "" else ("Country" if _scope == "country" else "Global"))
	if Board.is_online():
		_notice.get_parent().visible = false
	else:
		_notice.text = "%s is not online yet. It switches on when Orbit launches on Google Play. Until then this list shows your own rounds, saved on this device." % board

	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var entries := Board.top(_scope)
	if entries.is_empty():
		_list.add_child(W.label("Play a round to set your first record!", 28, Color(1, 1, 1, 0.75)))
	for i in mini(entries.size(), 10):
		var entry: Dictionary = entries[i]
		var place: int = entry.get("place", 0)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", W.tile(i == 0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		panel.add_child(row)
		var rank := W.label("%d." % (i + 1), 32, C.GOLD, 6)
		rank.custom_minimum_size = Vector2(56, 0)
		row.add_child(rank)
		var score := W.label(str(entry.get("score", 0)), 38, Color.WHITE, 6)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		score.custom_minimum_size = Vector2(130, 0)
		row.add_child(score)
		var detail := W.label("%s place  -  %s" % [W.ordinal(place), entry.get("map", "")], 24, Color(1, 1, 1, 0.75))
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(detail)
		_list.add_child(panel)
	_stats.text = "Rounds %d      Wins %d      Best %d" % [Profile.rounds, Profile.wins, Profile.best]
