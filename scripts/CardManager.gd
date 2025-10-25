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
var selected_monster: Node2D = null

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
		input_manager_ref.left_mouse_button_released.connect(_on_left_click_released)
		input_manager_ref.player_card_clicked.connect(_on_player_card_clicked)
	else:
		print("ERRO: InputManager não encontrado em CardManager.")
		
func _process(_delta):
	# Atualiza a posição da carta sendo arrastada
	if card_being_dragged:
		card_being_dragged.global_position = get_global_mouse_position()
	
	# Gerencia o estado visual de hover a cada frame
	update_hover_state()

# Inicia o processo de arrastar uma carta (geralmente da mão)
func start_drag(card_to_drag: Node2D):
	unselect_selected_monster() # Pode chamar unselect daqui
	card_being_hovered = null
	card_being_dragged = card_to_drag
	card_being_dragged.z_index = 10
	emit_signal("card_drag_started", card_to_drag) # Emite sinal

# Chamado quando o botão esquerdo do mouse é solto
func _on_left_click_released():
	if card_being_dragged:
		finish_drag()

# Finaliza o processo de arrastar e tenta jogar a carta
func finish_drag():
	var original_card = card_being_dragged
	var final_slot = null

	if card_being_dragged:
		# 1. Verifica Limite de Terreno
		if card_being_dragged.card_type == "Terreno" and battle_manager_ref.player_played_land_this_turn:
			player_hand_ref.add_card_to_hand(card_being_dragged, Constants.DEFAULT_CARD_MOVE_SPEED)
			# Sinal de fim ANTES de resetar
			emit_signal("card_drag_finished", original_card, null)
			card_being_dragged = null
			return

		# 2. Verifica Custo de Energia (Criaturas/Feitiços)
		if card_being_dragged.card_type != "Terreno":
			if card_being_dragged.energy_cost > battle_manager_ref.player_current_energy:
				player_hand_ref.add_card_to_hand(card_being_dragged, Constants.DEFAULT_CARD_MOVE_SPEED)
				# Sinal de fim ANTES de resetar
				emit_signal("card_drag_finished", original_card, null)
				card_being_dragged = null
				return

		# 3. Lógica específica para Feitiços
		if card_being_dragged.card_type == "feitiço":
			var spell_name = card_being_dragged.card_name
			var can_cast = true
			if spell_name == "A Peste":
				if not battle_manager_ref.check_plague_condition():
					can_cast = false

			if not can_cast:
				battle_manager_ref.animate_card_to_position_and_scale(card_being_dragged, card_being_dragged.hand_position, Constants.DEFAULT_CARD_SCALE, Constants.DEFAULT_CARD_MOVE_SPEED)
				# Sinal de fim ANTES de resetar
				emit_signal("card_drag_finished", original_card, null)
				card_being_dragged = null
				return

			# Se pode lançar o feitiço
			battle_manager_ref.player_current_energy -= card_being_dragged.energy_cost
			battle_manager_ref.update_energy_labels()
			player_hand_ref.remove_card_from_hand(card_being_dragged, Constants.DEFAULT_CARD_MOVE_SPEED)
			card_being_dragged.visible = false # Esconde carta temporariamente

			emit_signal("spell_cast_initiated", original_card) # Sinaliza que um feitiço começou

			# Não emite card_drag_finished aqui, o feitiço está em processo
			card_being_dragged = null
			return # Pula lógica de slot

		# 4. Procura slot válido (para Criaturas/Terrenos)
		var card_slot_found = raycast_check_for_card_slot()
		final_slot = card_slot_found # Guarda para o sinal final

		# 5. Verifica slot (vazio e tipo correto)
		if card_slot_found and not card_slot_found.card_in_slot and card_being_dragged.card_type == card_slot_found.card_slot_type:
			# Posiciona e dimensiona
			card_being_dragged.global_position = card_slot_found.global_position
			card_being_dragged.scale = Constants.CARD_SMALLER_SCALE
			card_being_dragged.z_index = -1

			# Reabilita colisão da carta
			var card_area = card_being_dragged.find_child("Area2D")
			if is_instance_valid(card_area):
				var shape = card_area.find_child("CollisionShape2D")
				if is_instance_valid(shape): shape.disabled = false

			# Desabilita colisão do SLOT
			var slot_area = card_slot_found.get_node_or_null("Area2D")
			if is_instance_valid(slot_area):
				var slot_shape = slot_area.get_node_or_null("CollisionShape2D")
				if is_instance_valid(slot_shape): slot_shape.disabled = true

			# Atualiza estado
			card_slot_found.card_in_slot = true
			card_being_dragged.card_slot_card_is_in = card_slot_found

			# Remove da mão visualmente
			player_hand_ref.remove_card_from_hand(card_being_dragged, Constants.DEFAULT_CARD_MOVE_SPEED)

			# Emite sinal indicando que a carta foi jogada com sucesso
			emit_signal("card_played", original_card)

			# Marca trava de turno no BattleManager (se for terreno)
			if card_being_dragged.card_type == "Terreno":
				battle_manager_ref.player_played_land_this_turn = true
		else:
			# Slot inválido ou ocupado, retorna para a mão
			player_hand_ref.add_card_to_hand(card_being_dragged, Constants.DEFAULT_CARD_MOVE_SPEED)

	# Emite o sinal de fim de drag (independente de sucesso ou falha ao jogar no slot)
	if is_instance_valid(original_card):
		emit_signal("card_drag_finished", original_card, final_slot)

	card_being_dragged = null # Garante que o estado de drag seja resetado
	
