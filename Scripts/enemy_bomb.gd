extends EnemyBase
## Buraka thrower: stationary, watches Detection circle for Player group,
## faces the target and lobs a DirtBall from the Muzzle Marker2D in an arc.
## Your hidden DirtBall Sprite2D stays as the held ball; Muzzle marks the spawn point.

@export var throw_cooldown := 2.0
@export var ball_speed := 220.0
@export var arc_height := 60.0
@export var muzzle_forward := 16.0 ## how far in front of the enemy the ball spawns
@export var muzzle_height := 0.0

var _player: Player
var _cd := 1.0
var _winding := false


func _ready() -> void:
	super._ready()
	_cd = throw_cooldown * 0.5
	var det := get_node_or_null("Detection") as Area2D
	if det != null:
		det.collision_layer = 0
		det.collision_mask = 1
		det.monitoring = true
		det.monitorable = false
		det.body_entered.connect(_on_detect_body)
		det.body_exited.connect(_on_lose_body)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_apply_gravity(delta)
	velocity.x = _tick_knock(delta).x
	move_and_slide()
	_tick_contact(delta)
	_cd -= delta
	if _player != null and not is_instance_valid(_player):
		_player = null
	if _player != null:
		var face_right := _player.global_position.x > global_position.x
		var spr := _sprite()
		if spr != null:
			spr.flip_h = face_right
		var muz := get_node_or_null("Muzzle") as Marker2D
		if muz != null:
			muz.position = Vector2(muzzle_forward if face_right else -muzzle_forward, muzzle_height)
		if _cd <= 0.0 and not _winding:
			_cd = throw_cooldown
			_throw()


func _on_detect_body(body: Node2D) -> void:
	if body is Player:
		_player = body


func _on_lose_body(body: Node2D) -> void:
	if body == _player:
		_player = null
		_back_to_idle()


func _back_to_idle() -> void:
	if _dead or _winding:
		return
	var spr := _sprite()
	if spr != null and spr.sprite_frames != null and spr.sprite_frames.has_animation(&"default"):
		spr.play(&"default")


func _throw() -> void:
	if _player == null or _dead or _winding:
		return
	_winding = true
	# Commit to the target snapshot now; ball releases when the throw anim finishes.
	var target: Vector2 = _player.global_position + Vector2(0, -8)
	var spr := _sprite()
	if spr != null and spr.sprite_frames != null and spr.sprite_frames.has_animation(&"throw"):
		spr.stop()
		spr.play(&"throw")
		await spr.animation_finished
	_winding = false
	if _dead:
		return
	_release(target)
	_back_to_idle()


func _release(target: Vector2) -> void:
	var muzzle := get_node_or_null("Muzzle") as Marker2D
	var from: Vector2 = muzzle.global_position if muzzle != null else global_position + Vector2(0, -12)
	# Pick flight time from distance so arc looks consistent near and far.
	var dist := absf(target.x - from.x)
	var t := clampf(dist / ball_speed, 0.3, 1.0)
	var vel := Vector2((target.x - from.x) / t, (target.y - from.y) / t - 0.5 * 500.0 * t)
	DirtBall.spawn(get_tree().current_scene, from, vel)
