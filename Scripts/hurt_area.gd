extends Area2D
class_name HurtArea
## Pure damage target. Owner must be an EnemyBase (or implement take_damage).
## MeleeHitbox (layer 4 / mask 8) detects this during a swing and calls take_damage().

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func take_damage(dmg: int, from_pos: Vector2) -> void:
	var o := owner
	if o != null and o.has_method("take_damage"):
		o.take_damage(dmg, from_pos)
