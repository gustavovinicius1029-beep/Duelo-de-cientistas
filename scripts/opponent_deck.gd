extends Node2D

signal card_drawn(card: Node2D)

const CARD_SCENE_PATH = "res://scenes/opponent_card.tscn"
var card_scene = preload(CARD_SCENE_PATH)


# 1. Comentamos as referências @onready var de get_parent()
# @onready var opponent_hand_ref = get_parent().get_node("OpponentHand")
# @onready var card_manager_ref = get_parent().get_node("CardManager")
var opponent_hand_ref
var card_manager_ref

# 2. @onready vars locais (filhos) - ESTAS ESTÃO CORRETAS, não precisam mudar
@onready var deck_area_2d = $Area2D
@onready var card_count_label = $CardCountLabel
@onready var deck_image = $DeckImage

const CARD_DRAW_SPEED = 0.2
var synced_card_count: int = 0



# 3. Mude a assinatura da função para 'async'
func _ready():
	await get_tree().process_frame
	
	var parent_id = get_parent().name 
	var player_id = "1" if parent_id == "2" else "2"

	var opponent_path = "/root/Main/" + parent_id
	var player_path = "/root/Main/" + player_id
	
	opponent_hand_ref = get_node(opponent_path + "/OpponentHand")
	card_manager_ref = get_node(player_path + "/CardManager")
	
	set_process(false)


@rpc("any_peer", "call_local")
func set_card_count(count: int):
	synced_card_count = count
	print("Deck do oponente sincronizado. Contagem: ", synced_card_count)
	update_card_count_label()


@rpc("any_peer", "call_local")
func draw_card():
	print("RPC: Recebida ordem para comprar carta (Oponente).")
	if synced_card_count <= 0:
		return
	
	synced_card_count -= 1
	_draw_card_action()

func _draw_card_action():
	var new_card = card_scene.instantiate()

	new_card.name = "OpponentCard" # Nome genérico
	# Adiciona a carta à cena principal (gerenciada pelo CardManager do jogador local)
	if is_instance_valid(card_manager_ref):
		card_manager_ref.add_child(new_card)
	else:
		printerr("OpponentDeck: CardManager reference is invalid.")
		new_card.queue_free() # Limpa a carta se não puder adicioná-la
		return

	new_card.global_position = self.global_position

	# REMOVER: opponent_hand_ref.add_card_to_hand(new_card, CARD_DRAW_SPEED)
	# EMITIR SINAL: Notifica OpponentHand para pegar a carta
	emit_signal("card_drawn", new_card)

	update_card_count_label()

	if synced_card_count <= 0:
		if is_instance_valid(deck_area_2d):
			var shape = deck_area_2d.get_node_or_null("CollisionShape2D")
			if is_instance_valid(shape): shape.disabled = true

func update_card_count_label():
	if is_instance_valid(card_count_label):
		card_count_label.text = str(synced_card_count)
