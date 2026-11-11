extends RefCounted
## Every number, colour and name you might want to tweak lives in this file.
## Change a value, press Play (F5) in Godot, and see what happens.

# ---- Arena ----
const ARENA_RADIUS := 1900.0
const BOT_COUNT := 11
const DUST_COUNT := 320

# ---- Planets ----
const START_MOONS := 2
const MAX_MOONS := 14
const DUST_PER_MOON := 4          # stardust needed to grow one new moon
const PLANET_BASE_RADIUS := 28.0
const PLANET_RADIUS_PER_MOON := 2.0
const SPEED_SMALL := 300.0        # speed with no moons
const SPEED_BIG := 200.0          # speed with MAX_MOONS moons

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
const HIT_SHIELD_TIME := 0.7      # safe time after being bumped
const SPAWN_SHIELD_TIME := 3.0    # safe time after (re)spawning
const BOT_RESPAWN_TIME := 2.5
const BOT_BRAVERY := 0.6         # 0 = bots never hunt, 1 = bots hunt a lot

# ---- Score ----
const SCORE_DUST := 1
const SCORE_LOOSE_MOON := 5
const SCORE_HIT := 3
const SCORE_POP := 20

# ---- Camera ----
const ZOOM_SMALL := 1.0
const ZOOM_BIG := 0.72

# ---- Colours ----
const SKINS: Array[Color] = [
	Color("ff7eb6"), # pink
	Color("ffa552"), # orange
	Color("ffd93d"), # yellow
	Color("6be39a"), # green
	Color("4dd9d0"), # teal
	Color("5cb8ff"), # sky blue
	Color("a98bff"), # purple
	Color("ff7b6b"), # coral
]
const DUST_COLORS: Array[Color] = [
	Color("fff3a3"), Color("ffc2e2"), Color("b5f5ff"), Color("c9ffb8"), Color("ffd6a5"),
]
const BG_TOP := Color("1c1a52")
const BG_BOTTOM := Color("5a2a8a")
const INK := Color("2a1b4d")       # dark outline / text colour
const CREAM := Color("fff8ee")
const GOLD := Color("ffd93d")

# ---- Names (all kid friendly) ----
const NAMES: Array[String] = [
	"Luna", "Cosmo", "Pixel", "Nova", "Ziggy", "Bubbles", "Comet", "Mango",
	"Pip", "Rocket", "Jelly", "Noodle", "Waffle", "Sprout", "Zippy", "Momo",
	"Bean", "Twinkle", "Pebble", "Sunny", "Biscuit", "Coco", "Doodle", "Fizz",
	"Gizmo", "Honey", "Jazzy", "Kiwi", "Lemon", "Muffin", "Nugget", "Olive",
	"Peanut", "Quack", "Skye", "Taco", "Widget", "Yoyo", "Astro", "Blip",
]
