extends EnemyBase
## Final battle: giant shroom. Cycles patrol -> bull charge (wall crash = dizzy
## punish window) or jump slam onto the player's last position. 30 hits.
## Only has a "walk" anim, so telegraphs are all squash / flash / shake.

enum State { INTRO, PATROL, BULL_WINDUP, BULL_CHARGE, DIZZY, JUMP_WINDUP, JUMP_FLY, RECOVER, DEAD }

@export var faces_left := false
@export var patrol_speed := 55.0
@export var patrol_time := 2.2
@export var bull_windup := 1.2
@export var bull_speed := 520.0
@export var bull_timeout := 2.5
@export var dizzy_time := 3.5
@export var jump_windup := 0.7
@export var jump_speed := 300.0

var _state: int = State.PATROL
var _t := 0.0
var _dir := -1
var _charge_dir := -1
var _jump_target := Vector2.ZERO
var _was_air := false
var _alternate := false
var _base_scale := Vector2.ONE


func _ready() -> void:
	super._ready()
	_base_scale = scale
	_face()
	# Dormant during the entry card; awakened when it fades.
	# Deferred: _ready runs while the tree is still setting up children.
	_to(State.INTRO, 999.0)
	_entry.call_deferred()


func take_damage(dmg: int, from_pos: Vector2) -> void:
	if _state == State.INTRO:
		return
	super(dmg, from_pos)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t -= delta
	match _state:
		State.INTRO:
			_apply_gravity(delta)
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			move_and_slide()
			_tick_contact(delta)
		State.PATROL:
			_patrol(delta)
			if _t <= 0.0:
				_pick_attack()
		State.BULL_WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			_apply_gravity(delta)
			move_and_slide()
			_face_player()
			_shake_visual()
			if _t <= 0.0:
				_start_charge()
		State.BULL_CHARGE:
			velocity = Vector2(float(_charge_dir) * bull_speed, 0.0)
			move_and_slide()
			_tick_contact(delta)
			if is_on_wall() or _t <= 0.0:
				_crash()
		State.DIZZY:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			_apply_gravity(delta)
			move_and_slide()
			rotation = sin(Time.get_ticks_msec() / 90.0) * 0.07
			if _t <= 0.0:
				rotation = 0.0
				_set_hit(false)
				_to(State.RECOVER, 0.5)
		State.JUMP_WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			_apply_gravity(delta)
			move_and_slide()
			_face_player()
			if _t <= 0.0:
				_start_leap()
		State.JUMP_FLY:
			_apply_gravity(delta)
			move_and_slide()
			_tick_contact(delta)
			if is_on_floor() and _was_air:
				_land()
			elif _t <= 0.0 and is_on_floor():
				_land()
			_was_air = not is_on_floor()
		State.RECOVER:
			_apply_gravity(delta)
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			move_and_slide()
			_tick_contact(delta)
			if _t <= 0.0:
				_to(State.PATROL, patrol_time * randf_range(0.8, 1.2))


# -- entry card ------------------------------------------------------------

func _entry() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	get_tree().current_scene.add_child(layer)
	var white := ColorRect.new()
	white.color = Color(1, 1, 1, 0)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(white)
	var label := Label.new()
	label.text = "Akhirnya Seseorang Datang"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_override("font", load("res://Asset/m6x11.ttf") as Font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.2))
	label.modulate.a = 0.0
	layer.add_child(label)
	var tw := white.create_tween()
	tw.set_parallel(true)
	tw.tween_property(white, "color:a", 1.0, 0.5)
	tw.tween_property(label, "modulate:a", 1.0, 0.5)
	await tw.finished
	if _dead:
		return
	await get_tree().create_timer(2.2).timeout
	var tw2 := white.create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(white, "color:a", 0.0, 0.6)
	tw2.tween_property(label, "modulate:a", 0.0, 0.6)
	await tw2.finished
	layer.queue_free()
	if not _dead and _state == State.INTRO:
		Sfx.play(&"enemy_hurt") # roar-ish cue as the fight starts
		_to(State.PATROL, patrol_time)


# -- shared bits -----------------------------------------------------------

func _to(s: int, time: float) -> void:
	_state = s
	_t = time


func _patrol(delta: float) -> void:
	_apply_gravity(delta)
	var wall := get_node_or_null("WallCheck") as RayCast2D
	var ledge := get_node_or_null("LedgeCheck") as RayCast2D
	if (wall != null and wall.is_colliding()) or (ledge != null and is_on_floor() and not ledge.is_colliding()):
		_dir *= -1
	velocity.x = float(_dir) * patrol_speed + _tick_knock(delta).x
	move_and_slide()
	_face()
	_tick_contact(delta)


func _pick_attack() -> void:
	_alternate = not _alternate
	if _alternate:
		_to(State.BULL_WINDUP, bull_windup)
		Sfx.play(&"enemy_hurt")
	else:
		_to(State.JUMP_WINDUP, jump_windup)
		_squash(Vector2(1.3, 0.65))


func _face() -> void:
	var spr := _sprite()
	if spr != null:
		spr.flip_h = (_dir > 0) == faces_left


func _face_player() -> void:
	var p := _tracked_player()
	if p == null:
		return
	_dir = 1 if p.global_position.x > global_position.x else -1
	_face()


func _tracked_player() -> Player:
	var best: Player = null
	var best_d := 1e9
	for n in get_tree().get_nodes_in_group("Player"):
		if n is Player:
			var d := (n as Node2D).global_position.distance_squared_to(global_position)
			if d < best_d:
				best_d = d
				best = n
	return best


