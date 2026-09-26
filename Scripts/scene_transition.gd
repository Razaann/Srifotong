extends CanvasLayer
## Global scene fade. Every scene starts with fade-out from black (0.5s);
## change_scene() fades in to black (0.5s), switches, then fades out.
## Combined: 1s full transition. Works for portals and death reloads alike
## (any scene change auto fades out via tree_changed).

const FADE_TIME := 0.5

var _rect: ColorRect
var _label: Label
var _tween: Tween
var _busy := false


func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 1)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_font_override("font", load("res://Asset/m6x11.ttf") as Font)
	_label.add_theme_font_size_override("font_size", 16)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.modulate.a = 0.0
	add_child(_label)
	get_tree().tree_changed.connect(_on_tree_changed)
	fade_out()


func _input(event: InputEvent) -> void:
	# Panic reset: R reloads the scene even if player input is stuck.
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func change_scene(path: String, flash := Color(0, 0, 0, 1), text := "") -> void:
	if _busy or path == "":
		return
	_busy = true
	_set_flash(flash, text)
	await _fade_cover(1.0)
	get_tree().call_deferred("change_scene_to_file", path)
	await get_tree().tree_changed
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_cover(0.0)
	_busy = false


func fade_out() -> void:
	await _fade_to(0.0)


func _on_tree_changed() -> void:
	# Any scene change NOT initiated here (e.g. death reload) still fades out.
	if _busy:
		return
	fade_out()


func _fade_to(alpha: float) -> void:
	_set_flash(Color(0, 0, 0, 1), "")
	await _fade_cover(alpha)


func _set_flash(flash: Color, text: String) -> void:
	_rect.color = Color(flash.r, flash.g, flash.b, _rect.color.a)
	_label.text = text
	# Dark text on light flash, white text on dark flash.
	var lum := (flash.r + flash.g + flash.b) / 3.0
	_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.2) if lum > 0.5 else Color.WHITE)


func _fade_cover(alpha: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_rect, "color:a", alpha, FADE_TIME)
	_tween.tween_property(_label, "modulate:a", alpha if _label.text != "" else 0.0, FADE_TIME)
	await _tween.finished
