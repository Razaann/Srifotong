extends Node2D
## Breakable butterfly ability bubble. Idle-bobs so it never sits still.
## Player swings call take_damage() (duck-typed via MeleeHitbox wiring).
## After hits_to_break hits: white flash, input lock, unlock text, grant ability.

@export var ability: StringName = &"dash" ## &"dash" or &"double_jump"
@export var unlock_text := "Kamu Mendapatkan Kemampuan Dash"
@export var hits_to_break := 3
const HURT_SCRIPT: Script = preload("res://Scripts/hurt_area.gd")

@export var bob_amp := 6.0
@export var bob_speed := 2.0

var _hits := 0
var _broken := false
var _base_y := 0.0
var _t := 0.0
var _hit_cd := 0.0


func _ready() -> void:
	_base_y = position.y
	var area := Area2D.new()
	area.name = "BreakArea"
	area.set_script(HURT_SCRIPT) # forwards take_damage() to owner (this bubble)
	add_child(area)
	area.owner = self
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 36.0
	shape.shape = circle
	area.add_child(shape)


func _process(delta: float) -> void:
	_hit_cd = maxf(0.0, _hit_cd - delta)
	if _broken:
		return
	_t += delta
	position.y = _base_y + sin(_t * bob_speed) * bob_amp


func take_damage(_dmg: int, from_pos: Vector2) -> void:
	if _broken or _hit_cd > 0.0:
		return
	_hit_cd = 0.25
	_hits += 1
	var player := _find_player(from_pos)
	if player != null:
		player.add_trauma(0.4)
	Sfx.play(&"ability")
	_pop()
	if _hits >= hits_to_break:
		_break(player)


func _find_player(from_pos: Vector2) -> Player:
	var best: Player = null
	var best_d := 400.0
	for n in get_tree().get_nodes_in_group("Player"):
		if n is Player:
			var d := (n as Node2D).global_position.distance_to(from_pos)
			if d < best_d:
				best_d = d
				best = n
	return best


func _pop() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.08)
	tw.tween_property(self, "modulate", Color(2.0, 2.0, 2.0), 0.08)
	tw.chain().tween_property(self, "scale", Vector2.ONE, 0.12)
	tw.tween_property(self, "modulate", Color.WHITE, 0.12)


func _break(player: Player) -> void:
	_broken = true
	# Shatter pop, then hide the bubble + butterfly.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await tw.finished
	visible = false
	_unlock_cinematic(player)


func _unlock_cinematic(player: Player) -> void:
	if player != null and is_instance_valid(player):
		player.control_locked = true
		player._invuln = 6.0 # untouchable during the unlock show
	# White flash layer (under HUD hearts at 10, above world).
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 5
	get_tree().current_scene.add_child(flash_layer)
	var white := ColorRect.new()
	white.color = Color(1, 1, 1, 0)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_layer.add_child(white)
	# Unlock text above the flash.
	var text_layer := CanvasLayer.new()
	text_layer.layer = 90
	get_tree().current_scene.add_child(text_layer)
	var label := Label.new()
	label.text = unlock_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_override("font", load("res://Asset/m6x11.ttf") as Font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.2))
	label.modulate.a = 0.0
	text_layer.add_child(label)
	Sfx.play(&"ability")
	var tw := white.create_tween()
	tw.tween_property(white, "color:a", 1.0, 0.25)
	await tw.finished
	var tw2 := label.create_tween()
	tw2.tween_property(label, "modulate:a", 1.0, 0.4)
	await tw2.finished
	if not is_instance_valid(white) or _player_gone(player):
		return
	await get_tree().create_timer(1.6).timeout
	if not is_instance_valid(label) or _player_gone(player):
		return
	var tw3 := label.create_tween()
	tw3.tween_property(label, "modulate:a", 0.0, 0.5)
	await tw3.finished
	_grant(player)
	if player != null and is_instance_valid(player):
		player.control_locked = false
	var tw4 := white.create_tween()
	tw4.tween_property(white, "color:a", 0.0, 0.6)
	await tw4.finished
	flash_layer.queue_free()
	text_layer.queue_free()
	queue_free()


func _grant(player: Player) -> void:
	if player == null or not is_instance_valid(player):
		return
	if ability == &"double_jump":
		player.max_jumps = 2
	else:
		player.has_dash = true


func _player_gone(player: Player) -> bool:
	return player == null or not is_instance_valid(player) or player._dead
