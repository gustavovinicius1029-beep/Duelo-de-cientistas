# CardDetailsPopup.gd
extends Control # Mantém a correção 'extends Control'

# --- REMOVIDA A VARIÁVEL 'is_pinned' ---

@onready var name_label = $NameLabel
@onready var type_label = $TypeLabel
@onready var cost_label = $CostLabel
@onready var attack_label = $AttackLabel
@onready var health_label = $HealthLabel
@onready var energy_gen_label = $EnergyGenLabel
@onready var attack_sprite = $Sprite2D
@onready var health_sprite = $Sprite2D2
@onready var scroll_sprite = $Sprite2D3
@onready var description_rich_text = $DescriptionRichText 
@onready var keyword_container = $PanelContainer/KeywordContainer

var card_database_ref = preload("res://scripts/card_database.gd")
const KEYWORD_POPUP_SCENE = preload("res://scenes/ui/KeywordPopup.tscn")

func _ready():
	hide_popup()
	pass

func show_popup(card_data: Dictionary):
	
	for child in keyword_container.get_children():
		child.queue_free()
	
	name_label.visible = false
	type_label.visible = false
	cost_label.visible = false
	attack_label.visible = false
	health_label.visible = false
	energy_gen_label.visible = false
	scroll_sprite.visible = true
	attack_sprite.visible = false
	health_sprite.visible = false
	description_rich_text.visible = false
	
	var card_keywords = card_data.get("keywords")
	if card_keywords: 
		print("recebi") # O print agora só acontece se a carta tiver keywords
		
		# Itera APENAS pelas keywords que esta carta possui
		for keyword in card_keywords:
			
			# Busca a descrição da keyword específica no banco de dados
			if card_database_ref.KEYWORD_DESCRIPTIONS.has(keyword):
				var rule_text = card_database_ref.KEYWORD_DESCRIPTIONS[keyword]
				
				# Instancia e mostra o popup
				var keyword_popup_instance = KEYWORD_POPUP_SCENE.instantiate()
				keyword_container.add_child(keyword_popup_instance)
				keyword_popup_instance.show_popup(keyword.capitalize(), rule_text)
			else:
				# Aviso caso a keyword da carta não exista no banco de dados
				print("Erro: A keyword '", keyword, "' não foi encontrada em KEYWORD_DESCRIPTIONS.")
			
	if card_data.has("name"):
		name_label.text = card_data.get("name", "N/A")
		name_label.visible = true
	var card_type = card_data.get("type", "")
	type_label.text = card_type.capitalize()
	type_label.visible = true
	if card_type == "Terreno":
		if card_data.has("energy_gen"):
			energy_gen_label.text = str(card_data.get("energy_gen", 0))
			energy_gen_label.visible = true
		if card_data.has("description"):
			_format_and_set_description(card_data.get("description", ""))
	elif card_type == "Criatura":
		attack_sprite.visible = true
		health_sprite.visible = true
		if card_data.has("cost"):
			cost_label.text = str(card_data.get("cost", 0))
			cost_label.visible = true
		if card_data.has("current_attack") and card_data.has("base_attack"):
			attack_label.text = str(card_data.get("current_attack", 0)) + "/" + str(card_data.get("base_attack", 0))
			attack_label.visible = true
		if card_data.has("current_health"):
			health_label.text = str(card_data.get("current_health", 0)) + "/" + str(card_data.get("base_health", 0))
			health_label.visible = true
		if card_data.has("description"):
			_format_and_set_description(card_data.get("description", ""))
	elif card_type == "feitiço":
		if card_data.has("cost"):
			cost_label.text = str(card_data.get("cost", 0))
			cost_label.visible = true
		if card_data.has("description"):
			_format_and_set_description(card_data.get("description", ""))

	await get_tree().process_frame
	self.visible = true

func hide_popup():
	self.visible = false
	for child in keyword_container.get_children():
		child.queue_free()

func _format_and_set_description(raw_desc: String):
	var formatted_desc = raw_desc
	for keyword in card_database_ref.KEYWORD_DESCRIPTIONS.keys():
		var styled_keyword = "[color=cyan][b]" + keyword.capitalize() + "[/b][/color]"
		formatted_desc = formatted_desc.replace(keyword, "[url="+keyword+"]" + styled_keyword + "[/url]")
	description_rich_text.text = formatted_desc
	description_rich_text.visible = true
