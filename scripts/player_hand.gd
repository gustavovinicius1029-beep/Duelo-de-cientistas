extends Node2D

var card_manager_ref
var battle_manager_ref
var cards_in_hand: Array = []

var center_screen_x: float

var deck_ref # Adicione se ainda não existir

func _ready(): # Ou func initialize_references():
	await get_tree().process_frame

	var parent_id = get_parent().name
	var player_path = "/root/Main/" + parent_id

	card_manager_ref = get_node(player_path + "/CardManager")
	battle_manager_ref = get_node(player_path + "/BattleManager")
	deck_ref = get_node(player_path + "/Deck") # Obter referência ao Deck

	center_screen_x = get_viewport_rect().size.x / 2

	# --- NOVAS CONEXÕES DE SINAL ---
	if is_instance_valid(deck_ref):
		deck_ref.card_drawn.connect(_on_card_drawn)
	else:
		print("ERRO (PlayerHand): Deck não encontrado.")

	if is_instance_valid(card_manager_ref):
		# Conecta ao sinal que indica que uma carta foi jogada com sucesso em um slot
		card_manager_ref.card_played.connect(_on_card_left_hand)
		# Conecta ao sinal que indica que um feitiço foi iniciado (e removido da mão visualmente)
		card_manager_ref.spell_cast_initiated.connect(_on_card_left_hand)
		# Conecta ao sinal de fim de drag para retornar a carta se falhar
		card_manager_ref.card_drag_finished.connect(_on_card_drag_finished)
	else:
		print("ERRO (PlayerHand): CardManager não encontrado.")

func _on_card_drawn(card: Node2D):

	var speed = Constants.CARD_DRAW_SPEED if Constants else 0.2 # Use constante global se configurada
	add_card_to_hand(card, speed)

func _on_card_left_hand(card: Node2D):
	remove_card_from_hand(card, 0)

	
func _on_card_drag_finished(card: Node2D, target_slot: Node2D):
	if not is_instance_valid(target_slot) and card.card_type != "feitiço" and cards_in_hand.has(card):
		update_hand_positions(Constants.DEFAULT_CARD_MOVE_SPEED if Constants else 0.1)
	elif not is_instance_valid(target_slot) and card.card_type != "feitiço" and not cards_in_hand.has(card):
		add_card_to_hand(card, Constants.DEFAULT_CARD_MOVE_SPEED if Constants else 0.1)
		
func add_card_to_hand(card: Node2D, speed: float = Constants.DEFAULT_CARD_MOVE_SPEED if Constants else 0.1):
	if not cards_in_hand.has(card):
		cards_in_hand.append(card)
	# Armazena a posição ideal na mão dentro da própria carta para o snap-back
	card.hand_position = calculate_card_position(cards_in_hand.find(card))
	update_hand_positions(speed) # Anima todas as cartas para suas novas posições

func remove_card_from_hand(card: Node2D, speed: float = Constants.DEFAULT_CARD_MOVE_SPEED if Constants else 0.1):
	if cards_in_hand.has(card):
		cards_in_hand.erase(card)
		# Não precisa animar a carta removida, apenas as restantes
		if speed > 0: # Só atualiza posições se não for remoção instantânea (speed 0)
			update_hand_positions(speed)

func update_hand_positions(speed: float = Constants.DEFAULT_CARD_MOVE_SPEED if Constants else 0.1):
	for i in range(cards_in_hand.size()):
		var card = cards_in_hand[i]
		var new_position = calculate_card_position(i)
		card.hand_position = new_position # Atualiza a posição ideal
		animate_card_to_position(card, new_position, speed)

func calculate_card_position(index: int) -> Vector2:
	var card_width = Constants.CARD_WIDTH if Constants else 120
	var hand_y = Constants.HAND_Y_POSITION_PLAYER if Constants else 930
	var total_hand_width = (cards_in_hand.size() - 1) * card_width
	var x_offset = center_screen_x - (index * card_width) + (total_hand_width / 2)
	return Vector2(x_offset, hand_y)

func animate_card_to_position(card: Node2D, position: Vector2, speed: float = Constants.DEFAULT_CARD_MOVE_SPEED if Constants else 0.1):
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", position, speed)
