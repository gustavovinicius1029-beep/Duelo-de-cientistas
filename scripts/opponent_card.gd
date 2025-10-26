extends Node2D

@onready var attribute1_label = $Attribute1 # Ataque
@onready var attribute2_label = $Attribute2 # Vida
@onready var cost_label = $CostLabel       # Custo
@onready var energy_gen_label = $EnergyGenLabel # NOVO: Geração
@onready var animation_player = $AnimationPlayer
@onready var card_image = $CardImage
@onready var attack_indicator: Sprite2D = $AttackIndicator
@onready var block_indicator: Sprite2D = $BlockIndicator
@onready var hover_timer = $HoverTimer
@onready var details_popup = $CardDetailsPopup

const HOVER_POPUP_OFFSET = Vector2(80, -120)
var card_data_ref: Dictionary = {} # Para guardar todos os dados da carta
var description: String = ""
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
var player_hand_ref
var opponent_hand_ref

func _ready() -> void:
	
	await get_tree().process_frame
	var player_id = get_parent().name 
	var player_path = "/root/Main/" + player_id
	opponent_hand_ref = get_node(player_path + "/OpponentHand")
	player_hand_ref = get_node(player_path + "/PlayerHand")
	if hover_timer:
		hover_timer.timeout.connect(_on_hover_timer_timeout)
	# Conectar mouse_entered/exited da Area2D se ainda não estiver conectado no editor
	var area = $Area2D
	if area and not area.is_connected("mouse_entered", Callable(self, "_on_area_2d_mouse_entered")):
		area.mouse_entered.connect(_on_area_2d_mouse_entered)
	if area and not area.is_connected("mouse_exited", Callable(self, "_on_area_2d_mouse_exited")):
		area.mouse_exited.connect(_on_area_2d_mouse_exited)

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

func show_attack_indicator(visible: bool) -> void:
	if is_instance_valid(attack_indicator):
		attack_indicator.visible = visible

func show_block_indicator(visible: bool) -> void:
	if is_instance_valid(block_indicator):
		block_indicator.visible = visible

func hide_combat_indicators() -> void:
	show_attack_indicator(false)
	show_block_indicator(false)
	
func _on_area_2d_mouse_entered():
	if card_slot_card_is_in != null or player_hand_ref.get_parent() or opponent_hand_ref.get_parent():
		if hover_timer:
			hover_timer.start()

func _on_area_2d_mouse_exited():
	if hover_timer:
		hover_timer.stop()
	if details_popup:
		details_popup.hide_popup()

func _on_hover_timer_timeout():
	if details_popup:
		card_data_ref["current_health"] = current_health
		details_popup.show_popup(card_data_ref)
		details_popup.global_position = global_position + HOVER_POPUP_OFFSET * scale # Ajusta pelo scale da carta

# Adicione esta função para atualizar os detalhes se a vida mudar enquanto o popup está visível
func update_details_popup_if_visible():
	if details_popup and details_popup.visible:
		card_data_ref["current_health"] = current_health
		details_popup.show_popup(card_data_ref) # Reaplica os dados

func update_health_from_counters():
	var health_reduction = plague_counters
	current_health = max(0, base_health - health_reduction)
	if is_instance_valid(attribute2_label):
		attribute2_label.text = str(current_health)
	if current_health <= 0:
		defeated = true
	update_details_popup_if_visible() # ATUALIZA O POPUP AQUI
