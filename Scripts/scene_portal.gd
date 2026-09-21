extends Area2D
class_name ScenePortal
## Portal pindah scene. Pasang di Area2D, isi target_scene di Inspector.
## Bekerja saat Player masuk ke area.

@export_file("*.tscn") var target_scene := ""

func _ready() -> void:
	body_entered.connect(_on_entered)

func _on_entered(body: Node2D) -> void:
	if body is Player and target_scene != "":
		get_tree().call_deferred("change_scene_to_file", target_scene)