func _shake_visual() -> void:
	var spr := _sprite()
	if spr == null:
		return
	spr.position = Vector2(randf_range(-3.0, 3.0), 0.0)
	spr.modulate = Color(3.0, 0.7, 0.7) if int(Time.get_ticks_msec() / 120) % 2 == 0 else Color.WHITE


func _calm_visual() -> void:
	var spr := _sprite()
	if spr == null:
		return
	spr.position = Vector2.ZERO
	spr.modulate = Color.WHITE


func _squash(f: Vector2) -> void:
	var tw := create_tween()
	scale = _base_scale * f
	tw.tween_property(self, "scale", _base_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_hit(on: bool) -> void:
	var hit := get_node_or_null("HitArea") as Area2D
	if hit != null:
		hit.set_deferred("monitoring", on)


func _camera_kick(power: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var base := cam.offset
	cam.offset = base + Vector2(randf_range(-power, power), randf_range(-power, power))
	var tw := create_tween()
	tw.tween_property(cam, "offset", base, 0.35)


func _burst(count: int, spread: float) -> void:
	var spr := _sprite()
	var tex: Texture2D = null
	if spr != null and spr.sprite_frames != null:
		tex = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	for i in count:
		var puff := Sprite2D.new()
		if tex != null:
			puff.texture = tex
			puff.scale = _base_scale * 0.4
		puff.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		get_parent().add_child(puff)
		puff.global_position = global_position + Vector2(randf_range(-16, 16), randf_range(-8, 8))
		puff.modulate = Color(0.9, 0.9, 0.9, 0.6)
		var target := puff.global_position + Vector2(randf_range(-spread, spread), randf_range(-spread, -spread * 0.3))
		var tw := puff.create_tween()
		tw.set_parallel(true)
		tw.tween_property(puff, "global_position", target, 0.4)
		tw.tween_property(puff, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(puff.queue_free)


# -- bull charge -----------------------------------------------------------

func _start_charge() -> void:
	_calm_visual()
	_charge_dir = _dir
	_face()
	_to(State.BULL_CHARGE, bull_timeout)
	Sfx.play(&"dash")


func _crash() -> void:
	_calm_visual()
	_camera_kick(12.0)
	_burst(10, 60.0)
	Sfx.play(&"attack")
	var p := _tracked_player()
	if p != null:
		p.add_trauma(0.5)
	_set_hit(false) # dizzy = safe punish window
	_to(State.DIZZY, dizzy_time)


# -- jump slam -------------------------------------------------------------

func _start_leap() -> void:
	_calm_visual()
	var p := _tracked_player()
	_jump_target = p.global_position if p != null else global_position + Vector2(120 * _dir, 0)
	var from := global_position
	var dist := absf(_jump_target.x - from.x)
	var time := clampf(dist / jump_speed, 0.5, 1.0)
	velocity = Vector2((_jump_target.x - from.x) / time, (_jump_target.y - from.y) / time - 0.5 * gravity * time)
	scale = _base_scale * Vector2(0.85, 1.2)
	_was_air = false
	_to(State.JUMP_FLY, 3.0)
	Sfx.play(&"jump")


func _land() -> void:
	scale = _base_scale
	_squash(Vector2(1.35, 0.6))
	_burst(12, 70.0)
	_camera_kick(10.0)
	Sfx.play(&"attack")
	var p := _tracked_player()
	if p != null:
		p.add_trauma(0.45)
	_to(State.RECOVER, 0.8)


# -- death = ending cinematic ----------------------------------------------

func _die() -> void:
	if _dead:
		return
	_dead = true
	_calm_visual()
	rotation = 0.0
	velocity = Vector2.ZERO
	_state = State.DEAD
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var hit := get_node_or_null("HitArea") as Area2D
	if hit != null:
		hit.set_deferred("monitoring", false)
	var hurt := get_node_or_null("HurtArea") as Area2D
	if hurt != null:
		hurt.set_deferred("monitorable", false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", _base_scale * Vector2(1.3, 0.4), 1.2)
	tw.tween_property(self, "modulate", Color(3, 3, 3), 1.2)
	_burst(16, 90.0)
	Sfx.play(&"lose")
	await tw.finished
	_ending()


func _ending() -> void:
	var player := _tracked_player()
	if player != null:
		player.control_locked = true
		player._invuln = 99.0
	var layer := CanvasLayer.new()
	layer.layer = 90
	get_tree().current_scene.add_child(layer)
	var white := ColorRect.new()
	white.color = Color(1, 1, 1, 0)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(white)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_override("font", load("res://Asset/m6x11.ttf") as Font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.2))
	label.modulate.a = 0.0
	layer.add_child(label)
	var tw := white.create_tween()
	tw.tween_property(white, "color:a", 1.0, 0.8)
	await tw.finished
	for line in ["Wow, kau mengalahkan penjahatnya", "lalu apa yang kau harapkan", "The End ?"]:
		label.text = line
		var a := label.create_tween()
		a.tween_property(label, "modulate:a", 1.0, 0.5)
		await a.finished
		await get_tree().create_timer(2.2 if line != "The End ?" else 3.0).timeout
		if line == "The End ?":
			break
		var b := label.create_tween()
		b.tween_property(label, "modulate:a", 0.0, 0.5)
		await b.finished
	get_tree().quit()
