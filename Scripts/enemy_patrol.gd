extends EnemyBase
## Shroom walker: patrols, turns at walls and ledges. Contact damages player.
## Needs children: WallCheck (RayCast2D forward), LedgeCheck (RayCast2D ahead-down).

@export var walk_speed := 30.0
@export var faces_left := false ## set true if the sheet faces left (walks backwards)

var _dir := -1
var _wall_pos := Vector2(-6, -8)
var _wall_tgt := Vector2(-4, 0)
var _ledge_x := -10.0


func _ready() -> void:
	super._ready()
	_remember_rays()
	_face()


## Snapshot your editor-placed ray positions so turns only mirror their
## direction, never overwrite your lengths/offsets.
func _remember_rays() -> void:
	var wall := get_node_or_null("WallCheck") as RayCast2D
	if wall != null:
		_wall_pos = wall.position
		_wall_tgt = wall.target_position
	var ledge := get_node_or_null("LedgeCheck") as RayCast2D
	if ledge != null:
		_ledge_x = ledge.position.x


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_apply_gravity(delta)
	var wall := get_node_or_null("WallCheck") as RayCast2D
	var ledge := get_node_or_null("LedgeCheck") as RayCast2D
	if (wall != null and wall.is_colliding()) or (ledge != null and is_on_floor() and not ledge.is_colliding()):
		_dir *= -1
	velocity.x = float(_dir) * walk_speed + _tick_knock(delta).x
	move_and_slide()
	_face() # enforce every frame so sprite + rays never desync from _dir
	_tick_contact(delta)


func _face() -> void:
	var face_right := _dir > 0
	var spr := _sprite()
	if spr != null:
		spr.flip_h = face_right == faces_left
	var wall := get_node_or_null("WallCheck") as RayCast2D
	if wall != null:
		var s := float(_dir)
		wall.position = Vector2(s * absf(_wall_pos.x), _wall_pos.y)
		wall.target_position = Vector2(s * absf(_wall_tgt.x), _wall_tgt.y)
	var ledge := get_node_or_null("LedgeCheck") as RayCast2D
	if ledge != null:
		ledge.position.x = float(_dir) * absf(_ledge_x)
