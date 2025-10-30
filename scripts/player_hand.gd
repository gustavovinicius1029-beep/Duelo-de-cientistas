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

func return_hand_to_deck() -> Array[String]:
	var card_names: Array[String] = []
	var cards_to_remove = cards_in_hand.duplicate()
	for card in cards_to_remove:
		if is_instance_valid(card):
			card_names.append(card.card_name)
			card.queue_free() # Remove o nó da carta da cena
		else:
			print("Aviso: Tentando retornar carta inválida da mão.") # Log de aviso
	cards_in_hand.clear() # Limpa o array de referências da mão
	print("Mão retornada ao deck. Nomes: ", card_names)
	return card_names

func _on_card_drawn(card: Node2D):
	var speed = Constants.CARD_DRAW_SPEED # Usar constante global
	add_card_to_hand(card, speed)

func _on_card_left_hand(card: Node2D):
	remove_card_from_hand(card, 0)

func _on_card_drag_finished(card: Node2D, target_slot: Node2D):
	if not is_instance_valid(target_slot) and card.card_type != "feitiço" and cards_in_hand.has(card):
		animate_card_to_position(card, card.hand_position, Constants.DEFAULT_CARD_MOVE_SPEED)
	elif not is_instance_valid(target_slot) and card.card_type != "feitiço" and not cards_in_hand.has(card):
		print("Aviso _on_card_drag_finished: Carta ", card.card_name, " retornando para a mão, mas não estava no array cards_in_hand.")
		add_card_to_hand(card, Constants.DEFAULT_CARD_MOVE_SPEED)
		
func add_card_to_hand(card: Node2D, speed: float = Constants.DEFAULT_CARD_MOVE_SPEED):
	if not cards_in_hand.has(card):
		cards_in_hand.append(card)
	var target_index = cards_in_hand.find(card)
	if target_index != -1: 
		card.hand_position = calculate_card_position(target_index)
		animate_card_to_position(card, card.hand_position, speed)
		update_hand_positions(speed, [card])

func remove_card_from_hand(card: Node2D, speed: float = Constants.DEFAULT_CARD_MOVE_SPEED):
	if cards_in_hand.has(card):
		cards_in_hand.erase(card)
		if speed > 0:
			update_hand_positions(speed)

func update_hand_positions(speed: float = Constants.DEFAULT_CARD_MOVE_SPEED, skip_cards: Array = []):
	for i in range(cards_in_hand.size()):
		var card = cards_in_hand[i]
		if card in skip_cards:
			continue
		var new_position = calculate_card_position(i)
		card.hand_position = new_position 
		animate_card_to_position(card, new_position, speed)

func calculate_card_position(index: int) -> Vector2:
	var card_width = Constants.CARD_WIDTH # Usar constante global
	var hand_y = Constants.HAND_Y_POSITION_PLAYER # Usar constante global
	var total_hand_width = (cards_in_hand.size() - 1) * card_width
	var card_width_effective = card_width
	if cards_in_hand.size() > 10: # Exemplo: mais de 10 cartas
		card_width_effective = card_width * 0.8
	total_hand_width = (cards_in_hand.size() - 1) * card_width_effective
	var start_x = center_screen_x - (total_hand_width / 2)
	var x_offset = start_x + (index * card_width_effective)
	return Vector2(x_offset, hand_y)

func animate_card_to_position(card: Node2D, position: Vector2, speed: float = Constants.DEFAULT_CARD_MOVE_SPEED):
	if not is_instance_valid(card): return
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", position, speed)
