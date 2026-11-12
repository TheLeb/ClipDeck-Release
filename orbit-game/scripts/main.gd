extends Node
## Glue: creates the world and the UI, reads the touch controls, and runs the
## rounds (menu -> 2-minute round -> results -> next round ...).

const C = preload("res://scripts/config.gd")
const Maps = preload("res://scripts/maps.gd")
const World = preload("res://scripts/world.gd")
const UI = preload("res://scripts/ui.gd")
const Background = preload("res://scripts/background.gd")
const Art = preload("res://scripts/art.gd")
const W = preload("res://scripts/widgets.gd")
const Board = preload("res://scripts/leaderboard.gd")

const JOY_RADIUS := 90.0
const MAP_BANNER_SECONDS := 2.5
const HINT_SECONDS := 5.0
const HINTS: Array[String] = [
	"Collect stardust to grow moons",
	"Hit other planets with your moons",
	"Every hit knocks off half their moons",
	"No moons left? The next hit pops them!",
	"Tap DASH to zoom past their moons",
	"Highest score when the time is up wins",
]

enum State { MENU, PLAYING, RESULTS }

var state := State.MENU
var world: World
var ui: UI
var background: Background

var current_map: Dictionary = Maps.MAPS[0]
var round_left := 0.0         # seconds until the round ends
var respawn_left := -1.0      # >= 0 while the player waits to come back
var paused := false

var _rotation := -1           # where we are in the map rotation
var _popped_by := ""
var _round_time := 0.0
var _last_tick := 0
var _touch_id := -1            # which finger is on the steering stick
var _fingers := {}            # every finger that is on the screen right now
var _joy_dir := Vector2.ZERO
var _hud_timer := 0.0
var _slow_time := 0.0
var _lite := false


func _ready() -> void:
	randomize()
	Art.setup()
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
	ui.play_pressed.connect(_start_round)
	ui.next_round_pressed.connect(_start_round)
	ui.quit_round_pressed.connect(_to_menu)
	ui.pause_pressed.connect(_on_pause)

	# A brand-new player starts on the classic map; after that the rotation
	# starts somewhere random.
	if Profile.rounds > 0:
		_rotation = randi() % Maps.MAPS.size()

	if "--shots" in OS.get_cmdline_user_args():
		var shots: Node = load("res://dev/shots.gd").new()
		shots.main = self
		add_child(shots)


func _process(delta: float) -> void:
	background.cam_pos = world.cam.position
	if state != State.PLAYING or paused:
		return
	round_left -= delta
	_round_time += delta
	if round_left <= 0.0:
		_end_round()
		return

	var me := world.player
	var keys := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	world.move_input = keys if keys != Vector2.ZERO else _joy_dir
	ui.set_dash(1.0 - me.dash_cd / (C.DASH_COOLDOWN * me.dash_cd_mul))
	ui.set_timer(round_left)
	var whole := ceili(round_left)
	if whole <= 10 and whole != _last_tick:
		_last_tick = whole
		Sfx.play("tick")

	# Big message in the middle: waiting to come back, or the map's name at the start.
	var message := ""
	if respawn_left >= 0.0:
		respawn_left -= delta
		if respawn_left <= 0.0:
			respawn_left = -1.0
			world.respawn_player()
		else:
			message = "%s popped you!\nBack in %d" % [_popped_by, ceili(respawn_left)]
	elif _round_time < MAP_BANNER_SECONDS:
		message = "%s\n%s" % [current_map.name, current_map.blurb]
	ui.set_center(message)

	var tip := int((_round_time - MAP_BANNER_SECONDS) / HINT_SECONDS)
	var show_tip := Profile.rounds < 3 and _round_time > MAP_BANNER_SECONDS and tip < HINTS.size()
	ui.set_hint(HINTS[tip] if show_tip else "")

	_check_speed(delta)
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.15
		ui.update_hud(me, world.standings())


## Steering stick fixed at the bottom left: the planet goes where your thumb
## is relative to the stick's centre. DASH button or Space to dash.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_fingers[event.index] = true
		else:
			_fingers.erase(event.index)
	if state != State.PLAYING or paused:
		return
	if event.is_action_pressed("ui_accept"):
		world.dash_player()
	elif event.is_action_pressed("ui_cancel"):
		_on_pause()
	elif event is InputEventScreenTouch:
		if event.pressed and ui.dash_hit(event.position):
			world.dash_player()
		elif event.pressed and ui.pause_hit(event.position):
			_on_pause()   # handled here so it also works while a thumb is steering
		elif event.pressed and _touch_id == -1:
			_touch_id = event.index
			_steer_to(event.position)
		elif not event.pressed and event.index == _touch_id:
			_release_joystick()
	elif event is InputEventScreenDrag:
		if _touch_id == -1 and event.position.x < ui.joy_center().x + 260.0:
			_touch_id = event.index   # a thumb that stayed on the stick through a pause
		if event.index == _touch_id:
			_steer_to(event.position)


