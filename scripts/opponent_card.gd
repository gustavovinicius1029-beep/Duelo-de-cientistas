extends Node2D

@onready var attribute1_label = $Attribute1 # Ataque
@onready var attribute2_label = $Attribute2 # Vida
@onready var cost_label = $CostLabel       # Custo
@onready var energy_gen_label = $EnergyGenLabel # NOVO: Geração
@onready var animation_player = $AnimationPlayer
@onready var card_image = $CardImage
@onready var attack_indicator: Sprite2D = $AttackIndicator
@onready var block_indicator: Sprite2D = $BlockIndicator


var card_type: String = ""
var card_name: String = ""
var attack: int = 0
var attack_value: int = 0 # Usado pela IA
var card_slot_card_is_in: Node2D = null
var defeated: bool = false
var energy_cost: int = 0
var energy_generation: int = 0
var base_health: int = 0  # NOVO: Vida base da carta
var current_health: int = 0 # NOVO: Vida atual
var plague_counters: int = 0 # NOVO: Marcadores de Peste


# Função atualizada para mostrar/esconder labels
func setup_card_display():
	# Quando a carta do oponente está virada para baixo, nada deve ser visível
	# Esta função será chamada APÓS a animação de virar, se aplicável
	if card_type == "Terreno":
		attribute1_label.visible = false
		attribute2_label.visible = false
		cost_label.visible = false
		energy_gen_label.visible = true
		energy_gen_label.text = "+" + str(energy_generation) + " E"
	elif card_type == "Criatura": # Criatura ou Magia (ajustar para Magia se necessário)
		attribute1_label.visible = true
		attribute2_label.visible = true
		cost_label.visible = false
		energy_gen_label.visible = false
		# Define os textos (eles são definidos no deck, mas garantimos aqui)
		attribute1_label.text = str(attack)
		attribute2_label.text = str(current_health)
	
	else:
		
		attribute1_label.visible = false
		attribute2_label.visible = false
		cost_label.visible = false
		energy_gen_label.visible = false


func set_card_image_texture(path: String):
	card_image.texture = load(path)

func set_defeated(status: bool):
	defeated = status

# Função auxiliar para obter o estado de derrota
func get_defeated() -> bool:
	return defeated
	
func add_plague_counter(amount: int):
	plague_counters += amount
	update_health_from_counters()
	
func update_health_from_counters():
	var health_reduction = plague_counters
	current_health = base_health - health_reduction
	
	if is_instance_valid(attribute2_label):
		attribute2_label.text = str(current_health)

	if current_health <= 0:
		defeated = true

func show_attack_indicator(visible: bool) -> void:
	if is_instance_valid(attack_indicator):
		attack_indicator.visible = visible

func show_block_indicator(visible: bool) -> void:
	if is_instance_valid(block_indicator):
		block_indicator.visible = visible

func hide_combat_indicators() -> void:
	show_attack_indicator(false)
	show_block_indicator(false)
