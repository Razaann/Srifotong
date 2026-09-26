extends CanvasLayer
## Hearts HUD (autoload "HUD"). Top-left, 5 slots from HeartFull.png.
## Full hearts render normal, lost hearts go solid black,
## rightmost full heart beats. Follows the Player across scene changes.

const HEART: Texture2D = preload("res://Asset/16x16 Pixel art Platformer 2D Assets/Pixel art Assets Itch.io/Heart/HeartFull.png")
const SLOT := Vector2(32, 32) # 16px art x2
const LOST := Color("353540")
const BEAT_SCALE := 1.22
const BEAT_TIME := 0.32

var _box: HBoxContainer
var _slots: Array[TextureRect] = []
var _player: Node
var _beat: Tween
var _boss_wrap: VBoxContainer
var _boss_bar: ProgressBar
var _boss: Node


func _ready() -> void:
	layer = 10
	_box = HBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_box.position = Vector2(8, 8)
	_box.add_theme_constant_override("separation", 4)
	add_child(_box)
	for i in 5:
		_box.add_child(_make_slot())
	_build_boss_bar()
	get_tree().tree_changed.connect(_hook_all)
	_hook_all()


func _build_boss_bar() -> void:
	_boss_wrap = VBoxContainer.new()
	_boss_wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_boss_wrap.offset_top = -46.0
	_boss_wrap.offset_bottom = -12.0
	_boss_wrap.offset_left = 90.0
	_boss_wrap.offset_right = -90.0
	_boss_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	_boss_wrap.add_theme_constant_override("separation", 2)
	add_child(_boss_wrap)
	var name_label := Label.new()
	name_label.text = "JAMUR RAKSASA"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", load("res://Asset/m6x11.ttf") as Font)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(1, 0.35, 0.35))
	_boss_wrap.add_child(name_label)
	_boss_bar = ProgressBar.new()
	_boss_bar.min_value = 0.0
	_boss_bar.max_value = 30.0
	_boss_bar.value = 30.0
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(0, 12)
	_boss_wrap.add_child(_boss_bar)
	_boss_wrap.visible = false


func _hook_all() -> void:
	_hook_player()
	_hook_boss()


func _hook_boss() -> void:
	var b := get_tree().get_first_node_in_group("Boss")
	if b == _boss:
		return
	_boss = b
	_boss_wrap.visible = b != null
	if b == null:
		return
	_boss_bar.max_value = float(b.get("max_hp"))
	_boss_bar.value = float(b.get("hp"))
	if b.has_signal("damaged") and not b.damaged.is_connected(_on_boss_hp):
		b.damaged.connect(_on_boss_hp)


func _on_boss_hp(hp: int, max_hp: int) -> void:
	_boss_bar.max_value = float(max_hp)
	_boss_bar.value = float(hp)


func _make_slot() -> TextureRect:
	var t := TextureRect.new()
	t.texture = HEART
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = SLOT
	t.pivot_offset = SLOT * 0.5
	_slots.append(t)
	return t


func _hook_player() -> void:
	var p := get_tree().get_first_node_in_group("Player")
	if p == _player:
		if p != null:
			_push_full()
		return
	if _player != null and is_instance_valid(_player):
		if _player.has_signal("health_changed") and _player.health_changed.is_connected(_on_health):
			_player.health_changed.disconnect(_on_health)
	_player = p
	if _player != null:
		if _player.has_signal("health_changed"):
			_player.health_changed.connect(_on_health)
		_push_full()


func _push_full() -> void:
	if _player == null:
		return
	_on_health(int(_player.get("hp")), int(_player.get("max_hp")))


func _on_health(hp: int, max_hp: int) -> void:
	while _slots.size() < max_hp:
		_box.add_child(_make_slot())
	for i in _slots.size():
		var s := _slots[i]
		s.modulate = Color.WHITE if i < hp else LOST
		s.scale = Vector2.ONE
	if _beat and _beat.is_valid():
		_beat.kill()
	_beat = null
	if hp <= 0 or hp > _slots.size():
		return
	var star := _slots[hp - 1]
	_beat = star.create_tween()
	_beat.set_loops()
	_beat.tween_property(star, "scale", Vector2.ONE * BEAT_SCALE, BEAT_TIME)
	_beat.tween_property(star, "scale", Vector2.ONE, BEAT_TIME)
