extends RefCounted
## The numbers and colours you are most likely to tweak live in this file.
## Change a value, press Play (F5) in Godot, and see what happens.
## Maps are in maps.gd; skins, hats, prices and coin packs are in catalog.gd.

# ---- Rounds ----
const ROUND_TIME := 120.0         # seconds per round
const PLAYER_RESPAWN_TIME := 3.0  # seconds you sit out after being popped
const BOT_COUNT := 11

# ---- Planets ----
const START_MOONS := 2
const MAX_MOONS := 8
const DUST_PER_MOON := 4          # stardust needed to grow one new moon
const PLANET_BASE_RADIUS := 28.0
const PLANET_RADIUS_PER_MOON := 2.0
const SPEED_SMALL := 285.0        # speed with no moons
const SPEED_BIG := 235.0          # speed with MAX_MOONS moons

# ---- Moons ----
const MOON_RADIUS := 11.0
const RING_BASE_GAP := 40.0       # distance from planet edge to the moon ring
const RING_GAP_PER_MOON := 9.0    # the ring gets wider with every moon
const MOON_LINEAR_SPEED := 230.0  # how fast moons travel around the ring

# ---- Dash ----
const DASH_SPEED := 760.0
const DASH_TIME := 0.28           # seconds of zooming; nothing can hit you meanwhile
const DASH_COOLDOWN := 2.5        # seconds before you can dash again

# ---- Fighting ----
const HIT_LOSS := 0.5             # share of its moons a planet loses per hit (at least 1)
const HIT_KNOCKBACK := 200.0      # how hard a hit pushes the planet away
const HIT_SHIELD_TIME := 0.45     # safe time after being bumped
const HIT_DIZZY_TIME := 1.0       # after a hit the planet is slow for this long...
const HIT_DIZZY_SPEED := 0.45     # ...moving at this share of its speed (dash still works)
const SPAWN_SHIELD_TIME := 3.0    # safe time after (re)spawning
const BOT_RESPAWN_TIME := 2.5
const BOT_BRAVERY := 0.9          # 0 = bots never hunt, 1 = bots hunt a lot

# ---- Score ----
const SCORE_DUST := 1
const SCORE_LOOSE_MOON := 5
const SCORE_HIT := 3
const SCORE_POP := 25

# ---- Coins ----
const START_COINS := 100                                  # welcome gift for a new player
const PLACE_COINS: Array[int] = [60, 40, 30, 20, 20, 20]  # 1st place, 2nd place, ...
const OTHER_PLACE_COINS := 10                             # everyone below that list
const SCORE_PER_COIN := 20                                # 1 coin for every 20 points
const COINS_PER_POP := 3
const DAILY_COINS: Array[int] = [25, 40, 60, 80, 100, 130, 250]   # day 1 ... day 7 of a streak
const AD_COINS := 30                                      # "free coins" ad reward
const AD_COINS_PER_DAY := 3

# ---- Camera ----
const ZOOM_SMALL := 1.0
const ZOOM_BIG := 0.72

# ---- Colours ----
const DUST_COLORS: Array[Color] = [
	Color("fff3a3"), Color("ffc2e2"), Color("b5f5ff"), Color("c9ffb8"), Color("ffd6a5"),
]
const INK := Color("2a1b4d")       # dark outline / text colour
const CREAM := Color("fff8ee")
const GOLD := Color("ffd93d")

# ---- Bot names (all kid friendly) ----
const NAMES: Array[String] = [
	"Luna", "Cosmo", "Pixel", "Nova", "Ziggy", "Bubbles", "Comet", "Mango",
	"Pip", "Rocket", "Jelly", "Noodle", "Waffle", "Sprout", "Zippy", "Momo",
	"Bean", "Twinkle", "Pebble", "Sunny", "Biscuit", "Coco", "Doodle", "Fizz",
	"Gizmo", "Honey", "Jazzy", "Kiwi", "Lemon", "Muffin", "Nugget", "Olive",
	"Peanut", "Quack", "Skye", "Taco", "Widget", "Yoyo", "Astro", "Blip",
]
