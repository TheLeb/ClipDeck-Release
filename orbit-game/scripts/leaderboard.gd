extends RefCounted
## Where rankings come from. There is no online server yet, so the only real
## data is the player's own rounds saved on this device. When a server exists,
## change these three functions and the Ranks screen keeps working:
##   is_online()  -> true
##   submit()     -> also send the entry (name, country, score) to the server
##   top()        -> fetch the best entries for "country" or "global"


static func is_online() -> bool:
	return false


## Called after every round with {score, place, map}.
static func submit(_entry: Dictionary) -> void:
	pass   # Profile.finish_round() already stored it on the device.


## Best entries for a scope ("country" or "global"); offline: the player's own.
static func top(_scope: String) -> Array:
	return Profile.records
