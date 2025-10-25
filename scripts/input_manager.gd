extends Node2D

# Constantes das camadas (valores de MÁSCARA)
const COLLISION_MASK_CARD = 1           # Layer 1
const COLLISION_MASK_CARD_SLOT = 2      # Layer 2
const COLLISION_MASK_DECK = 4           # Layer 3
const COLLISION_MASK_OPPONENT_CARD = 8  # Layer 4

signal left_mouse_button_clicked()
signal left_mouse_button_released()

# 2. Definimos elas como variáveis normais
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
	# Garante que a máscara de busca inclui a camada do deck
	query.collision_mask = COLLISION_MASK_CARD | COLLISION_MASK_CARD_SLOT | COLLISION_MASK_DECK | COLLISION_MASK_OPPONENT_CARD

	var result = space_state.intersect_point(query)

	if not result.is_empty():
		var collider = result[0].collider # Esta é a Area2D
		var collider_parent = collider.get_parent() # Este é o nó principal (Deck, Card, OpponentCard)
		var result_collision_layer_mask = collider.collision_layer # Pega o VALOR DA MÁSCARA da camada do objeto clicado

		print("InputManager: Colisão detectada! Objeto: ", collider_parent.name, " | Camada (Máscara): ", result_collision_layer_mask)

		# Verifica Camada da Carta do Oponente (Máscara 8)
		if result_collision_layer_mask == COLLISION_MASK_OPPONENT_CARD:
			if is_instance_valid(collider_parent):
				print("InputManager: Clicou em CARTA DO OPONENTE.")
				battle_manager_ref.opponent_card_selected(collider_parent)
		
		# Verifica Camada da Carta do Jogador (Máscara 1)
		elif result_collision_layer_mask == COLLISION_MASK_CARD:
			if is_instance_valid(collider_parent):
				print("InputManager: Clicou em CARTA DO JOGADOR.")
				card_manager_ref.card_clicked(collider_parent)
		
		# Verifica Camada do Deck do Jogador (Máscara 4)
		elif result_collision_layer_mask == COLLISION_MASK_DECK:
			if collider_parent == deck_ref:
				print("InputManager: Clicou no DECK do Jogador.")
				
				# --- INÍCIO DA CORREÇÃO DE COMPRA MANUAL ---
				if deck_ref.drawn_card_this_turn:
					print("InputManager: Já comprou carta neste turno.")
				else:
					deck_ref.drawn_card_this_turn = true
					
					# 1. Diz ao NOSSO BattleManager para comprar NOSSA carta (local)
					battle_manager_ref.rpc_id(multiplayer.get_unique_id(), "rpc_draw_my_card")
					
					# 2. Encontra o ID e o caminho do BattleManager do OPONENTE
					var player_id = get_parent().name 
					var opponent_id_str = "2" if player_id == "1" else "1"
					var opponent_bm_path = "/root/Main/" + opponent_id_str + "/BattleManager"
					
					var opponent_peer_id = multiplayer_ref.opponent_peer_id
					
					# 3. Envia um RPC para o OPONENTE, dizendo a ele para comprar um "verso"
					multiplayer.rpc_id(opponent_peer_id, opponent_bm_path, "rpc_draw_opponent_card")
			else:
				print("InputManager: Colisão na camada DECK, mas não era o deck do jogador (era ", collider_parent.name, ")")
		
	else:
		print("InputManager: Clique no vazio.")
