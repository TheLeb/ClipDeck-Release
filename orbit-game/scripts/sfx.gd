extends Node
## Tiny sound player:  Sfx.play("pickup")

const SOUNDS := ["pickup", "moon", "hit", "dash", "pop", "click", "start", "over", "coin", "tick", "win"]

var muted := false
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for s: String in SOUNDS:
		var path := "res://assets/sfx/%s.wav" % s
		if ResourceLoader.exists(path):
			_streams[s] = load(path)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if muted or not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()
