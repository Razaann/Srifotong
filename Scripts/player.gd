extends CharacterBody2D
class_name Player
## Boy_Adventure C — jalan, lompat, attack sederhana.
## Kontrol: A/D atau Panah = jalan, Space = lompat, J/X = attack, E = interaksi.
## Kiri-kanan cukup flip_h (sprite menghadap kanan).

@export var speed := 140.0
@export var jump_force := -300.0
@export var gravity := 900.0
@export_range(0.0, 1.0) var jump_cut := 0.45 ## velocity kept when jump released early (lower = shorter hop)
@export var max_jumps := 2 ## set to 2 later for double jump; logic already supports it
@export var dash_speed := 320.0
@export var dash_time := 0.16
@export var dash_cooldown := 0.5
@export var max_hp := 3
@export var invuln_time := 0.8
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
var _jumps_used := 0 # counts jumps since leaving floor; max_jumps=2 enables double jump later
var _is_dashing := false
var _dash_time_left := 0.0
var _dash_cd := 0.0
var _dash_dir := 1
var _ghost_tick := 0.0
var _fall_speed := 0.0
var _squash_tween: Tween
var hp: int
var _invuln := 0.0
var _dead := false
var _swing_id := 0
var _hit_this_swing: Array = []
var _trauma := 0.0 ## screen shake energy 0..1, fed by hits
var _shake_cam: Camera2D
var _shake_base := Vector2.ZERO

func _ready() -> void:
	hp = max_hp
	hitbox.collision_layer = 4
	hitbox.collision_mask = 8
	hitbox.area_entered.connect(_on_hitbox_area)
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
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	anim.modulate.a = 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() / 60.0)) if _invuln > 0.0 and not _dead else 1.0
	if _dead:
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
		move_and_slide()
		return
	if is_on_floor():
		_jumps_used = 0
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		_facing = 1 if dir > 0.0 else -1
		anim.flip_h = _facing < 0
		hitshape.position.x = 14.0 * _facing
	# Start dash: responsive cancel out of attack, works ground + air.
	if Input.is_action_just_pressed("dash") and not _is_dashing and _dash_cd <= 0.0:
		_start_dash(dir)
	if _is_dashing:
		_dash_time_left -= delta
		velocity = Vector2(float(_dash_dir) * dash_speed, 0.0)
		_ghost_tick -= delta
		if _ghost_tick <= 0.0:
			_ghost_tick = 0.03
			_spawn_ghost()
		move_and_slide()
		if _dash_time_left <= 0.0:
			_end_dash()
		return
	var was_floor := is_on_floor()
	_fall_speed = maxf(_fall_speed, velocity.y) if not was_floor else 0.0
	if not is_on_floor():
		velocity.y += gravity * delta
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
		_try_jump()
	# Variable height: releasing jump early cuts upward velocity.
	# Full hold = full jump_force height; tap = hop. Works for jump 1 and future double jump.
	# Guarded against dash so dash velocity is never cut.
	if Input.is_action_just_released("jump") and velocity.y < 0.0 and not _is_dashing:
		velocity.y *= jump_cut
	move_and_slide()
	# Landing: squash + dust scaled by fall speed. Heavy fall = bigger squash + more dust.
	if not was_floor and is_on_floor():
		_play_land_squash(_fall_speed)
		_fall_speed = 0.0
	if _combo != 0:
		return
	if not is_on_floor():
		_play(&"jump")
	elif dir != 0.0:
		_play(&"run")
	else:
		_play(&"idle")

func _process(delta: float) -> void:
	_tick_shake(delta)
	if not pbubble.visible:
		return
	var top: Vector2 = get_global_transform_with_canvas() * Vector2(0, -40)
	var vsz := get_viewport().get_visible_rect().size
	pbubble.size = pbubble.get_combined_minimum_size()
	pbubble.position = Vector2(clampf(top.x - pbubble.size.x * 0.5, 4.0, vsz.x - pbubble.size.x - 4.0), top.y - pbubble.size.y - 4.0)


func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func _tick_shake(delta: float) -> void:
	if _trauma <= 0.0:
		return
	_trauma = maxf(0.0, _trauma - delta * 1.6)
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		_trauma = 0.0
		return
	if cam != _shake_cam:
		_shake_cam = cam
		_shake_base = cam.offset
	if _trauma <= 0.0:
		cam.offset = _shake_base
		_shake_cam = null
		return
	var s := _trauma * _trauma * 14.0
	cam.offset = _shake_base + Vector2(randf_range(-s, s), randf_range(-s, s))

func _play(name: StringName) -> void:
	if anim.animation != name:
		anim.play(name)

func _try_jump() -> void:
	if not Input.is_action_just_pressed("jump"):
		return
	if is_on_floor():
		_jumps_used = 0
	if _jumps_used >= max_jumps:
		return
	var air_jump := not is_on_floor()
	_jumps_used += 1
	velocity.y = jump_force
	_play_jump_stretch(air_jump)

func _kill_squash_tween() -> void:
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = null

