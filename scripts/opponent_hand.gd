extends Node2D

const CARD_SCENE_PATH = "res://scenes/opponent_card.tscn" # NOVO: Usa a cena de carta do oponente
var card_scene = preload(CARD_SCENE_PATH)

var card_manager_ref
var battle_manager_ref

var center_screen_x: float
var opponent_hand: Array[Node2D] = [] # NOVO: Array para as cartas do oponente

var opponent_deck_ref # Adicione esta variável se não existir

func _ready() -> void:
	await get_tree().process_frame

	var parent_id = get_parent().name
	var player_id = "1" if parent_id == "2" else "2" # O ID do campo do jogador local

	var opponent_path = "/root/Main/" + parent_id # Caminho para o OpponentField
	var player_path = "/root/Main/" + player_id # Caminho para o PlayerField (onde estão os managers)

	# As referências aos managers são para o CardManager do jogador local,
	# pois é ele quem gerencia todas as cartas na cena.
	card_manager_ref = get_node(player_path + "/CardManager")
	battle_manager_ref = get_node(player_path + "/BattleManager")
	opponent_deck_ref = get_node(opponent_path + "/Deck") # Referência ao deck do oponente

	center_screen_x = get_viewport_rect().size.x / 2

	# --- NOVA CONEXÃO DE SINAL ---
	if is_instance_valid(opponent_deck_ref):
		opponent_deck_ref.card_drawn.connect(_on_opponent_card_drawn)
	else:
		printerr("OpponentHand: OpponentDeck não encontrado.")

func _on_opponent_card_drawn(card: Node2D):
	# Chamada quando OpponentDeck emite card_drawn
	# A carta já foi criada e adicionada à cena pelo OpponentDeck
	# Apenas adicionamos à lógica da mão e animamos
	var speed = Constants.CARD_DRAW_SPEED if Constants else 0.2
	add_card_to_hand(card, speed)

func add_card_to_hand(card: Node2D, speed: float = Constants.DEFAULT_CARD_MOVE_SPEED if Constants else 0.1):
	if not opponent_hand.has(card):
		opponent_hand.append(card)
	update_hand_positions(speed)

func remove_card_from_hand(card: Node2D, speed: float = Constants.DEFAULT_CARD_MOVE_SPEED if Constants else 0.1):
	if opponent_hand.has(card):
		opponent_hand.erase(card)
		if speed > 0: # Só atualiza se não for remoção instantânea (como no RPC)
			update_hand_positions(speed)

func update_hand_positions(speed: float = Constants.DEFAULT_CARD_MOVE_SPEED if Constants else 0.1):
	for i in range(opponent_hand.size()):
		var card = opponent_hand[i]
		var new_position = calculate_card_position(i)
		animate_card_to_position(card, new_position, speed)

func calculate_card_position(index: int) -> Vector2:
	var card_width = Constants.CARD_WIDTH if Constants else 120
	var hand_y = Constants.HAND_Y_POSITION_OPPONENT if Constants else 30
	var total_hand_width = (opponent_hand.size() - 1) * card_width
	var x_offset = center_screen_x - (index * card_width) + (total_hand_width / 2)
	return Vector2(x_offset, hand_y)

func animate_card_to_position(card: Node2D, position: Vector2, speed: float = Constants.DEFAULT_CARD_MOVE_SPEED if Constants else 0.1):
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", position, speed)

func remove_card_from_hand_by_rpc() -> Node2D:
	# Esta função é chamada via RPC pelo BattleManager quando o oponente joga uma carta
	if not opponent_hand.is_empty():
		var card_to_remove = opponent_hand.pop_front() # Pega a primeira (FIFO visual)
		remove_card_from_hand(card_to_remove, 0) # Remove da lógica instantaneamente
		update_hand_positions(Constants.DEFAULT_CARD_MOVE_SPEED if Constants else 0.1) # Atualiza posições das restantes
		return card_to_remove # Retorna a carta removida para o BattleManager animar
	return null
