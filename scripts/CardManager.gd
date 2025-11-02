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
var player_hand_ref
var input_manager_ref
var deck_ref
var battle_manager_ref
var selected_attackers: Array[Node2D] = []

var card_clicked_for_drag: Node2D = null 
var click_start_position: Vector2 = Vector2.ZERO 
const DRAG_START_THRESHOLD = 10.0

func _ready():
	await get_tree().process_frame

	var player_id = get_parent().name
	var player_path = "/root/Main/" + player_id
	player_hand_ref = get_node(player_path + "/PlayerHand")
	input_manager_ref = get_node(player_path + "/InputManager")
	deck_ref = get_node(player_path + "/Deck")
	battle_manager_ref = get_node(player_path + "/BattleManager")
	screen_size = get_viewport_rect().size
	if is_instance_valid(input_manager_ref):
		input_manager_ref.left_mouse_button_released.connect(_on_left_click_released)
		input_manager_ref.player_card_clicked.connect(_on_player_card_clicked)
	else:
		print("ERRO: InputManager não encontrado em CardManager.")
		
func _process(_delta):
	if is_instance_valid(card_clicked_for_drag) and card_being_dragged == null:
		if get_global_mouse_position().distance_to(click_start_position) > DRAG_START_THRESHOLD:
			start_drag(card_clicked_for_drag)
			card_clicked_for_drag = null
	if card_being_dragged:
		card_being_dragged.details_popup.hide_popup()
		card_being_dragged.global_position = get_global_mouse_position()
	update_hover_state()

func start_drag(card_to_drag: Node2D):
	if "is_in_viewer_mode" in card_to_drag and card_to_drag.is_in_viewer_mode:
		return
	clear_attacker_selection()
	card_being_hovered = null
	card_clicked_for_drag = null
	card_being_dragged = card_to_drag
	card_being_dragged.z_index = 10
	emit_signal("card_drag_started", card_to_drag)

func clear_attacker_selection():
	# Remove indicadores visuais e limpa a lista
	for attacker in selected_attackers:
		if is_instance_valid(attacker):
			attacker.show_attack_indicator(false)
			attacker.position.y += 20 # Move de volta se você moveu ao selecionar
	selected_attackers.clear()

func _on_left_click_released():
	if is_instance_valid(card_being_dragged):
		finish_drag()
	card_clicked_for_drag = null

# Finaliza o processo de arrastar e tenta jogar a carta
func finish_drag():
	var original_card = card_being_dragged
	var final_slot = null
	if card_being_dragged:
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

			if card_being_dragged.card_type == "Criatura": # Certifique-se que é uma criatura
				battle_manager_ref.player_current_energy -= card_being_dragged.energy_cost # Deduz a energia
				battle_manager_ref.update_energy_labels() # Atualiza o label imediatamente
				card_being_dragged.set_has_summoning_sickness(true)
			# --- FIM DA CORREÇÃO ---

			# Emite sinal indicando que a carta foi jogada com sucesso
			emit_signal("card_played", original_card) #

			# Marca trava de turno no BattleManager (se for terreno)
			if card_being_dragged.card_type == "Terreno": #
				battle_manager_ref.player_played_land_this_turn = true #
		else:
			# Slot inválido ou ocupado, retorna para a mão
			player_hand_ref.add_card_to_hand(card_being_dragged, Constants.DEFAULT_CARD_MOVE_SPEED) #

	# Emite o sinal de fim de drag (independente de sucesso ou falha ao jogar no slot)
	if is_instance_valid(original_card):
		emit_signal("card_drag_finished", original_card, final_slot) #

	card_being_dragged = null
	
# Gerencia o efeito visual de hover
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
	if "is_in_viewer_mode" in card and card.is_in_viewer_mode:
		return
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

func _on_player_card_clicked(card: Node2D):
	
	# --- LÓGICA REESTRUTURADA ---

	# 1. Checagem de modo visualizador (cemitério) - Sempre primeiro
	if "is_in_viewer_mode" in card and card.is_in_viewer_mode:
		return

	# 2. Checagem de Jogo (Mulligan) - Sempre segundo
	var multiplayer_node = get_node_or_null("/root/Main")
	if not is_instance_valid(multiplayer_node) or not multiplayer_node.game_started:
		print("Aguardando início do jogo (Mulligan). Clique na carta bloqueado.")
		return
		
	# 3. Lógica de "Fixar" (Pinning) - LOCAL
	# Verificamos se a carta está no campo
	if card.card_slot_card_is_in != null:
		if not is_instance_valid(battle_manager_ref) or \
		   battle_manager_ref.current_combat_phase != battle_manager_ref.CombatPhase.DECLARE_ATTACKERS:
			return # Esta era a ação do clique. Fim.
			
	# 4. Checagem de Turno/Animação - BLOQUEIA AÇÕES DE JOGO
	# Se chegamos aqui, não foi um clique para "fixar".
	# Agora verificamos se podemos fazer ações de jogo (atacar, arrastar).
	if not is_instance_valid(battle_manager_ref) or battle_manager_ref.is_opponent_turn or battle_manager_ref.player_is_attacking:
		# Isto agora bloqueia corretamente o Client de arrastar ou atacar,
		# mas permite que ele "fixe" (passo 3).
		return
		
	# 5. Checagem de Fase: Declarar Atacantes (Ação de Jogo)
	if battle_manager_ref.current_combat_phase == battle_manager_ref.CombatPhase.DECLARE_ATTACKERS:
		if card.card_slot_card_is_in != null and card.card_type == "Criatura" \
		and not battle_manager_ref.player_cards_that_attacked_this_turn.has(card) \
		and not card.has_summoning_sickness:

			if selected_attackers.has(card):
				selected_attackers.erase(card)
				if card.has_method("show_attack_indicator"): card.show_attack_indicator(false)
				card.position.y += 20
			else:
				selected_attackers.append(card)
				if card.has_method("show_attack_indicator"): card.show_attack_indicator(true)
				card.position.y -= 20 
		return # Impede de arrastar durante esta fase

	# 6. Checagem de Fase: Clicar na Mão (Ação de Jogo)
	if card.card_slot_card_is_in == null and battle_manager_ref.current_combat_phase == battle_manager_ref.CombatPhase.NONE:
		card_clicked_for_drag = card
		click_start_position = get_global_mouse_position()
		return

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
	if cards.is_empty(): return null
	var highest_card: Node2D = null
	var highest_z = -INF
	for item in cards:
		var c = item.collider
		if is_instance_valid(c):
			var p = c.get_parent()
			if is_instance_valid(p) and p is Node2D and p.z_index > highest_z:
				highest_z = p.z_index
				highest_card = p
	return highest_card
		
