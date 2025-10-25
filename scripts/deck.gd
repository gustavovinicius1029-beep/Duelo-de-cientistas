extends Node2D

signal card_drawn(card: Node2D)

const CARD_SCENE_PATH = "res://scenes/card.tscn"
var card_scene = preload(CARD_SCENE_PATH)

var card_database_ref = preload("res://scripts/card_database.gd")
var card_manager_ref

# 2. @onready vars locais (filhos) - ESTAS ESTÃO CORRETAS, não precisam mudar
@onready var deck_area_2d = $Area2D
@onready var card_count_label = $CardCountLabel
@onready var deck_image = $DeckImage

var synced_deck_list: Array[String] = []
var player_hand_ref
var drawn_card_this_turn: bool = false

func _ready():
	
	await get_tree().process_frame
	
	# 3. NOVO: Encontramos os nós usando caminhos absolutos
	var player_id = get_parent().name 
	var player_path = "/root/Main/" + player_id
	
	player_hand_ref = get_node(player_path + "/PlayerHand")
	card_manager_ref = get_node(player_path + "/CardManager")
	

@rpc("any_peer", "call_local")
func set_deck_list(list: Array):
	synced_deck_list = list
	print("Deck do jogador sincronizado. Contagem: ", synced_deck_list.size())
	update_card_count_label()
	
@rpc("any_peer", "call_local")
func draw_card():
	print("RPC: Recebida ordem para comprar carta (Jogador).")
	if synced_deck_list.is_empty():
		return
	var card_drawn_name = synced_deck_list.pop_front()
	_draw_card_action(card_drawn_name)

func _draw_card_action(card_drawn_name: String):
	var new_card = card_scene.instantiate()

	new_card.name = "Card_" + card_drawn_name.replace(" ", "_")
	new_card.card_name = card_drawn_name
	card_manager_ref.add_child(new_card) # Adiciona a carta à cena principal
	new_card.global_position = self.global_position

	# Configura os dados da carta
	var card_data = card_database_ref.CARDS[card_drawn_name]
	new_card.attack = card_data[0]
	new_card.base_health = card_data[1]
	new_card.current_health = card_data[1]
	new_card.card_type = card_data[3]
	new_card.energy_cost = card_data[4]
	new_card.energy_generation = card_data[5]

	var ability_script_path = card_data[6]
	if ability_script_path != null:
		new_card.ability_script = load(ability_script_path).new()

	var card_image_path = card_database_ref.CARD_IMAGE_PATHS[card_drawn_name]
	new_card.set_card_image_texture(card_image_path)

	# Inicia animação e espera terminar antes de emitir o sinal
	new_card.animation_player.play("card_flip")
	await new_card.animation_player.animation_finished
	new_card.setup_card_display()

	# REMOVER: player_hand_ref.add_card_to_hand(new_card, CARD_DRAW_SPEED)
	# EMITIR SINAL: Notifica que a carta foi comprada e está pronta
	emit_signal("card_drawn", new_card)

	update_card_count_label()

	# Lógica para desabilitar colisão do deck vazio permanece
	if synced_deck_list.is_empty():
		if is_instance_valid(deck_area_2d):
			var shape = deck_area_2d.get_node_or_null("CollisionShape2D")
			if is_instance_valid(shape): shape.disabled = true

func update_card_count_label():
	if is_instance_valid(card_count_label):
		card_count_label.text = str(synced_deck_list.size())

func reset_draw():
	drawn_card_this_turn = false
