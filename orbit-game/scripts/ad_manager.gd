extends Node
## Placeholder for ads. Use it from anywhere as `Ads`. The game only ever
## calls these two functions, so when you add a real ad plugin (e.g. AdMob)
## you only have to change this file. See README.md -> "Adding real ads".

var interstitial_every := 3   # show a full-screen ad every N finished rounds
var _rounds := 0


## Rewarded ad ("watch to double your coins"). Calls on_done.call(true) if
## the player earned the reward, on_done.call(false) if they skipped / no ad.
func show_rewarded(on_done: Callable) -> void:
	print("[Ads] rewarded ad would play here")
	on_done.call(true)


## Call once per finished round; shows a full-screen ad every few rounds,
## unless the player bought "No Ads".
func round_finished() -> void:
	_rounds += 1
	if _rounds % interstitial_every == 0 and not Profile.no_ads:
		print("[Ads] interstitial ad would show here")
