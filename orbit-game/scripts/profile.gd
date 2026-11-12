extends Node
## Everything that is remembered about the player between sessions: name,
## coins, what they own and wear, records. Use it from anywhere as `Profile`.
## It is saved on the device only; nothing is sent anywhere.

signal changed

const C = preload("res://scripts/config.gd")
const Catalog = preload("res://scripts/catalog.gd")
const SAVE_PATH := "user://orbit_save.cfg"
const MAX_RECORDS := 20

var player_name := ""
var country := ""            # two-letter code, "" = not chosen yet
var coins := C.START_COINS
var owned: Array[String] = []
var equipped := {"skin": "skin_pink", "hat": "hat_none", "trail": "trail_none", "moon": "moon_round"}
var best := 0
var rounds := 0
var wins := 0
var sound_on := true
var no_ads := false
var map_choice := "random"   # "random" or a map id
var daily_step := 0          # which daily gift comes next (0 = day 1)
var daily_last_day := -1     # day number of the last claimed gift
var ad_day := -1
var ad_used := 0
var records: Array = []      # best rounds: {score, place, map, day}


func _ready() -> void:
	_load()
	Sfx.muted = not sound_on


# ---------------------------------------------------------------- identity --

func set_player_name(value: String) -> void:
	player_name = value
	_commit()


func set_country(code: String) -> void:
	country = code
	_commit()


func set_map_choice(value: String) -> void:
	map_choice = value
	_commit()


func toggle_sound() -> void:
	sound_on = not sound_on
	Sfx.muted = not sound_on
	_commit()


# ------------------------------------------------------------ shop / items --

func owns(id: String) -> bool:
	var price = Catalog.item(id).get("price", 0)
	return (price is int and price == 0) or id in owned


func is_equipped(id: String) -> bool:
	return equipped.get(Catalog.kind_of(id), "") == id


func equip(id: String) -> void:
	if owns(id):
		equipped[Catalog.kind_of(id)] = id
		_commit()


## Pays for an item with coins. False if it is already owned or too expensive.
func buy(id: String) -> bool:
	var price: int = Catalog.item(id).price
	if owns(id) or coins < price:
		return false
	coins -= price
	owned.append(id)
	_commit()
	return true


func add_coins(amount: int) -> void:
	coins += amount
	_commit()


func set_no_ads() -> void:
	no_ads = true
	_commit()


## What the player's planet looks like and which skin stats it has.
func look() -> Dictionary:
	return {
		"skin": Catalog.item(equipped.skin), "hat": equipped.hat,
		"trail": equipped.trail, "moon": equipped.moon,
	}


# ----------------------------------------------------------------- rewards --

## Days since 1970 in the player's own time zone.
func today() -> int:
	var bias: int = Time.get_time_zone_from_system().bias
	return int((Time.get_unix_time_from_system() + bias * 60.0) / 86400.0)


func daily_ready() -> bool:
	return daily_last_day != today()


## Which of the 7 gifts is next. A missed day starts the streak again.
func daily_next_step() -> int:
	var day := today()
	return daily_step if daily_last_day == day or daily_last_day == day - 1 else 0


## Hands out today's gift. Returns the coins given (0 if already claimed).
func claim_daily() -> int:
	if not daily_ready():
		return 0
	var step := daily_next_step()
	var amount := C.DAILY_COINS[step]
	daily_step = (step + 1) % C.DAILY_COINS.size()
	daily_last_day = today()
	coins += amount
	_commit()
	return amount


func ad_coins_left() -> int:
	return C.AD_COINS_PER_DAY - (ad_used if ad_day == today() else 0)


func use_ad_coins() -> void:
	if ad_day != today():
		ad_day = today()
		ad_used = 0
	ad_used += 1
	coins += C.AD_COINS
	_commit()


## Books a finished round: coins, statistics and the personal record list.
func finish_round(score: int, place: int, map_name: String, coins_won: int) -> void:
	rounds += 1
	if place == 1:
		wins += 1
	best = maxi(best, score)
	coins += coins_won
	records.append({"score": score, "place": place, "map": map_name, "day": today()})
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	if records.size() > MAX_RECORDS:
		records.resize(MAX_RECORDS)
	_commit()


# ------------------------------------------------------------------ saving --

func _commit() -> void:
	save()
	changed.emit()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "country", country)
	cfg.set_value("player", "coins", coins)
	cfg.set_value("player", "owned", owned)
	cfg.set_value("player", "equipped", equipped)
	cfg.set_value("player", "best", best)
	cfg.set_value("player", "rounds", rounds)
	cfg.set_value("player", "wins", wins)
	cfg.set_value("player", "sound", sound_on)
	cfg.set_value("player", "no_ads", no_ads)
	cfg.set_value("player", "map", map_choice)
	cfg.set_value("daily", "step", daily_step)
	cfg.set_value("daily", "last_day", daily_last_day)
	cfg.set_value("daily", "ad_day", ad_day)
	cfg.set_value("daily", "ad_used", ad_used)
	cfg.set_value("records", "list", records)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var free_skins := 8
	player_name = C.NAMES[randi() % C.NAMES.size()]
	equipped.skin = Catalog.SKINS[randi() % free_skins].id
	var locale := OS.get_locale().get_slice("_", 1).to_upper()
	if locale.length() == 2 and Catalog.country_name(locale) != "":
		country = locale

	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	player_name = str(cfg.get_value("player", "name", player_name))
	country = str(cfg.get_value("player", "country", country))
	coins = int(cfg.get_value("player", "coins", coins))
	best = int(cfg.get_value("player", "best", 0))
	rounds = int(cfg.get_value("player", "rounds", 0))
	wins = int(cfg.get_value("player", "wins", 0))
	sound_on = bool(cfg.get_value("player", "sound", true))
	no_ads = bool(cfg.get_value("player", "no_ads", false))
	map_choice = str(cfg.get_value("player", "map", "random"))
	daily_step = int(cfg.get_value("daily", "step", 0))
	daily_last_day = int(cfg.get_value("daily", "last_day", -1))
	ad_day = int(cfg.get_value("daily", "ad_day", -1))
	ad_used = int(cfg.get_value("daily", "ad_used", 0))
	for id in cfg.get_value("player", "owned", []):
		if Catalog.exists(str(id)):
			owned.append(str(id))
	var worn = cfg.get_value("player", "equipped", {})
	if worn is Dictionary:
		for kind: String in equipped:
			var id := str(worn.get(kind, ""))
			if Catalog.exists(id) and owns(id):
				equipped[kind] = id
	if cfg.has_section_key("player", "skin"):   # saves from the first version
		var old_skin = cfg.get_value("player", "skin")
		if old_skin is int:
			equipped.skin = Catalog.SKINS[clampi(old_skin, 0, free_skins - 1)].id
	var list = cfg.get_value("records", "list", [])
	if list is Array:
		for entry in list:
			if entry is Dictionary and entry.has("score"):
				records.append(entry)
