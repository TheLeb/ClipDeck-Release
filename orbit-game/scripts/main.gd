extends Node
## Glue: creates the world and the UI, reads the touch joystick, and moves
## between the three states of the game (menu -> playing -> game over).

const C = preload("res://scripts/config.gd")
const World = preload("res://scripts/world.gd")
const UI = preload("res://scripts/ui.gd")
const Background = preload("res://scripts/background.gd")

const SAVE_PATH := "user://orbit_save.cfg"
const JOY_RADIUS := 90.0

enum State { MENU, PLAYING, GAME_OVER }

var state := State.MENU
var world: World
var ui: UI
var background: Background

var player_name := "Luna"
var skin := 0
var best := 0
var sound_on := true
var revive_used := false

var _touch_id := -1
var _joy_origin := Vector2.ZERO
var _joy_dir := Vector2.ZERO
var _hud_timer := 0.0


func _ready() -> void:
	randomize()
	_load()
	var font := _make_font()

	var back_layer := CanvasLayer.new()
	back_layer.layer = -10
	add_child(back_layer)
	background = Background.new()
	back_layer.add_child(background)

	world = World.new()
	world.font = font
	add_child(world)
	world.player_popped.connect(_on_player_popped)

	ui = UI.new()
	add_child(ui)
	ui.setup(font)
	ui.play_pressed.connect(_start_game)
	ui.again_pressed.connect(_start_game)
	ui.revive_pressed.connect(_on_revive)
	ui.menu_pressed.connect(_to_menu)
	ui.new_name_pressed.connect(_on_new_name)
	ui.skin_picked.connect(_on_skin_picked)
	ui.sound_toggled.connect(_on_sound_toggled)
	_refresh_profile()

	if "--shots" in OS.get_cmdline_user_args():
		var shots: Node = load("res://dev/shots.gd").new()
		shots.main = self
		add_child(shots)


func _process(delta: float) -> void:
	background.cam_pos = world.cam.position
	if state != State.PLAYING:
		return
	var keys := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	world.move_input = keys if keys != Vector2.ZERO else _joy_dir
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.15
		ui.update_hud(world.player, world.leaderboard())


## Floating joystick: touch anywhere, drag to steer.
func _input(event: InputEvent) -> void:
	if state != State.PLAYING:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1:
			_touch_id = event.index
			_joy_origin = event.position
			_joy_dir = Vector2.ZERO
			ui.set_joystick(true, _joy_origin, _joy_origin)
		elif not event.pressed and event.index == _touch_id:
			_release_joystick()
	elif event is InputEventScreenDrag and event.index == _touch_id:
		var offset: Vector2 = event.position - _joy_origin
		if offset.length() > JOY_RADIUS:
			# Drag the base along so turning never needs a big swipe back.
			_joy_origin = event.position - offset.normalized() * JOY_RADIUS
			offset = event.position - _joy_origin
		_joy_dir = offset / JOY_RADIUS
		ui.set_joystick(true, _joy_origin, event.position)


func _release_joystick() -> void:
	_touch_id = -1
	_joy_dir = Vector2.ZERO
	ui.set_joystick(false, Vector2.ZERO, Vector2.ZERO)


# -------------------------------------------------------------- game states --

func _start_game() -> void:
	revive_used = false
	world.spawn_player(player_name, C.SKINS[skin])
	state = State.PLAYING
	_hud_timer = 0.0
	ui.show_hud()
	Sfx.play("start")


func _to_menu() -> void:
	world.remove_player()
	state = State.MENU
	_refresh_profile()
	ui.show_menu()


func _on_player_popped(by_name: String) -> void:
	state = State.GAME_OVER
	_release_joystick()
	world.move_input = Vector2.ZERO
	var score := world.player.score
	var new_best := score > best
	if new_best:
		best = score
		_save()
	ui.update_hud(world.player, world.leaderboard())
	await get_tree().create_timer(0.9).timeout
	if state != State.GAME_OVER:
		return
	Sfx.play("over")
	Ads.game_over()
	ui.show_over(score, best, new_best, by_name, not revive_used)


func _on_revive() -> void:
	Ads.show_rewarded(func(granted: bool) -> void:
		if not granted or state != State.GAME_OVER:
			return
		revive_used = true
		world.revive_player()
		state = State.PLAYING
		ui.show_hud()
		Sfx.play("start"))


# ------------------------------------------------------------------ profile --

func _on_new_name() -> void:
	var pick := player_name
	while pick == player_name:
		pick = C.NAMES[randi() % C.NAMES.size()]
	player_name = pick
	_save()
	_refresh_profile()


func _on_skin_picked(index: int) -> void:
	skin = index
	_save()
	_refresh_profile()


func _on_sound_toggled() -> void:
	sound_on = not sound_on
	_save()
	_refresh_profile()


func _refresh_profile() -> void:
	Sfx.muted = not sound_on
	ui.set_profile(player_name, skin, best, sound_on)


func _load() -> void:
	player_name = C.NAMES[randi() % C.NAMES.size()]
	skin = randi() % C.SKINS.size()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	player_name = str(cfg.get_value("player", "name", player_name))
	skin = clampi(int(cfg.get_value("player", "skin", skin)), 0, C.SKINS.size() - 1)
	best = int(cfg.get_value("player", "best", 0))
	sound_on = bool(cfg.get_value("player", "sound", true))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "skin", skin)
	cfg.set_value("player", "best", best)
	cfg.set_value("player", "sound", sound_on)
	cfg.save(SAVE_PATH)


## Fredoka is a variable font; pick its SemiBold weight for a chunky look.
func _make_font() -> Font:
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Fredoka.ttf")
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): 600}
	return fv
