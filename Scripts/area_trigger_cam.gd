extends Area2D
class_name AreaTriggerCam
## Modular room-camera trigger.
## Base scene has NO CollisionShape2D — instance it in a room scene,
## add a CollisionShape2D child there, and set target_camera_position
## (global X/Y) in the Inspector. When a body in the Player group enters,
## the fixed Camera2D tweens to that position. Enter-only.

@export var target_camera_position: Vector2 = Vector2.ZERO
@export var tween_duration: float = 0.8
@export var trigger_once: bool = true
@export var camera_path: NodePath = NodePath("")

var _tween: Tween
var _fired := false


func _ready() -> void:
	body_entered.connect(_on_entered)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var has_shape := false
	for child in get_children():
		if child is CollisionShape2D:
			has_shape = true
			break
	if not has_shape:
		warnings.append("No CollisionShape2D child — add one in the host room scene.")
	return warnings


func _on_entered(body: Node2D) -> void:
	if _fired and trigger_once:
		return
	if not body.is_in_group("Player"):
		return
	var cam := _resolve_camera()
	if cam == null:
		push_warning("AreaTriggerCam: no Camera2D found (room_camera group / camera_path / viewport).")
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(cam, "global_position", target_camera_position, tween_duration)
	if trigger_once:
		_fired = true
		set_deferred("monitoring", false)


func _resolve_camera() -> Camera2D:
	if camera_path != NodePath(""):
		var n := get_node_or_null(camera_path)
		if n is Camera2D:
			return n
	var grouped := get_tree().get_first_node_in_group("room_camera")
	if grouped is Camera2D:
		return grouped
	return get_viewport().get_camera_2d()
