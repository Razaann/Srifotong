extends Node
## Global SFX (autoload "Sfx"). Pooled players so hits/attacks can overlap.
## Usage: Sfx.play(&"attack"). Ability jingle intentionally left unwired.

const BANK := {
	&"attack": preload("res://Asset/SFX/attack.wav"),
	&"dash": preload("res://Asset/SFX/dash.wav"),
	&"enemy_hurt": preload("res://Asset/SFX/enemy_hurt.wav"),
	&"hurt": preload("res://Asset/SFX/hurt.wav"),
	&"jump": preload("res://Asset/SFX/jump.wav"),
	&"lose": preload("res://Asset/SFX/lose.wav"),
	&"ability": preload("res://Asset/SFX/ability.wav"),
}
const POOL := 8

var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound: StringName) -> void:
	if not BANK.has(sound):
		return
	for p in _players:
		if not p.playing:
			p.stream = BANK[sound]
			p.pitch_scale = randf_range(0.96, 1.04) if sound != &"lose" else 1.0
			p.play()
			return
	# Pool exhausted: steal the oldest.
	var p0 := _players[0]
	p0.stream = BANK[sound]
	p0.play()
