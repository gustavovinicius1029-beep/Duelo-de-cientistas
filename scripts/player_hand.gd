extends Node2D

var card_manager_ref
var battle_manager_ref
var cards_in_hand: Array = []
const CARD_WIDTH = 120
const HAND_Y_POSITION = 930 # Posição Y para a mão do oponente
const DEFAULT_CARD_MOVE_SPEED = 0.1

var center_screen_x: float

func _ready():
	
	await get_tree().process_frame
	
	# 4. Encontra os nós
	# Este script está no "player_field"
	var parent_id = get_parent().name # O ID do nosso campo ("1" ou "2")
	var player_path = "/root/Main/" + parent_id # Caminho para os gerenciadores
	
	card_manager_ref = get_node(player_path + "/CardManager")
	battle_manager_ref = get_node(player_path + "/BattleManager")
	
	center_screen_x = get_viewport_rect().size.x / 2

func add_card_to_hand(card: Node2D, speed: float = DEFAULT_CARD_MOVE_SPEED):
	if not cards_in_hand.has(card):
		cards_in_hand.append(card)
	update_hand_positions(speed)

func remove_card_from_hand(card: Node2D, speed: float = DEFAULT_CARD_MOVE_SPEED):
	if cards_in_hand.has(card):
		cards_in_hand.erase(card)
		update_hand_positions(speed)

func update_hand_positions(speed: float = DEFAULT_CARD_MOVE_SPEED):
	for i in range(cards_in_hand.size()):
		var card = cards_in_hand[i]
		var new_position = calculate_card_position(i)
		animate_card_to_position(card, new_position, speed)

func calculate_card_position(index: int) -> Vector2:
	var total_hand_width = (cards_in_hand.size() - 1) * CARD_WIDTH
	# Lógica invertida para que a mão cresça da direita para a esquerda
	var x_offset = center_screen_x - (index * CARD_WIDTH) + (total_hand_width / 2)
	return Vector2(x_offset, HAND_Y_POSITION)

func animate_card_to_position(card: Node2D, position: Vector2, speed: float = DEFAULT_CARD_MOVE_SPEED):
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", position, speed)
