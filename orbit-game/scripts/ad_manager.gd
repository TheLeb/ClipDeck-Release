extends Node
## Placeholder for ads. The game only ever talks to these two functions, so
## when you add a real ad plugin (e.g. AdMob) you only have to change this file.
## See README.md -> "Adding real ads".

var interstitial_every := 3   # show a full-screen ad every N game overs
var _game_overs := 0


## Rewarded ad ("watch to keep going"). Calls on_done.call(true) if the
## player earned the reward, on_done.call(false) if they skipped / no ad.
func show_rewarded(on_done: Callable) -> void:
	print("[Ads] rewarded ad would play here")
	on_done.call(true)


## Call once per game over; shows a full-screen ad every few rounds.
func game_over() -> void:
	_game_overs += 1
	if _game_overs % interstitial_every == 0:
		print("[Ads] interstitial ad would show here")