func _steer_to(touch: Vector2) -> void:
	var offset := (touch - ui.joy_center()).limit_length(JOY_RADIUS)
	_joy_dir = offset / JOY_RADIUS if offset.length() > 10.0 else Vector2.ZERO
	ui.set_joystick(true, offset)


func _release_joystick() -> void:
	_touch_id = -1
	_joy_dir = Vector2.ZERO
	ui.set_joystick(state == State.PLAYING, Vector2.ZERO)


## Buttons only listen to the first finger that touched the screen. When a
## screen with buttons opens (pause, results, menu) while a thumb is still
## resting on the stick, tell the engine those fingers have lifted, so a tap
## with any finger works straight away.
func _let_go_of_touches() -> void:
	for index: int in _fingers.keys():
		var lift := InputEventScreenTouch.new()
		lift.index = index
		lift.pressed = false
		Input.parse_input_event(lift)
	_fingers.clear()


## If the game runs slowly for a while, draw at a lower resolution from then
## on. Slightly softer picture, far less work for a weak phone or a browser.
func _check_speed(delta: float) -> void:
	if _lite or _round_time < 3.0:
		return
	_slow_time = _slow_time + delta if Engine.get_frames_per_second() < 45.0 else 0.0
	if _slow_time > 2.5:
		_lite = true
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT


# ------------------------------------------------------------------- rounds --

## The map `steps` rounds from now (0 = the round being started or played).
func _map_in(steps: int) -> Dictionary:
	if Profile.map_choice != "random":
		return Maps.by_id(Profile.map_choice)
	return Maps.MAPS[posmod(_rotation + steps, Maps.MAPS.size())]


func _start_round() -> void:
	_rotation += 1
	current_map = _map_in(0)
	world.start_round(current_map, Profile.player_name, Profile.look())
	background.set_sky(current_map.sky_top, current_map.sky_bottom)
	round_left = C.ROUND_TIME
	respawn_left = -1.0
	paused = false
	_round_time = 0.0
	_last_tick = 0
	_hud_timer = 0.0
	state = State.PLAYING
	ui.show_hud()
	ui.set_timer(round_left)
	Sfx.play("start")


func _on_player_popped(by_name: String) -> void:
	_popped_by = by_name
	respawn_left = C.PLAYER_RESPAWN_TIME


## Time is up: freeze the game, hand out coins, show the results.
func _end_round() -> void:
	state = State.RESULTS
	world.frozen = true
	_release_joystick()
	_let_go_of_touches()
	world.move_input = Vector2.ZERO
	ui.set_timer(0.0)
	ui.set_hint("")
	ui.set_center("Time's up!")

	var me := world.player
	var standings := world.standings()
	var place := standings.find(me) + 1
	var rewards: Array = []
	var place_coins := C.PLACE_COINS[place - 1] if place <= C.PLACE_COINS.size() else C.OTHER_PLACE_COINS
	rewards.append(["%s place" % W.ordinal(place), place_coins])
	rewards.append(["%d points" % me.score, me.score / C.SCORE_PER_COIN])
	if me.pops > 0:
		rewards.append(["%d planets popped" % me.pops, me.pops * C.COINS_PER_POP])
	var total := 0
	for reward: Array in rewards:
		total += int(reward[1])
	if me.coin_mul > 1.0:
		var bonus := roundi(total * (me.coin_mul - 1.0))
		rewards.append(["Skin bonus", bonus])
		total += bonus

	var new_best := me.score > Profile.best
	Profile.finish_round(me.score, place, current_map.name, total)
	Board.submit({"score": me.score, "place": place, "map": current_map.name})
	Ads.round_finished()
	Sfx.play("win" if place <= 3 else "over")

	await get_tree().create_timer(1.5).timeout
	if state != State.RESULTS:
		return
	ui.set_center("")
	ui.show_results({
		"standings": standings, "place": place, "score": me.score, "new_best": new_best,
		"map_name": current_map.name, "next_map": _map_in(1).name,
		"rewards": rewards, "total": total,
	})


func _to_menu() -> void:
	world.remove_player()
	world.frozen = false
	paused = false
	state = State.MENU
	_release_joystick()
	_let_go_of_touches()
	ui.show_menu()


func _on_pause() -> void:
	if state != State.PLAYING or paused:
		return
	paused = true
	world.frozen = true
	_release_joystick()
	_let_go_of_touches()
	ui.popups.confirm("Paused", "If you leave now you get no coins for this round.",
			"Keep playing", _resume, _to_menu, "Leave round")


func _resume() -> void:
	paused = false
	world.frozen = false


## Fredoka is a variable font; pick its SemiBold weight for a chunky look.
func _make_font() -> Font:
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Fredoka.ttf")
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): 600}
	return fv
