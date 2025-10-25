extends Node2D

signal player_card_clicked(card: Node2D)
signal opponent_card_clicked(card: Node2D)
signal player_deck_clicked
signal empty_space_clicked

signal left_mouse_button_clicked()
signal left_mouse_button_released()

var card_manager_ref
var deck_ref
var battle_manager_ref
var multiplayer_ref

func _ready():
	
	await get_tree().process_frame
	
	# 3. NOVO: Encontramos os nós usando caminhos absolutos
	var player_id = get_parent().name 
	var player_path = "/root/Main/" + player_id
	
	card_manager_ref = get_node(player_path + "/CardManager")
	deck_ref = get_node(player_path + "/Deck")
	battle_manager_ref = get_node(player_path + "/BattleManager")
	multiplayer_ref = get_node("/root/Main")

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			emit_signal("left_mouse_button_clicked")
			raycast_at_cursor()
		else:
			emit_signal("left_mouse_button_released")

func raycast_at_cursor():
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	query.collision_mask = Constants.MASK_INPUT_CLICK

	var result = space_state.intersect_point(query)

	if not result.is_empty():
		var collider = result[0].collider # Esta é a Area2D
		var collider_parent = collider.get_parent() # Este é o nó principal (Deck, Card, OpponentCard)
		var result_collision_layer_mask = collider.collision_layer # Pega o VALOR DA MÁSCARA da camada do objeto clicado

		print("InputManager: Colisão detectada! Objeto: ", collider_parent.name, " | Camada (Máscara): ", result_collision_layer_mask) #

		# Verifica Camada da Carta do Oponente (Máscara 8)
		if result_collision_layer_mask == Constants.COLLISION_MASK_OPPONENT_CARD: #
			if is_instance_valid(collider_parent):
				print("InputManager: Clicou em CARTA DO OPONENTE.") #
				# REMOVER: battle_manager_ref.opponent_card_selected(collider_parent)
				emit_signal("opponent_card_clicked", collider_parent) # EMITIR SINAL

		# Verifica Camada da Carta do Jogador (Máscara 1)
		elif result_collision_layer_mask == Constants.COLLISION_MASK_CARD: #
			if is_instance_valid(collider_parent):
				print("InputManager: Clicou em CARTA DO JOGADOR.") #
				# REMOVER: card_manager_ref.card_clicked(collider_parent)
				emit_signal("player_card_clicked", collider_parent) # EMITIR SINAL

		# Verifica Camada do Deck do Jogador (Máscara 4)
		elif result_collision_layer_mask == Constants.COLLISION_MASK_DECK: #
			if collider_parent == deck_ref: #
				print("InputManager: Clicou no DECK do Jogador.") #
				emit_signal("player_deck_clicked") # EMITIR SINAL
			else:
				print("InputManager: Colisão na camada DECK, mas não era o deck do jogador (era ", collider_parent.name, ")") #

	else:
		print("InputManager: Clique no vazio.") #
		emit_signal("empty_space_clicked") # EMITIR SINAL (Opcional)
