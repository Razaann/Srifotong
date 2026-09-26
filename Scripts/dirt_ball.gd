extends Area2D
class_name DirtBall
## Buraka projectile: arcs with gravity, hurts Player on touch, breaks on world/timeout.

@export var fall_gravity := 500.0
@export var life := 3.0

var velocity := Vector2.ZERO
var _dead := false


static func spawn(parent: Node, from: Vector2, vel: Vector2) -> DirtBall:
	var ball := (load("res://Scenes/dirt_ball.tscn") as PackedScene).instantiate() as DirtBall
	parent.add_child(ball)
	ball.global_position = from
	ball.velocity = vel
	return ball


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	velocity.y += fall_gravity * delta
	global_position += velocity * delta
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr != null:
		spr.rotation += 6.0 * delta


func _on_body(body: Node2D) -> void:
	if _dead:
		return
	_dead = true
	if body is Player:
		(body as Player).take_damage(1, global_position)
	queue_free()
