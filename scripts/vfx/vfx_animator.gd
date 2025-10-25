extends Sprite2D

# Configurações que vamos ajustar no Inspetor do Godot
@export var total_frames: int = 16
@export var frame_duration: float = 0.015 # 0.04s é rápido e impactante

func _ready():
	# Centraliza a animação
	self.centered = true
	# Inicia a animação assim que a cena é instanciada
	play_animation()

func play_animation():
	self.visible = true
	
	for i in range(total_frames):
		self.frame = i
		await get_tree().create_timer(frame_duration).timeout
		
	# Quando a animação terminar, remove a cena da árvore
	queue_free()
