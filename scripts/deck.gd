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
	print("Deck do jogador ", get_parent().name, " sincronizado. Contagem: ", synced_deck_list.size())
	update_card_count_label()
	
@rpc("any_peer", "call_local")
func draw_card():
	print("RPC: Recebida ordem para comprar carta (Jogador ", get_parent().name, ").")
	if synced_deck_list.is_empty():
		print("Deck vazio, não pode comprar.")
		return
	var card_drawn_name = synced_deck_list.pop_front()
	_draw_card_action(card_drawn_name)

@rpc("any_peer", "call_local")
func rpc_perform_mulligan_draw(returned_card_names: Array):
	print("RPC: Jogador ", get_parent().name, " realizando Mulligan.") # ID adicionado
	if not is_instance_valid(player_hand_ref):
		printerr("Erro Mulligan Draw: Referência inválida para PlayerHand.")
		return
	for card_name in returned_card_names:
		synced_deck_list.append(card_name)
	print("Cartas devolvidas adicionadas ao fundo. Tamanho do deck: ", synced_deck_list.size())
	synced_deck_list.shuffle()
	print("Deck re-embaralhado.")
	# 3. Limpa a mão visualmente (os nós das cartas já foram removidos por return_hand_to_deck)
	# player_hand_ref.clear_hand_visuals() # Uma nova função talvez seja necessária em player_hand se return_hand_to_deck não limpar tudo
	var hand_size = returned_card_names.size() # Compra o mesmo número que devolveu
	print("Comprando nova mão de ", hand_size, " cartas.")
	if not is_multiplayer_authority():
		printerr("ERRO FATAL: Tentando executar rpc_perform_mulligan_draw sem autoridade!")
		return
	for i in range(hand_size):
		if synced_deck_list.is_empty():
			print("Deck acabou durante o Mulligan draw.")
			break
		var card_drawn_name = synced_deck_list.pop_front()
		_draw_card_action(card_drawn_name)
		await get_tree().create_timer(0.05).timeout
	print("Mulligan draw completo. Tamanho final do deck: ", synced_deck_list.size())
	update_card_count_label()

func _draw_card_action(card_drawn_name: String):
	var new_card = card_scene.instantiate()

	new_card.name = "Card_" + card_drawn_name.replace(" ", "_")
	new_card.card_name = card_drawn_name
	card_manager_ref.add_child(new_card) # Adiciona a carta à cena principal
	new_card.global_position = self.global_position

	# Configura os dados da carta
	var card_data = card_database_ref.CARDS[card_drawn_name]
	
	# Usando as novas chaves do dicionário
	new_card.attack = card_data["ataque"]
	new_card.base_health = card_data["vida"]
	new_card.current_health = card_data["vida"] # Vida atual começa igual à base
	new_card.description = card_data["desc"]
	new_card.card_type = card_data["tipo"]
	new_card.energy_cost = card_data["custo_energy"]
	new_card.energy_generation = card_data["gera_energy"]
	var ability_script_path = card_data["habilidade_path"]
	if ability_script_path != null:
		new_card.ability_script = load(ability_script_path).new()
	var card_image_path = card_data["art_path"]
	new_card.set_card_image_texture(card_image_path)
	new_card.card_data_ref = {
	"name": card_data["nome"],
	"attack": card_data["ataque"],
	"base_health": card_data["vida"],
	"current_health": card_data["vida"], # Inclui vida atual
	"description": card_data["desc"],
	"type": card_data["tipo"],
	"cost": card_data["custo_energy"],
	"energy_gen": card_data["gera_energy"]
	}

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
