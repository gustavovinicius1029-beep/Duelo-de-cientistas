extends Node2D

signal card_played(card: Node2D)
signal spell_cast_initiated(spell_card: Node2D)
signal card_selected_for_attack(card: Node2D)
signal card_deselected_for_attack(card: Node2D)
signal card_drag_started(card: Node2D)
signal card_drag_finished(card: Node2D, target_slot: Node2D) 

var screen_size: Vector2
var card_being_dragged: Node2D = null
var card_being_hovered: Node2D = null

# 2. Definimos elas como variáveis normais
var player_hand_ref
var input_manager_ref
var deck_ref
var battle_manager_ref

# --- Constantes (sem mudança) ---
#var selected_monster: Node2D = null
var selected_attackers: Array[Node2D] = []

func _ready():
	await get_tree().process_frame

	var player_id = get_parent().name
	var player_path = "/root/Main/" + player_id

	player_hand_ref = get_node(player_path + "/PlayerHand")
	input_manager_ref = get_node(player_path + "/InputManager") # Referência necessária para conectar
	deck_ref = get_node(player_path + "/Deck")
	battle_manager_ref = get_node(player_path + "/BattleManager")

	screen_size = get_viewport_rect().size

	# Conecta aos sinais do Input Manager
	if is_instance_valid(input_manager_ref):
		input_manager_ref.left_mouse_button_clicked.connect(_on_left_mouse_button_clicked)
		input_manager_ref.left_mouse_button_released.connect(_on_left_mouse_button_released)
		input_manager_ref.player_card_clicked.connect(_on_player_card_clicked)
	else:
		print("CardManager: InputManager não encontrado em " + player_path)
		
func _process(_delta):
	if card_being_dragged:
		card_being_dragged.global_position = get_global_mouse_position()
	update_hover_state()

func _on_left_mouse_button_clicked():
	pass

func _on_left_mouse_button_released():
	if is_instance_valid(card_being_dragged):
		end_drag()

func update_hover_state():
	# Se estiver arrastando ou uma carta já estiver selecionada para ataque, limpe o hover e saia.
	if card_being_dragged or selected_attackers:
		if is_instance_valid(card_being_hovered):
			highlight_card(card_being_hovered, false) # Remove highlight anterior
			card_being_hovered = null
		return

	# Verifica qual nó (Carta, Deck, etc.) está sob o mouse
	var node_under_mouse = raycast_check_for_interactable() # Usaremos uma função auxiliar mais robusta
	# Se não há nada interativo sob o mouse
	if not is_instance_valid(node_under_mouse):
		if is_instance_valid(card_being_hovered):
			highlight_card(card_being_hovered, false) # Remove highlight anterior
			card_being_hovered = null
	# Se o nó sob o mouse É UMA CARTA (verificamos se tem o script de carta ou uma propriedade específica)
	elif node_under_mouse.has_method("get_defeated"): # 'get_defeated' existe em card.gd e opponent_card.gd
		if node_under_mouse != card_being_hovered: # Se é uma *nova* carta sob o mouse
			if is_instance_valid(card_being_hovered):
				highlight_card(card_being_hovered, false) # Remove highlight anterior
			highlight_card(node_under_mouse, true) # Aplica highlight na nova
			card_being_hovered = node_under_mouse
	# Se o nó sob o mouse NÃO É UMA CARTA (ex: é o Deck)
	else:
		if is_instance_valid(card_being_hovered): # Se havia uma carta com highlight
			highlight_card(card_being_hovered, false) # Remove o highlight dela
			card_being_hovered = null

func raycast_check_for_interactable() -> Node2D:
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	# Define a máscara para colidir com cartas E decks
	query.collision_mask = Constants.COLLISION_LAYER_CARD | Constants.COLLISION_LAYER_DECK | Constants.COLLISION_LAYER_OPPONENT_CARD
	var result = space.intersect_point(query)

	if not result.is_empty():
		# Pega o nó pai (Card, Deck, OpponentCard) da Area2D com maior Z-index
		var highest_node: Node2D = null
		var highest_z = -INF
		for item in result:
			var collider = item.collider
			if is_instance_valid(collider):
				var parent_node = collider.get_parent()
				# Certifica-se que é um Node2D antes de checar z_index
				if is_instance_valid(parent_node) and parent_node is Node2D and parent_node.z_index >= highest_z:
					highest_z = parent_node.z_index
					highest_node = parent_node
		return highest_node
	return null

func highlight_card(card: Node2D, hovered: bool):
	if not is_instance_valid(card): return
	if not card.has_method("get_defeated") or not card.has_node("HoverTimer") or not card.has_node("CardDetailsPopup"):
		return
	if card.get_defeated(): return # Não faz nada se derrotada
	var is_in_slot = card.card_slot_card_is_in != null
	if hovered:
		if not is_in_slot:
			card.scale = Constants.CARD_BIGGER_SCALE
			card.z_index = 5 # Traz BEM para frente para garantir visibilidade
		else:
			pass
		if is_instance_valid(card.hover_timer):
			card.hover_timer.start()
	else: 
		if is_instance_valid(card.hover_timer):
			card.hover_timer.stop()
		if is_instance_valid(card.details_popup):
			card.details_popup.hide_popup()
		if not is_in_slot:
			card.scale = Constants.DEFAULT_CARD_SCALE
			card.z_index = 1 # Retorna ao normal

