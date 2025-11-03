extends AnimatedSprite2D

func _ready():
	# Garante que a animação "play" toque assim que a cena for instanciada
	play("play")
	#animation_finished.connect(_on_animation_finished)

func _on_animation_finished():
	queue_free()