# Gerencia o efeito visual de hover
func update_hover_state():
	if card_being_dragged or selected_monster:
		if is_instance_valid(card_being_hovered):
			highlight_card(card_being_hovered, false)
			card_being_hovered = null
		return
		
	var card_under_mouse = raycast_check_for_card()

	if not card_under_mouse:
		if is_instance_valid(card_being_hovered):
			highlight_card(card_being_hovered, false)
			card_being_hovered = null
	else:
		if card_under_mouse != card_being_hovered:
			if is_instance_valid(card_being_hovered):
				highlight_card(card_being_hovered, false)
			highlight_card(card_under_mouse, true)
			card_being_hovered = card_under_mouse

# Aplica/Remove o efeito visual de hover
func highlight_card(card: Node2D, hovered: bool):
	if not is_instance_valid(card): return
	if card.has_method("get_defeated") and card.get_defeated(): return
	if card.card_slot_card_is_in != null and hovered: return
		
	if hovered:
		card.scale = Constants.CARD_BIGGER_SCALE
		card.z_index = 2
	else:
		card.scale = Constants.DEFAULT_CARD_SCALE
		card.z_index = 1

# Reseta apenas a seleção visual
func reset_turn_limits():
	unselect_selected_monster()

# Função principal chamada pelo InputManager quando uma carta do jogador é clicada
func _on_player_card_clicked(card: Node2D):
	if battle_manager_ref.player_is_targeting_spell:
		battle_manager_ref.player_card_selected_for_spell(card)
		return # Pula lógica de drag/ataque

	if battle_manager_ref.is_opponent_turn or battle_manager_ref.player_is_attacking:
		return

	if card.card_slot_card_is_in == null: # Carta na mão
		start_drag(card)
		return

	if card.card_slot_card_is_in != null: # Carta no campo
		if card.card_type != "Criatura" or battle_manager_ref.player_cards_that_attacked_this_turn.has(card):
			unselect_selected_monster()
			return

		# É uma criatura que pode atacar/ser selecionada
		if not battle_manager_ref.opponent_has_creatures(): # Ataque Direto
			unselect_selected_monster()

		else: # Seleção para atacar criatura
			if selected_monster == card:
				unselect_selected_monster()
			else:
				select_card_for_battle(card)
				
# Seleciona visualmente uma carta para atacar
func select_card_for_battle(card: Node2D):
	unselect_selected_monster() # Chama unselect antes de selecionar um novo
	selected_monster = card
	selected_monster.position.y -= 20
	emit_signal("card_selected_for_attack", selected_monster) # Emite sinal

# Remove a seleção visual da carta
func unselect_selected_monster():
	if is_instance_valid(selected_monster):
		var deselected_card = selected_monster
		selected_monster.position.y += 20
		selected_monster = null
		emit_signal("card_deselected_for_attack", deselected_card) # Emite sinal

# --- Funções de Raycast e Auxiliares ---

# Verifica se há uma CARTA DO JOGADOR sob o mouse
func raycast_check_for_card() -> Node2D:
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	query.collision_mask = Constants.COLLISION_LAYER_CARD | Constants.COLLISION_LAYER_SLOT | Constants.COLLISION_LAYER_DECK | Constants.COLLISION_LAYER_OPPONENT_CARD
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
	if cards.is_empty(): return null
	var highest_card: Node2D = null
	var highest_z = -INF
	for item in cards: 
		var c = item.collider
		if is_instance_valid(c): 
			var p = c.get_parent()
			if is_instance_valid(p) and p.z_index > highest_z: 
				highest_z = p.z_index
				highest_card = p
	return highest_card