func reset_turn_limits():
	clear_attacker_selection()

# Função principal chamada pelo InputManager quando uma carta do jogador é clicada
# Em scripts/CardManager.gd

# Em CardManager.gd
# Conectado ao sinal 'player_card_clicked' do InputManager
func _on_player_card_clicked(card: Node2D):
	if not is_instance_valid(card) or not is_instance_valid(battle_manager_ref):
		return

	var bm = battle_manager_ref

	# --- 1. LÓGICA DE PRIORIDADE (A VERIFICAÇÃO PRINCIPAL) ---
	# Cenário 1: É o nosso turno, não estamos esperando o oponente.
	var can_play_on_own_turn = not bm.is_opponent_turn and not bm.opponent_is_waiting_for_pass
	
	# Cenário 2: Temos prioridade (respondendo) E a carta é uma instantânea.
	var can_play_as_instant = bm.waiting_for_player_response and \
							  card.card_type == "Magia Instantânea"

	# Se não pudermos jogar em nenhum dos cenários, verificamos se é um clique de ataque
	if not (can_play_on_own_turn or can_play_as_instant):
		
		# Exceção: Clicar para atacar (Isso é permitido)
		if bm.current_combat_phase == bm.CombatPhase.DECLARE_ATTACKERS and \
			not bm.is_opponent_turn and card.card_type == "Criatura":
			toggle_attacker(card) # Permite selecionar atacante
			return
		
		# Se não for um clique de ataque, bloqueia a ação.
		print("Não pode jogar agora. TurnoOp: %s, EsperandoOponente: %s, EsperandoNossaResp: %s" % [bm.is_opponent_turn, bm.opponent_is_waiting_for_pass, bm.waiting_for_player_response])
		return
	# --- FIM DA LÓGICA DE PRIORIDADE ---

	# --- 2. LÓGICA DE AÇÃO (SE A VERIFICAÇÃO ACIMA PASSAR) ---

	# Lógica de Ataque (Se a verificação passou, mas estamos na fase de ataque)
	if bm.current_combat_phase == bm.CombatPhase.DECLARE_ATTACKERS and \
	   not bm.is_opponent_turn and card.card_type == "Criatura" and \
	   not bm.player_cards_that_attacked_this_turn.has(card):
		toggle_attacker(card)
		return

	# Lógica de Drag de Magias (feitiço OU Magia Instantânea)
	if card.card_type == "feitiço" or card.card_type == "Magia Instantânea":
		# (A checagem de custo e turno será feita no try_play_spell_no_slot ao soltar)
		start_drag(card)
		return
	
	# Lógica de Drag de Criatura/Terreno
	if card.card_type == "Terreno" or card.card_type == "Criatura":
		# (A checagem de turno/fase será feita no try_play_card_on_slot ao soltar)
		if bm.is_opponent_turn: return # Segurança (já verificado, mas bom ter)
		if bm.current_combat_phase == bm.CombatPhase.NONE:
			start_drag(card)
			return

func start_drag(card: Node2D):
	if card_being_dragged or not is_instance_valid(card):
		return
	if is_instance_valid(player_hand_ref):
		player_hand_ref.remove_card_from_hand(card, 0)
	card_being_dragged = card
	card_being_dragged.z_index = 100 # Garante que a carta fique no topo
	emit_signal("card_drag_started", card)

func end_drag():
	var card = card_being_dragged
	if not is_instance_valid(card):
		return

	var target_slot = raycast_check_for_card_slot()
	var success = false

	# Se a carta for um feitiço ou magia, não precisa de slot
	if card.card_type == "feitiço" or card.card_type == "Magia Instantânea":
		success = try_play_spell_no_slot(card)
	# Se for criatura ou terreno, precisa de slot
	elif is_instance_valid(target_slot):
		success = try_play_card_on_slot(card, target_slot)

	if success:
		card_being_dragged = null
		if card.card_type == "Criatura" or card.card_type == "Terreno":
			if is_instance_valid(target_slot):
				card.global_position = target_slot.global_position
				card.scale = Constants.CARD_SMALLER_SCALE #
				card.z_index = -1
		# O BattleManager ou PlayerHand cuidará de mover/deletar a carta
	else:
		# Retorna a carta para a mão
		if is_instance_valid(player_hand_ref):
			player_hand_ref.add_card_to_hand(card)
		card_being_dragged.z_index = 1 # Retorna ao Z-index normal
		card_being_dragged = null

	emit_signal("card_drag_finished", card, target_slot if success else null)
	
