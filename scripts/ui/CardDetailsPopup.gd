# CardDetailsPopup.gd
extends Node2D

# Referências aos labels (ajuste os caminhos se sua estrutura for diferente)
@onready var name_label = $NameLabel
@onready var type_label = $TypeLabel
@onready var cost_label = $CostLabel
@onready var attack_label = $AttackLabel
@onready var health_label = $HealthLabel
@onready var energy_gen_label = $EnergyGenLabel
@onready var description_label = $DescriptionLabel
@onready var attack_sprite = $Sprite2D
@onready var health_sprite = $Sprite2D2
@onready var scroll_sprite = $Sprite2D3

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
	scroll_sprite.visible = true
	attack_sprite.visible = false
	health_sprite.visible = false
	

	if card_data.has("name"):
		name_label.text = card_data.get("name", "N/A") #.to_upper()
		name_label.visible = true

	# Popula e mostra baseado no tipo
	var card_type = card_data.get("type", "")
	type_label.text = card_type.capitalize()
	type_label.visible = true

	if card_type == "Terreno":
		if card_data.has("energy_gen"):
			energy_gen_label.text = str(card_data.get("energy_gen", 0))
			energy_gen_label.visible = true
		if card_data.has("description"):
			description_label.text = card_data.get("description", "")
			description_label.visible = true

	elif card_type == "Criatura":
		
		attack_sprite.visible = true
		health_sprite.visible = true
		
		if card_data.has("cost"):
			cost_label.text = str(card_data.get("cost", 0))
			cost_label.visible = true
		if card_data.has("attack"):
			print("tem vida")
			attack_label.text = str(card_data.get("attack", 0))
			attack_label.visible = true
		if card_data.has("current_health"):
			print("tem vida")
			health_label.text = str(card_data.get("current_health", 0)) + "/" + str(card_data.get("base_health", 0))
			health_label.visible = true
		if card_data.has("description"):
			description_label.text = card_data.get("description", "")
			description_label.visible = true

	elif card_type == "feitiço":
		if card_data.has("cost"):
			cost_label.text = str(card_data.get("cost", 0))
			cost_label.visible = true
		if card_data.has("description"):
			description_label.text = card_data.get("description", "")
			description_label.visible = true

	await get_tree().process_frame

	self.visible = true

func hide_popup():
	self.visible = false
