extends Node
## Real-money purchases (coin packs, No Ads). Use it from anywhere as `Store`.
##
## THIS VERSION ONLY SIMULATES PURCHASES: no payment happens and the pack is
## handed out for free. Before release, connect Google Play Billing here and
## call _grant() only after the store has confirmed the payment.
## See README.md -> "Real purchases".

const Catalog = preload("res://scripts/catalog.gd")

## True while purchases are simulated. The shop shows a notice when it is.
var test_mode := true


## Starts a purchase. Calls on_done.call(true) once the pack was handed out.
func buy(pack_id: String, on_done: Callable) -> void:
	print("[Store] simulated purchase: ", pack_id)
	_grant(pack_id)
	on_done.call(true)


func _grant(pack_id: String) -> void:
	var pack := Catalog.item(pack_id)
	if pack.has("coins"):
		Profile.add_coins(pack.coins)
	if pack.get("no_ads", false):
		Profile.set_no_ads()
