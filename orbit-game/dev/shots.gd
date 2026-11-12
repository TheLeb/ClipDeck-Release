extends Node
## Developer tool, not part of the game. Clicks through the screens, plays a
## short round by itself and saves screenshots:
##   godot --path . -- --shots [output_folder] [map_id]
## It dresses the player up and hands out coins for the pictures, without
## saving any of that.

var main
var _t := 0.0
var _step := 0
var _dir := "user://shots"
var _map := "random"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shots")
	if i + 1 < args.size():
		_dir = args[i + 1]
	if i + 2 < args.size():
		_map = args[i + 2]
	DirAccess.make_dir_recursive_absolute(_dir)
	Profile.map_choice = _map
	Profile.coins = 780
	Profile.equipped.skin = "skin_comet"
	Profile.equipped.hat = "hat_party"
	Profile.equipped.trail = "trail_rainbow"
	Profile.equipped.moon = "moon_gem"
	Profile.changed.emit()


func _process(delta: float) -> void:
	_t += delta
	var ui = main.ui
	match _step:
		0:
			if _t > 1.5:
				_snap("1_menu")
				ui.shop.open("skin")
				_next()
		1:
			if _t > 0.6:
				_snap("2_shop_skins")
				ui.shop.open("hat")
				_next()
		2:
			if _t > 0.6:
				_snap("3_shop_hats")
				ui.shop.open("pack")
				_next()
		3:
			if _t > 0.6:
				_snap("4_shop_coins")
				ui.shop.open("trail")
				_next()
		4:
			if _t > 0.6:
				_snap("4b_shop_trails")
				ui.shop.open("moon")
				_next()
		5:
			if _t > 0.6:
				_snap("4c_shop_moons")
				ui.shop.close()
				ui.ranks.open()
				_next()
		6:
			if _t > 0.6:
				_snap("5_ranks")
				ui.popups.pick_country()
				_next()
		7:
			if _t > 0.8:
				_snap("5b_country")
				ui.popups.close()
				ui.ranks.close()
				ui.popups.edit_name()
				_next()
		8:
			if _t > 0.8:
				_snap("5c_name")
				ui.popups.daily_gift()
				_next()
		9:
			if _t > 0.8:
				_snap("6_gift")
				ui.popups.close()
				main.world.autopilot = true
				main._start_round()
				_next()
		10:
			if _t > 1.2:
				_snap("7_round_start")
				_next()
		11:
			if _t > 9.0:
				var me = main.world.player
				while me.moons > 0:
					me.remove_moon(0)
				_next()
		12:
			if _t > 0.15:
				_snap("8_playing")
				main._on_pause()
				_next()
		13:
			if _t > 0.8:
				_snap("8b_pause")
				ui.popups.close()
				main._resume()
				main.round_left = 0.4
				_next()
		14:
			if ui.results.visible and _t > 3.0:
				_snap("9_results")
				get_tree().quit()


func _next() -> void:
	_step += 1
	_t = 0.0


func _snap(label: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_dir, label])
	print("[shots] saved ", label, "  draw calls: ",
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
