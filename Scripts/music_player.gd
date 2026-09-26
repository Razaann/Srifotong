extends AudioStreamPlayer
## Scene music node. Set stream + volume_db in the scene, it loops on ready.


func _ready() -> void:
	var s := stream as AudioStreamWAV
	if s != null:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	play()
