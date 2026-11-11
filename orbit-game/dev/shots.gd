extends Node
## Developer tool, not part of the game. Plays a short demo by itself and
## saves screenshots:   godot --path . -- --shots [output_folder]

var main
var _t := 0.0
var _step := 0
var _dir := "user://shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shots")
	if i + 1 < args.size():
		_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_dir)


func _process(delta: float) -> void:
	_t += delta
	match _step:
		0:
			if _t > 1.5:
				_snap("1_menu")
				main.world.autopilot = true
				main._start_game()
				_next()
		1:
			if _t > 6.0:
				_snap("2_play_early")
				_next()
		2:
			if _t > 25.0 or main.state == main.State.GAME_OVER:
				_snap("3_play_late")
				_next()
		3:
			if main.state == main.State.PLAYING and main.world.player.shield <= 0.0:
				while main.world.player.moons > 0:
					main.world.player.remove_moon(0)
				for p in main.world.planets:
					if p != main.world.player and p.alive:
						main.world._bump(main.world.player, p, main.world.player.pos)
						break
			if main.state == main.State.GAME_OVER and _t > 1.8:
				_snap("4_game_over")
				get_tree().quit()


func _next() -> void:
	_step += 1
	_t = 0.0


func _snap(label: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_dir, label])
	print("[shots] saved ", label)
