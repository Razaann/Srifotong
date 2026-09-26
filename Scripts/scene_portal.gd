extends Area2D
class_name ScenePortal
## Portal pindah scene. Pasang di Area2D, isi target_scene di Inspector.
## Bekerja saat Player masuk ke area.

@export_file("*.tscn") var target_scene := ""
@export var white_flash := false ## white cover instead of black (forest entry)
@export var flash_text := "" ## shown centered while covered, e.g. "Kamu Sudah Terpilih"

func _ready() -> void:
	body_entered.connect(_on_entered)

func _on_entered(body: Node2D) -> void:
	if body is Player and target_scene != "":
		var flash := Color(1, 1, 1, 1) if white_flash else Color(0, 0, 0, 1)
		SceneTransition.change_scene(target_scene, flash, flash_text)
