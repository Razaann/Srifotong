extends EnemyBase
## Namosa drifter: no gravity, wanders around its spawn point, never strays far.
## Picks a nearby target every few seconds, eases toward it. Contact damages player.

@export var drift_speed := 28.0
@export var roam_radius := 64.0
@export var retarget_time := 2.5

var _home := Vector2.ZERO
var _target := Vector2.ZERO
var _retarget := 0.0
var _t := 0.0


func _ready() -> void:
	super._ready()
	_home = global_position
	_target = _home
	# Flyers ignore ground gravity.
	gravity = 0.0


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = retarget_time * randf_range(0.7, 1.3)
		_target = _home + Vector2(randf_range(-roam_radius, roam_radius), randf_range(-roam_radius * 0.6, roam_radius * 0.6))
	var to := _target - global_position
	var want := to * 2.0
	if want.length() > drift_speed:
		want = want.normalized() * drift_speed
	# Gentle bob so it feels airborne even when hovering.
	want.y += sin(_t * 3.0) * 8.0
	velocity = want + _tick_knock(delta)
	move_and_slide()
	_tick_contact(delta)
	var spr := _sprite()
	if spr != null and absf(velocity.x) > 4.0:
		spr.flip_h = velocity.x > 0.0
