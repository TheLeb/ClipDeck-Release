extends RefCounted
## The arenas. Each one has its own colours and one special rule.
##   radius  size of the arena            dust   how much stardust floats around
##   rocks   number of asteroids          hole   true = black hole in the middle
##   grip    how quickly planets change direction (7 = normal, 2 = slippery ice)

const MAPS: Array[Dictionary] = [
	{
		"id": "starfield", "name": "Starfield", "blurb": "The classic arena",
		"radius": 1900.0, "dust": 320, "rocks": 0, "hole": false, "grip": 7.0,
		"sky_top": Color("1c1a52"), "sky_bottom": Color("5a2a8a"), "wall": Color("ffd93d"),
	},
	{
		"id": "asteroids", "name": "Asteroid Belt", "blurb": "Rocks block the way",
		"radius": 1850.0, "dust": 300, "rocks": 16, "hole": false, "grip": 7.0,
		"sky_top": Color("0d2444"), "sky_bottom": Color("1d6a75"), "wall": Color("7ff0e0"),
	},
	{
		"id": "blackhole", "name": "Black Hole", "blurb": "The middle pulls you in",
		"radius": 1800.0, "dust": 300, "rocks": 0, "hole": true, "grip": 7.0,
		"sky_top": Color("1b0c30"), "sky_bottom": Color("7a2b55"), "wall": Color("ff9a5c"),
	},
	{
		"id": "ice", "name": "Ice Ring", "blurb": "Small and slippery",
		"radius": 1450.0, "dust": 220, "rocks": 0, "hole": false, "grip": 2.0,
		"sky_top": Color("10305c"), "sky_bottom": Color("3f84c8"), "wall": Color("d6f4ff"),
	},
]


static func by_id(id: String) -> Dictionary:
	for m in MAPS:
		if m.id == id:
			return m
	return MAPS[0]