func try_play_card_on_slot(card: Node2D, slot: Node2D) -> bool:
	if not is_instance_valid(card) or not is_instance_valid(slot):
		return false
		
	var bm = battle_manager_ref
	if not is_instance_valid(bm): return false
	
	# --- LÓGICA DE PRIORIDADE ATUALIZADA ---
	# Criaturas e Terrenos SÓ podem ser jogados no nosso turno,
	# sem prioridade pendente e fora de combate.
	if bm.is_opponent_turn or bm.opponent_is_waiting_for_pass:
		print("Não pode jogar Criatura/Terreno no turno do oponente ou esperando resposta.")
		return false
	if bm.current_combat_phase != bm.CombatPhase.NONE:
		print("Não pode jogar Criatura/Terreno durante o combate.")
		return false
	# --- FIM DA LÓGICA ---

	# (Resto da lógica original de custo, tipo de slot, etc.)
	if bm.player_current_energy < card.energy_cost:
		print("Energia insuficiente.")
		return false
		
	if (card.card_type == "Criatura" and slot.card_slot_type != "Criatura") or \
	   (card.card_type == "Terreno" and slot.card_slot_type != "Terreno"):
		print("Tipo de carta e slot incompatíveis.")
		return false
		
	if card.card_type == "Terreno" and bm.player_played_land_this_turn:
		print("Já jogou terreno neste turno.")
		return false
		
	bm.player_current_energy -= card.energy_cost
	if card.card_type == "Terreno":
		bm.player_played_land_this_turn = true
	
	# Atualiza energia visualmente (função do battle_manager)
	bm.update_energy_labels() 
	
	slot.card_in_slot = true
	card.card_slot_card_is_in = slot
	
	emit_signal("card_played", card)
	return true
	
func try_play_spell_no_slot(card: Node2D) -> bool:
	if not is_instance_valid(card) or not is_instance_valid(battle_manager_ref):
		return false

	var bm = battle_manager_ref

	# Checagem de Custo
	if bm.player_current_energy < card.energy_cost:
		print("Energia insuficiente.")
		return false
	
	# --- LÓGICA DE PRIORIDADE ATUALIZADA ---
	if card.card_type == "feitiço":
		# Feitiços: Só no nosso turno, sem esperar resposta, fora de combate
		if bm.is_opponent_turn or bm.opponent_is_waiting_for_pass:
			print("Feitiços só podem ser jogados no seu turno, sem esperar resposta.")
			return false
		if bm.current_combat_phase != bm.CombatPhase.NONE:
			print("Feitiços não podem ser jogados durante o combate.")
			return false
		# Se for nosso turno e não estivermos esperando, OK
	
	elif card.card_type == "Magia Instantânea":
		# Instantâneas: (Nosso turno E sem esperar) OU (Temos prioridade)
		var can_play_on_own_turn = not bm.is_opponent_turn and not bm.opponent_is_waiting_for_pass
		var can_play_as_instant = bm.waiting_for_player_response

		if not (can_play_on_own_turn or can_play_as_instant):
			print("Não é o momento de jogar uma instantânea.")
			return false
		# Se for nosso turno (e não esperando) OU se tivermos prioridade, OK
	
	else:
		return false # Não é um tipo de magia
	# --- FIM DA LÓGICA ---

	# Se passou, gasta energia e emite o sinal
	bm.player_current_energy -= card.energy_cost
	bm.update_energy_labels()
	emit_signal("spell_cast_initiated", card)
	return true
	
func toggle_attacker(card: Node2D):
	if selected_attackers.has(card):
		selected_attackers.erase(card)
		card.show_attack_indicator(false)
		emit_signal("card_deselected_for_attack", card)
	else:
		selected_attackers.append(card)
		card.show_attack_indicator(true)
		emit_signal("card_selected_for_attack", card)

func clear_attacker_selection():
	for card in selected_attackers:
		if is_instance_valid(card):
			card.show_attack_indicator(false)
	selected_attackers.clear()
	
# Verifica se há uma CARTA DO JOGADOR sob o mouse
func raycast_check_for_card() -> Node2D:
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	query.collision_mask = Constants.COLLISION_LAYER_CARD # Apenas cartas do jogador
	var result = space.intersect_point(query)
	if !result.is_empty():
		return get_card_with_highest_z_index(result)
	return null
	
# Verifica se há um SLOT DO JOGADOR sob o mouse
func raycast_check_for_card_slot() -> Node2D:
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	query.collision_mask = Constants.COLLISION_MASK_CARD_SLOT
	var result = space.intersect_point(query)
	if !result.is_empty(): 
		var c = result[0].collider
		if is_instance_valid(c):
			return c.get_parent()
	return null
	
# Retorna a carta com o maior Z-Index de uma lista de resultados de colisão
func get_card_with_highest_z_index(cards: Array) -> Node2D:
	var highest_z_index = -INF
	var top_card: Node2D = null
	for item in cards:
		var collider = item.collider
		if is_instance_valid(collider):
			var card = collider.get_parent() # Assume que o 'collider' é filho da 'card'
			if is_instance_valid(card) and card.is_in_group("Card"): # Assegure-se que suas cartas tenham o grupo "Card"
				if card.z_index > highest_z_index:
					highest_z_index = card.z_index
					top_card = card
	return top_card
