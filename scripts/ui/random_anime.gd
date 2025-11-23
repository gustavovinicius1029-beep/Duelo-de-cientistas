extends AnimatedSprite2D

func _ready():
	play() 
	var frame_count = sprite_frames.get_frame_count(animation)
	if frame_count > 0:
		frame = randi() % frame_count
