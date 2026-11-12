extends Control
## The shop. Skins, hats, trails and moon styles are paid with coins; the
## Coins tab offers free coins for an ad and the real-money packs.

const C = preload("res://scripts/config.gd")
const W = preload("res://scripts/widgets.gd")
const Art = preload("res://scripts/art.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Popups = preload("res://scripts/popups.gd")

const TABS := [["skin", "Skins"], ["hat", "Hats"], ["trail", "Trails"], ["moon", "Moons"], ["pack", "Coins"]]

var popups: Popups
var _tab := "skin"
var _tab_buttons := {}
var _coins: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _previews: Array[Control] = []
var _time := 0.0
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

	_coins = W.label("0", 36, C.GOLD, 6)
	col.add_child(W.header("Shop", _coins, close))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for tab: Array in TABS:
		var b := W.button(tab[1], W.PURPLE, 24)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select.bind(tab[0]))
		tabs.add_child(b)
		_tab_buttons[tab[0]] = b
	col.add_child(tabs)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	_scroll.add_child(_grid)
	Profile.changed.connect(_refresh_soon)


## tab: "skin", "hat", "trail", "moon" or "pack" (the coins tab).
func open(tab := "skin") -> void:
	visible = true
	_select(tab)


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for preview in _previews:
		preview.queue_redraw()


func _select(tab: String) -> void:
	_tab = tab
	for key: String in _tab_buttons:
		var b: Button = _tab_buttons[key]
		W.paint(b, b.text, W.ORANGE if key == tab else W.PURPLE, 24)
	_scroll.scroll_vertical = 0
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
	_coins.text = str(Profile.coins)
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_previews.clear()
	if _tab == "pack":
		_grid.columns = 1
		_grid.add_child(_free_coins_row())
		for pack in Catalog.PACKS:
			_grid.add_child(_pack_row(pack))
		if Store.test_mode:
			var note := W.label("Test version: real-money buying is switched off, so these packs are handed out for free.", 22, Color(1, 1, 1, 0.7))
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_grid.add_child(note)
	else:
		_grid.columns = 2
		var items := Catalog.list_of(_tab)
		if _tab == "skin":   # the special skins first, the free colours after them
			for item in items:
				if item.has("stats"):
					_grid.add_child(_item_card(item))
		for item in items:
			if not (_tab == "skin" and item.has("stats")):
				_grid.add_child(_item_card(item))


# ------------------------------------------------------------------- items --

func _item_card(item: Dictionary) -> Control:
	var id: String = item.id
	var price: int = item.price
	var using := Profile.is_equipped(id)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", W.tile(using))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := W.vbox(4)
	panel.add_child(box)

	var preview := Control.new()
	preview.custom_minimum_size = Vector2(0, 200)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.draw.connect(_draw_item.bind(preview, item))
	box.add_child(preview)
	_previews.append(preview)

	box.add_child(W.label(item.name, 30, Color.WHITE, 6))
	if item.has("good"):
		box.add_child(W.label(item.good, 21, W.GOOD, 4))
		box.add_child(W.label(item.bad, 21, W.BAD, 4))
	elif _tab == "skin":
		box.add_child(W.label("No bonus", 21, Color(1, 1, 1, 0.55)))
		box.add_child(W.label(" ", 21, Color.WHITE))
	else:
		box.add_child(W.label("Just for looks", 21, Color(1, 1, 1, 0.55)))

	var b: Button
	if using:
		b = W.button("Using", W.GREY, 26)
		b.disabled = true
	elif Profile.owns(id):
		b = W.button("Use", W.BLUE, 26)
		b.pressed.connect(func() -> void: Profile.equip(id))
	else:
		b = W.price_button(price, W.GREEN if Profile.coins >= price else W.GREY, 26)
		b.pressed.connect(_ask_buy.bind(item))
	b.size_flags_horizontal = Control.SIZE_FILL
	box.add_child(b)
	return panel


