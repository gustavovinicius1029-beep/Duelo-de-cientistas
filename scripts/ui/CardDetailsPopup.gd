# CardDetailsPopup.gd
extends PanelContainer

# Referências aos labels (ajuste os caminhos se sua estrutura for diferente)
@onready var name_label = $MarginContainer/VBoxContainer/NameLabel
@onready var type_label = $MarginContainer/VBoxContainer/CostLabel
@onready var cost_label = $MarginContainer/VBoxContainer/TypeLabel
@onready var attack_label = $MarginContainer/VBoxContainer/AttackLabel
@onready var health_label = $MarginContainer/VBoxContainer/HealthLabel
@onready var energy_gen_label = $MarginContainer/VBoxContainer/EnergyGenLabel
@onready var description_label = $MarginContainer/VBoxContainer/DescriptionLabel

func _ready():
	hide_popup()

func show_popup(card_data: Dictionary):

	name_label.visible = false
	type_label.visible = false
	cost_label.visible = false
	attack_label.visible = false
	health_label.visible = false
	energy_gen_label.visible = false
	description_label.visible = false

	if card_data.has("name"):
		name_label.text = "[center][b]" + card_data.get("name", "N/A") + "[/b][/center]"
		name_label.visible = true

	# Popula e mostra baseado no tipo
	var card_type = card_data.get("type", "")
	type_label.text = "Tipo: " + card_type.capitalize()
	type_label.visible = true

	if card_type == "Terreno":
		if card_data.has("energy_gen"):
			energy_gen_label.text = "Gera: +" + str(card_data.get("energy_gen", 0)) + " Energia"
			energy_gen_label.visible = true
		if card_data.has("description"):
			description_label.text = "Descrição: " + card_data.get("description", "")
			description_label.visible = true

	elif card_type == "Criatura":
		if card_data.has("cost"):
			cost_label.text = "Custo: " + str(card_data.get("cost", 0))
			cost_label.visible = true
		if card_data.has("attack"):
			attack_label.text = "Ataque: " + str(card_data.get("attack", 0))
			attack_label.visible = true
		if card_data.has("health"):
			# Mostra vida atual / base
			health_label.text = "Vida: " + str(card_data.get("current_health", 0)) + "/" + str(card_data.get("base_health", 0))
			health_label.visible = true
		if card_data.has("description"):
			description_label.text = "Descrição: " + card_data.get("description", "")
			description_label.visible = true

	elif card_type == "feitiço":
		if card_data.has("cost"):
			cost_label.text = "Custo: " + str(card_data.get("cost", 0))
			cost_label.visible = true
		if card_data.has("description"):
			description_label.text = "Descrição: " + card_data.get("description", "")
			description_label.visible = true

	# Ajusta o tamanho mínimo para caber o conteúdo
	custom_minimum_size = Vector2.ZERO # Reseta para recalcular
	await get_tree().process_frame # Espera o texto ser renderizado
	custom_minimum_size = get_minimum_size() # Pega o tamanho necessário

	self.visible = true

func hide_popup():
	self.visible = false
