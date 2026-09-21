extends CharacterBody2D
class_name Player
## Boy_Adventure C — jalan, lompat, attack sederhana.
## Kontrol: A/D atau Panah = jalan, Space = lompat, J/X = attack, E = interaksi.
## Kiri-kanan cukup flip_h (sprite menghadap kanan).

@export var speed := 140.0
@export var jump_force := -320.0
@export var gravity := 900.0
@export var intro_lines: PackedStringArray = ["Sudah malam, persediaan kayuku sudah mau habis", "Aku harus segera ke hutan untuk mencari kayu"]

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $MeleeHitbox
@onready var hitshape: CollisionShape2D = $MeleeHitbox/CollisionShape2D
@onready var pbubble: PanelContainer = $BubbleLayer/Bubble
@onready var pname: Label = $BubbleLayer/Bubble/VBox/Name
@onready var ptext: Label = $BubbleLayer/Bubble/VBox/Text

var _combo := 0 # 0 = tidak menyerang, 1 = ayunan 1, 2 = ayunan 2
var _buffered := false # tombol attack ditekan saat ayunan berjalan -> lanjut combo
var _facing := 1

func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	_play(&"idle")
	_play_intro()

func _play_intro() -> void:
	if intro_lines.is_empty():
		return
	await get_tree().create_timer(1.0).timeout
	for line in intro_lines:
		say(line)
		await get_tree().create_timer(3.0).timeout
	stop_say()

func say(text: String, who := "Pemuda") -> void:
	pname.text = who
	ptext.text = text
	pbubble.visible = true

func stop_say() -> void:
	pbubble.visible = false

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		_facing = 1 if dir > 0.0 else -1
		anim.flip_h = _facing < 0
		hitshape.position.x = 14.0 * _facing
	if Input.is_action_just_pressed("attack"):
		if _combo == 0:
			_start_attack(1)
		else:
			_buffered = true
	if _combo != 0:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
	else:
		velocity.x = dir * speed
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_force
	move_and_slide()
	if _combo != 0:
		return
	if not is_on_floor():
		_play(&"jump")
	elif dir != 0.0:
		_play(&"run")
	else:
		_play(&"idle")

func _process(_delta: float) -> void:
	if not pbubble.visible:
		return
	var top: Vector2 = get_global_transform_with_canvas() * Vector2(0, -40)
	var vsz := get_viewport().get_visible_rect().size
	pbubble.size = pbubble.get_combined_minimum_size()
	pbubble.position = Vector2(clampf(top.x - pbubble.size.x * 0.5, 4.0, vsz.x - pbubble.size.x - 4.0), top.y - pbubble.size.y - 4.0)

func _play(name: StringName) -> void:
	if anim.animation != name:
		anim.play(name)

func _start_attack(n: int) -> void:
	_combo = n
	_buffered = false
	hitbox.monitoring = true
	if is_on_floor():
		velocity.x = 70.0 * _facing # langkah kecil ke depan biar tebasan terasa
	_play(StringName("attack%d" % n))

func _end_attack() -> void:
	_combo = 0
	_buffered = false
	hitbox.monitoring = false

func _on_animation_finished() -> void:
	if anim.animation in [&"attack1", &"attack2", &"attack3", &"attack4"]:
		if _buffered:
			_start_attack(_combo % 4 + 1)
		else:
			_end_attack()