func _play_jump_stretch(air_jump: bool) -> void:
	# Takeoff: tall stretch + dust ring at feet. Air jump gets extra pop + flip flick.
	if _is_dashing:
		return
	_kill_squash_tween()
	anim.scale = Vector2(0.75, 1.35) if not air_jump else Vector2(0.7, 1.4)
	_spawn_dust(5 if not air_jump else 7, 26.0)
	_squash_tween = create_tween()
	_squash_tween.tween_property(anim, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if air_jump:
		# Quick spin-flick so double jump (later) reads clearly even with same sprite.
		var tw := create_tween()
		tw.tween_property(anim, "rotation", float(_facing) * TAU, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void: anim.rotation = 0.0)

func _play_land_squash(fall_speed: float) -> void:
	if _is_dashing:
		return
	# Ignore tiny step-offs; scale squash with impact.
	if fall_speed < 120.0:
		return
	var strength := clampf(fall_speed / 900.0, 0.35, 1.0)
	_kill_squash_tween()
	anim.scale = Vector2(1.0 + 0.35 * strength, 1.0 - 0.3 * strength)
	_spawn_dust(int(4.0 + 6.0 * strength), 20.0 + 30.0 * strength)
	_squash_tween = create_tween()
	_squash_tween.tween_property(anim, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _spawn_dust(count: int, power: float) -> void:
	var tex: Texture2D = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	var feet := global_position + Vector2(0, -2)
	for i in count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var puff := Sprite2D.new()
		if tex != null:
			puff.texture = tex
			puff.scale = Vector2(0.25, 0.25)
		puff.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		get_parent().add_child(puff)
		puff.global_position = feet + Vector2(randf_range(-4.0, 4.0), randf_range(-2.0, 0.0))
		puff.modulate = Color(0.95, 0.95, 0.9, 0.55)
		var target := puff.global_position + Vector2(side * randf_range(power * 0.5, power), randf_range(-power * 0.7, -power * 0.2))
		var tw := puff.create_tween()
		tw.set_parallel(true)
		tw.tween_property(puff, "global_position", target, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "modulate:a", 0.0, 0.3)
		tw.tween_property(puff, "scale", Vector2(0.12, 0.12), 0.3)
		tw.chain().tween_callback(puff.queue_free)

func _start_dash(dir: float) -> void:
	_is_dashing = true
	_dash_time_left = dash_time
	_dash_cd = dash_cooldown
	_dash_dir = int(signf(dir)) if dir != 0.0 else _facing
	_facing = _dash_dir
	anim.flip_h = _facing < 0
	hitshape.position.x = 14.0 * _facing
	if _combo != 0:
		_end_attack()
	# Stretch along dash axis — reads as speed on pixel sprite.
	_kill_squash_tween()
	anim.rotation = 0.0
	anim.scale = Vector2(1.3, 0.7)
	_ghost_tick = 0.0
	_spawn_ghost()

func _end_dash() -> void:
	_is_dashing = false
	velocity.x = float(_dash_dir) * speed * 0.5
	velocity.y = minf(velocity.y, 0.0)
	# Squash-then-recover so dash end has weight.
	_kill_squash_tween()
	anim.scale = Vector2(0.8, 1.25)
	_squash_tween = create_tween()
	_squash_tween.tween_property(anim, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _spawn_ghost() -> void:
	# Afterimage fade: snapshot current frame, fade out, free. No assets needed.
	var tex: Texture2D = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	if tex == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = tex
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.show_behind_parent = true
	get_parent().add_child(ghost)
	ghost.global_position = anim.global_position
	ghost.flip_h = anim.flip_h
	ghost.scale = anim.scale
	ghost.modulate = Color(0.7, 0.9, 1.0, 0.5)
	var tw := ghost.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_property(ghost, "global_position:x", ghost.global_position.x - float(_dash_dir) * 12.0, 0.25)
	tw.chain().tween_callback(ghost.queue_free)

func _start_attack(n: int) -> void:
	_combo = n
	_buffered = false
	_swing_id += 1
	_hit_this_swing.clear()
	hitbox.monitoring = true
	if is_on_floor():
		velocity.x = 70.0 * _facing # langkah kecil ke depan biar tebasan terasa
	_play(StringName("attack%d" % n))

func _end_attack() -> void:
	_combo = 0
	_buffered = false
	hitbox.monitoring = false

func _on_hitbox_area(area: Area2D) -> void:
	if _combo == 0 or _dead:
		return
	if area.owner == self:
		return # never hit your own HurtArea, even if one gets a damage script later
	if area.has_method("take_damage") and not _hit_this_swing.has(area.get_instance_id()):
		_hit_this_swing.append(area.get_instance_id())
		area.call("take_damage", 1, global_position)


func take_damage(dmg: int, from_pos: Vector2) -> void:
	if _dead or _invuln > 0.0 or _is_dashing:
		return
	hp -= dmg
	_invuln = invuln_time
	add_trauma(0.55)
	var push := global_position - from_pos
	push.y = 0.0
	if push.length() < 1.0:
		push = Vector2(float(-_facing), 0.0)
	velocity = push.normalized() * 180.0 + Vector2(0, -120)
	if _combo != 0:
		_end_attack()
	if hp <= 0:
		_die()
	else:
		_play(&"hurt")


func _die() -> void:
	_dead = true
	_is_dashing = false
	hitbox.set_deferred("monitoring", false)
	_kill_squash_tween()
	anim.rotation = 0.0
	anim.scale = Vector2.ONE
	add_trauma(1.0)
	# Death anim plays once (~1s); input already locked via _dead.
	anim.stop()
	anim.play(&"death")
	await _fade_to_black(3.0)
	get_tree().reload_current_scene()


func _fade_to_black(duration: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 1.0, duration)
	await tw.finished


func _on_animation_finished() -> void:
	if anim.animation == &"death":
		return # hold last frame under the fade
	if anim.animation == &"hurt":
		_play(&"idle")
		return
	if anim.animation in [&"attack1", &"attack2", &"attack3", &"attack4"]:
		if _buffered:
			_start_attack(_combo % 4 + 1)
		else:
			_end_attack()
