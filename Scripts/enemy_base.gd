extends CharacterBody2D
class_name EnemyBase
## Shared HP / flash / knockback / death + contact damage wiring.
## Child HurtArea (hurt_area.gd) forwards take_damage() here.
## Child HitArea (plain Area2D) damages the Player on body contact.

@export var max_hp := 3
@export var contact_damage := 1
@export var contact_cooldown := 1.0 ## re-hit delay while player stays in contact
@export var knockback_force := 160.0
@export var gravity := 900.0

var hp: int
var _dead := false
var _flash_tween: Tween
var _knock := Vector2.ZERO
var _contact_cd := 0.0


func _ready() -> void:
	hp = max_hp
	_wire_contact()


func take_damage(dmg: int, from_pos: Vector2) -> void:
	if _dead:
		return
	hp -= dmg
	_flash()
	var push := global_position - from_pos
	push.y = 0.0
	if push.length() < 1.0:
		push = Vector2(float(-_facing_sign()), 0.0)
	_knock = push.normalized() * knockback_force
	if hp <= 0:
		_die()
	# else: keep AI running; flash is the feedback (no hurt anim on these sprites)


func _die() -> void:
	_dead = true
	_knock = Vector2.ZERO
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	for child in get_children():
		if child is Area2D:
			child.set_deferred("monitoring", false)
			child.set_deferred("monitorable", false)
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
		if child is RayCast2D:
			child.enabled = false
	_flash_cancel()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.2, 0.5), 0.18)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(queue_free)


func _flash() -> void:
	_flash_cancel()
	var spr := _sprite()
	if spr == null:
		return
	spr.modulate = Color(3.0, 0.6, 0.6)
	_flash_tween = create_tween()
	_flash_tween.tween_property(spr, "modulate", Color.WHITE, 0.18)


func _flash_cancel() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	var spr := _sprite()
	if spr != null:
		spr.modulate = Color.WHITE


func _sprite() -> AnimatedSprite2D:
	var n := get_node_or_null("AnimatedSprite2D")
	return n as AnimatedSprite2D


func _facing_sign() -> int:
	var spr := _sprite()
	if spr != null and spr.flip_h:
		return -1
	return 1


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


## Knockback decay shared by all movers. Call each physics frame and add result.
func _tick_knock(delta: float) -> Vector2:
	_knock = _knock.move_toward(Vector2.ZERO, knockback_force * 4.0 * delta)
	return _knock


func _wire_contact() -> void:
	var hit := get_node_or_null("HitArea") as Area2D
	if hit == null:
		return
	hit.collision_layer = 16
	hit.collision_mask = 1
	hit.monitoring = true
	hit.monitorable = false
	if not hit.body_entered.is_connected(_on_contact_body):
		hit.body_entered.connect(_on_contact_body)


func _on_contact_body(body: Node2D) -> void:
	_attempt_contact(body)


## Instant hit (signal) + sustained contact (polled below) share one cooldown,
## so staying inside the HitArea re-hits every contact_cooldown seconds.
func _attempt_contact(body: Node2D) -> void:
	if _dead or _contact_cd > 0.0:
		return
	if body is Player:
		(body as Player).take_damage(contact_damage, global_position)
		_contact_cd = contact_cooldown


## Call every physics frame. body_entered fires only on enter, so without
## this a player who stays inside (or entered during i-frames) is never hit again.
func _tick_contact(delta: float) -> void:
	_contact_cd = maxf(0.0, _contact_cd - delta)
	if _dead or _contact_cd > 0.0:
		return
	var hit := get_node_or_null("HitArea") as Area2D
	if hit == null or not hit.monitoring:
		return
	for b in hit.get_overlapping_bodies():
		if b is Player:
			_attempt_contact(b)
			break
