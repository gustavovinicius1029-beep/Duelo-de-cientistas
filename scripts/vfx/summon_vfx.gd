extends Sprite2D

# Duração total desejada (0.8s) / 60 frames = 0.0133s por frame
const FRAME_DURATION = 0.0133
const TOTAL_FRAMES = 60 # O número de frames que queremos tocar

func _ready():
	# Inicia a animação assim que a cena é instanciada
	play_animation()

func play_animation():
	# Garante que o sprite está visível
	self.visible = true
	
	# Loop de 0 a 59 (total de 60 frames)
	for i in range(TOTAL_FRAMES):
		# O Godot automaticamente calcula a posição na grade 8x8
		self.frame = i 
		
		# Cria um timer curto para esperar antes de mostrar o próximo frame
		await get_tree().create_timer(FRAME_DURATION).timeout
		
	# Quando a animação terminar, remove a cena da árvore
	queue_free()
