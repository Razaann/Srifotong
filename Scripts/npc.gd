extends StaticBody2D
class_name NPC
## Warga desa: diam di posisi, menoleh ke player saat didekati.
## Dekat -> prompt F muncul. Tekan F (interact) -> bubble chat per baris, F lagi = lanjut.

@export var npc_name := "Warga"
@export var dialogue_lines: PackedStringArray = ["Halo!"]

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt: Label = $BubbleLayer/Prompt
@onready var bubble: PanelContainer = $BubbleLayer/Bubble
@onready var name_label: Label = $BubbleLayer/Bubble/VBox/Name
@onready var body_label: Label = $BubbleLayer/Bubble/VBox/Text

var _near := false
var _talking := false
var _idx := 0
var _player: Player = null

func _ready() -> void:
	prompt.visible = false
	bubble.visible = false
	($TalkZone as Area2D).body_entered.connect(_on_entered)
	($TalkZone as Area2D).body_exited.connect(_on_exited)

func _process(_delta: float) -> void:
	if _player != null and is_instance_valid(_player):
		anim.flip_h = _player.global_position.x < global_position.x
	if _near and Input.is_action_just_pressed("interact"):
		if not _talking:
			_talking = true
			_idx = 0
			_show_line()
		else:
			_advance()
	_update_floaters()

func _update_floaters() -> void:
	if not prompt.visible and not bubble.visible:
		return
	var top: Vector2 = get_global_transform_with_canvas() * Vector2(0, -40)
	var vsz := get_viewport().get_visible_rect().size
	if bubble.visible:
		bubble.size = bubble.get_combined_minimum_size()
		bubble.position = Vector2(clampf(top.x - bubble.size.x * 0.5, 4.0, vsz.x - bubble.size.x - 4.0), top.y - bubble.size.y - 4.0)
	elif prompt.visible:
		prompt.size = prompt.get_combined_minimum_size()
		prompt.position = Vector2(clampf(top.x - prompt.size.x * 0.5, 4.0, vsz.x - prompt.size.x - 4.0), top.y - prompt.size.y - 2.0)

func _on_entered(body: Node2D) -> void:
	if body is Player:
		_near = true
		_player = body as Player
		if not _talking:
			prompt.visible = true

func _on_exited(body: Node2D) -> void:
	if body is Player:
		_near = false
		prompt.visible = false
		_stop_talk()
		_player = null

func _show_line() -> void:
	var line := dialogue_lines[_idx] if _idx < dialogue_lines.size() else "..."
	prompt.visible = false
	if line.begins_with("P:"):
		bubble.visible = false
		if _player != null and is_instance_valid(_player):
			_player.say(line.substr(2).strip_edges())
	else:
		if _player != null and is_instance_valid(_player):
			_player.stop_say()
		if line.begins_with("N:"):
			line = line.substr(2).strip_edges()
		name_label.text = npc_name
		body_label.text = line
		bubble.visible = true

func _advance() -> void:
	_idx += 1
	if _idx >= dialogue_lines.size():
		_stop_talk()
	else:
		_show_line()

func _stop_talk() -> void:
	_talking = false
	_idx = 0
	bubble.visible = false
	if _player != null and is_instance_valid(_player):
		_player.stop_say()
	prompt.visible = _near
