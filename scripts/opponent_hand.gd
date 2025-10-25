extends Node2D

const CARD_SCENE_PATH = "res://scenes/opponent_card.tscn" # NOVO: Usa a cena de carta do oponente
var card_scene = preload(CARD_SCENE_PATH)

var card_manager_ref
var battle_manager_ref

const CARD_WIDTH = 120
const HAND_Y_POSITION = 30 # NOVO: Posição Y para a mão do oponente (acima dos slots)

const DEFAULT_CARD_MOVE_SPEED = 0.1

var center_screen_x: float
var opponent_hand: Array[Node2D] = [] # NOVO: Array para as cartas do oponente

func _ready() -> void:
	
	# 3. Espera um frame
	await get_tree().process_frame
	
	# 4. Encontra os nós
	# Este script está no "opponent_field"
	var parent_id = get_parent().name # O ID do campo do oponente ("1" ou "2")
	var player_id = "1" if parent_id == "2" else "2" # O ID do campo do jogador

	var player_path = "/root/Main/" + player_id # Caminho para os gerenciadores
	
	card_manager_ref = get_node(player_path + "/CardManager")
	battle_manager_ref = get_node(player_path + "/BattleManager")
	center_screen_x = get_viewport_rect().size.x / 2
# Adiciona uma carta ao array da mão do oponente
func add_card_to_hand(card: Node2D, speed: float = DEFAULT_CARD_MOVE_SPEED):
	if not opponent_hand.has(card):
		opponent_hand.append(card) # NOVO: Adiciona no final para que as cartas cresçam da direita para a esquerda
	
	update_hand_positions(speed)

# Remove uma carta do array da mão do oponente
func remove_card_from_hand(card: Node2D, speed: float = DEFAULT_CARD_MOVE_SPEED): # NOVO: Adiciona 'speed'
	if opponent_hand.has(card):
		opponent_hand.erase(card)
		update_hand_positions(speed) # Passa a velocidade

# Atualiza a posição de todas as cartas na mão do oponente
func update_hand_positions(speed: float = DEFAULT_CARD_MOVE_SPEED):
	for i in range(opponent_hand.size()):
		var card = opponent_hand[i]
		var new_position = calculate_card_position(i)
		animate_card_to_position(card, new_position, speed)
		
		# Não precisamos armazenar hand_position na carta do oponente, pois não há snap-back
		# card.hand_position = new_position # REMOVIDO

# Calcula a posição X e Y de uma carta na mão com base no seu índice (para o oponente)
func calculate_card_position(index: int) -> Vector2:
	var total_hand_width = (opponent_hand.size() - 1) * CARD_WIDTH
	# NOVO: Lógica invertida para que as cartas cresçam da direita para a esquerda
	var x_offset = center_screen_x - (index * CARD_WIDTH) + (total_hand_width / 2)
	return Vector2(x_offset, HAND_Y_POSITION)

func animate_card_to_position(card: Node2D, position: Vector2, speed: float = DEFAULT_CARD_MOVE_SPEED):
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", position, speed)
	
func remove_card_from_hand_by_rpc() -> Node2D:
	if not opponent_hand.is_empty():
		var card_to_remove = opponent_hand.pop_front() # Pega a primeira carta
		update_hand_positions(DEFAULT_CARD_MOVE_SPEED)
		return card_to_remove # RETORNA a carta
	return null # Retorna nulo se a mão estiver vazia