## Shows the player's own planet wearing the item.
func _draw_item(preview: Control, item: Dictionary) -> void:
	var outfit := Profile.look()
	var id: String = item.id
	var c := preview.size * 0.5
	match _tab:
		"skin":
			outfit.skin = item
			Art.avatar(preview, c + Vector2(0, 16), 46.0, outfit, _time, 3, 80.0)
		"hat":
			outfit.hat = id
			Art.avatar(preview, c + Vector2(0, 36), 54.0, outfit, _time)
		"trail":
			outfit.trail = id
			var at := c + Vector2(50, 14)
			for i in 7:
				var age := fmod(_time * 1.4 + i / 7.0, 1.0)   # 0 = fresh, 1 = faded
				var pos := at + Vector2(-50.0 - age * 110.0, sin(i * 2.4) * 10.0)
				var k := 1.0 - age
				match id:
					"trail_bubbles":
						Art.disc(preview, pos + Vector2(0, -age * 18.0), 9.0 * k, Color(0.78, 0.95, 1.0, 0.85 * k))
					"trail_stars":
						Art.star(preview, pos, 15.0 * k, Color(C.DUST_COLORS[i % C.DUST_COLORS.size()], k))
					"trail_rainbow":
						Art.disc(preview, pos, 11.0 * k, Color(Color.from_hsv(fmod(_time * 0.9 + age * 0.3, 1.0), 0.55, 1.0), k))
			Art.avatar(preview, at, 46.0, outfit, _time)
		"moon":
			outfit.moon = id
			Art.avatar(preview, c + Vector2(0, 10), 34.0, outfit, _time, 4, 70.0, 15.0)


func _ask_buy(item: Dictionary) -> void:
	var price: int = item.price
	var id: String = item.id
	var item_name: String = item.name
	if Profile.coins < price:
		popups.toast("You need %d more coins" % (price - Profile.coins))
		return
	popups.confirm("Buy %s?" % item_name, "It costs %d coins." % price, "Buy", func() -> void:
		if Profile.buy(id):
			Profile.equip(id)
			Sfx.play("coin")
			popups.toast("%s is yours!" % item_name))


# ------------------------------------------------------------- coins tab --

func _row(title: String, blurb: String, icon: Control, action: Button) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", W.tile())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	row.add_child(icon)
	var texts := W.vbox(0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	var title_label := W.label(title, 34, Color.WHITE, 6)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(title_label)
	var blurb_label := W.label(blurb, 22, Color(1, 1, 1, 0.7))
	blurb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(blurb_label)
	row.add_child(texts)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(action)
	return panel


func _free_coins_row() -> Control:
	var left := Profile.ad_coins_left()
	var b := W.button("Watch", W.ORANGE if left > 0 else W.GREY, 30)
	b.disabled = left <= 0
	b.pressed.connect(func() -> void: Ads.show_rewarded(_ad_watched))
	return _row("Free coins", "Watch an ad: +%d coins (%d left today)" % [C.AD_COINS, maxi(left, 0)], W.coin_icon(64.0), b)


func _ad_watched(granted: bool) -> void:
	if granted:
		Profile.use_ad_coins()
		Sfx.play("coin")
		popups.toast("+%d coins" % C.AD_COINS)


func _pack_row(pack: Dictionary) -> Control:
	var is_no_ads: bool = pack.get("no_ads", false)
	var owned := is_no_ads and Profile.no_ads
	var price: String = pack.price
	var b := W.button("Owned" if owned else price, W.GREY if owned else W.GREEN, 30)
	b.disabled = owned
	b.pressed.connect(_ask_pack.bind(pack))
	var icon := W.coin_icon(64.0)
	if is_no_ads:
		icon = Control.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.draw.connect(func() -> void:
			Art.disc(icon, Vector2(32, 32), 30.0, W.PINK)
			Art.star(icon, Vector2(32, 32), 24.0, Color.WHITE))
	return _row(pack.name, pack.blurb, icon, b)


func _ask_pack(pack: Dictionary) -> void:
	var id: String = pack.id
	var pack_name: String = pack.name
	var text := "Price: %s" % pack.price
	if Store.test_mode:
		text = "This is a test version, so it is free here and no money is charged.\n\nNormal price: %s" % pack.price
	popups.confirm(pack_name, text, "Get it", _buy_pack.bind(id))


func _buy_pack(id: String) -> void:
	Store.buy(id, _pack_bought)


func _pack_bought(ok: bool) -> void:
	if ok:
		Sfx.play("coin")
		popups.toast("Thank you!")
