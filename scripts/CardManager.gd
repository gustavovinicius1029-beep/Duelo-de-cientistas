extends Node2D

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_CARD_SLOT = 2
const COLLISION_MASK_DECK = 4

var screen_size: Vector2
var card_being_dragged: Node2D = null
var card_being_hovered: Node2D = null

# 2. Definimos elas como variáveis normais
var player_hand_ref
var input_manager_ref
var deck_ref
var battle_manager_ref

# --- Constantes (sem mudança) ---
const DEFAULT_CARD_MOVE_SPEED = 0.1
const DEFAULT_CARD_SCALE = Vector2(0.6, 0.6)
const CARD_BIGGER_SCALE = Vector2(0.75, 0.75)
const CARD_SMALLER_SCALE = Vector2(0.6, 0.6)

var selected_monster: Node2D = null

func _ready():
	
	await get_tree().process_frame
	
	# 3. NOVO: Encontramos os nós usando caminhos absolutos
	var player_id = get_parent().name 
	var player_path = "/root/Main/" + player_id
	
	player_hand_ref = get_node(player_path + "/PlayerHand")
	input_manager_ref = get_node(player_path + "/InputManager")
	deck_ref = get_node(player_path + "/Deck")
	battle_manager_ref = get_node(player_path + "/BattleManager")
	
	# --- Lógica original do _ready() (agora podemos usá-la) ---
	screen_size = get_viewport_rect().size
	# Conecta ao sinal do InputManager para saber quando o botão do mouse é solto
	input_manager_ref.connect("left_mouse_button_released", _on_left_click_released)
	
func _process(_delta):
	# Atualiza a posição da carta sendo arrastada
	if card_being_dragged:
		card_being_dragged.global_position = get_global_mouse_position()
	
	# Gerencia o estado visual de hover a cada frame
	update_hover_state()

# Inicia o processo de arrastar uma carta (geralmente da mão)
func start_drag(card_to_drag: Node2D):
	unselect_selected_monster()
	card_being_hovered = null
	card_being_dragged = card_to_drag
	card_being_dragged.z_index = 10

# Chamado quando o botão esquerdo do mouse é solto
func _on_left_click_released():
	if card_being_dragged:
		finish_drag()

# Finaliza o processo de arrastar e tenta jogar a carta
func finish_drag():
	if card_being_dragged:
		# 1. Verifica Limite de Terreno
		if card_being_dragged.card_type == "Terreno" and battle_manager_ref.player_played_land_this_turn:
			# print("CardManager: Já jogou um terreno neste turno!") # Print removido
			player_hand_ref.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
			card_being_dragged = null
			return

		# 2. Verifica Custo de Energia
		if card_being_dragged.card_type != "Terreno":
			if card_being_dragged.energy_cost > battle_manager_ref.player_current_energy:
				# print("CardManager: Energia insuficiente!") # Print removido
				player_hand_ref.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
				card_being_dragged = null
				return
		
		if card_being_dragged.card_type == "feitiço":
			var spell_name = card_being_dragged.card_name
			
			# 1. Checagem de Custo de Energia (genérico)
			if card_being_dragged.energy_cost > battle_manager_ref.player_current_energy:
				print("CardManager: Energia insuficiente para o feitiço.")
				battle_manager_ref.animate_card_to_position_and_scale(card_being_dragged, card_being_dragged.hand_position, DEFAULT_CARD_SCALE, DEFAULT_CARD_MOVE_SPEED)
				card_being_dragged = null
				return

			# 2. Checagem de Condição de Lançamento (específico)
			var can_cast = true
			if spell_name == "A Peste":
				if not battle_manager_ref.check_plague_condition():
					print("Condição não atendida: 'A Peste' requer um Rato ou marcador Peste.")
					can_cast = false
			# (Adicione mais 'elif' aqui para outros feitiços com condições)
			
			if not can_cast:
				battle_manager_ref.animate_card_to_position_and_scale(card_being_dragged, card_being_dragged.hand_position, DEFAULT_CARD_SCALE, DEFAULT_CARD_MOVE_SPEED)
				card_being_dragged = null
				return
			
			# 3. Se passou em tudo, Pague o custo e Execute
			print("CardManager: Processando feitiço: ", spell_name)
			battle_manager_ref.player_current_energy -= card_being_dragged.energy_cost
			battle_manager_ref.update_energy_labels()
			
			# 4. Remove a carta da mão e a coloca no "limbo"
			# Fazemos isso para feitiços com alvo E sem alvo
			player_hand_ref.remove_card_from_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
			card_being_dragged.visible = false # Esconde a carta
			
			# 5. Determina se o feitiço tem alvo ou é global
			if spell_name == "Início da Peste":
				print("Iniciando modo de targeting (alvo único).")
				var restrictions = {"type": "Criatura"}
				battle_manager_ref.setup_targeting_state(card_being_dragged, 1, restrictions, true)
			
			elif spell_name == "Surto da Peste":
				print("Iniciando modo de targeting (múltiplos alvos).")
				var restrictions = {"type": "Criatura", "max_health": 2}
				battle_manager_ref.setup_targeting_state(card_being_dragged, 2, restrictions, true)
			
			elif spell_name == "A Peste":
				var player_id = get_parent().name 
				var opponent_id_str = "2" if player_id == "1" else "1"
				var opponent_bm_path = "/root/Main/" + opponent_id_str + "/BattleManager"
				var opponent_bm = get_node_or_null(opponent_bm_path)
				var multiplayer_ref = get_node("/root/Main") 
				var opponent_peer_id = multiplayer_ref.opponent_peer_id
				
				# 2. Enviar RPC para o oponente executar o feitiço
				if is_instance_valid(opponent_bm):
					opponent_bm.rpc_id(opponent_peer_id, "rpc_opponent_cast_global_spell", "A Peste")

				# 3. Este feitiço é GLOBAL e resolve imediatamente (localmente)
				print("Lançando feitiço global 'A Peste'.")
				if card_being_dragged.ability_script != null:
					# Chama a habilidade e ESPERA (await) ela terminar
					# 4. Passa "Jogador" como o dono (caster)
					await card_being_dragged.ability_script.trigger_ability(battle_manager_ref, card_being_dragged, "Jogador")
				else:
					print("ERRO: 'A Peste' sem ability_script!")
			
			else:
				print("ERRO: Feitiço desconhecido: ", spell_name)
				# (Opcional: Reembolsar energia e devolver para a mão)

			# 6. Limpa o estado de arrastar
			card_being_dragged = null 
			return # Importante: Pula o resto da função de slot
		
		# 3. Procura slot válido
		var card_slot_found = raycast_check_for_card_slot()
		
		# 4. Verifica slot (vazio e tipo correto)
		if card_slot_found and not card_slot_found.card_in_slot and card_being_dragged.card_type == card_slot_found.card_slot_type:
			
			# Consome energia (se não for terreno)
				
			# Posiciona e dimensiona
			card_being_dragged.global_position = card_slot_found.global_position
			card_being_dragged.scale = CARD_SMALLER_SCALE
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
			
			# Remove da mão e adiciona ao campo
			player_hand_ref.remove_card_from_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
			battle_manager_ref.add_player_card_to_battlefield(card_being_dragged) # Notifica BM
			
			# Marca as travas de turno NO BATTLEMANAGER
			# REMOVIDO: if card_being_dragged.card_type == "Criatura": battle_manager_ref.player_played_creature_this_turn = true
			if card_being_dragged.card_type == "Terreno":
				battle_manager_ref.player_played_land_this_turn = true
		else:
			# print("CardManager: Slot inválido ou ocupado.") # Print removido
			player_hand_ref.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED) 

		card_being_dragged = null
	
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
		card.scale = CARD_BIGGER_SCALE
		card.z_index = 2
	else:
		card.scale = DEFAULT_CARD_SCALE
		card.z_index = 1

# Reseta apenas a seleção visual
func reset_turn_limits():
	unselect_selected_monster()

# Função principal chamada pelo InputManager quando uma carta do jogador é clicada
func card_clicked(card: Node2D):
	
	if battle_manager_ref.player_is_targeting_spell:
		battle_manager_ref.player_card_selected_for_spell(card)
		return # Pula a lógica de ataque
	
	if battle_manager_ref.is_opponent_turn or battle_manager_ref.player_is_attacking: return

	if card.card_slot_card_is_in == null: # Carta na mão
		start_drag(card)
		return

	if card.card_slot_card_is_in != null: # Carta no campo
		if card.card_type != "Criatura" or battle_manager_ref.player_cards_that_attacked_this_turn.has(card):
			unselect_selected_monster()
			return


		if not battle_manager_ref.opponent_has_creatures(): # Ataque Direto
			
			
			# 1. Encontrar índice do atacante
			var attacker_slot_node = card.card_slot_card_is_in
			var attacker_slot_index = battle_manager_ref.player_creature_slots_ref.find(attacker_slot_node)
			
			if attacker_slot_index == -1:
				print("ERRO: Não foi possível encontrar o índice de slot para o ataque direto.")
				unselect_selected_monster()
				return

			# 2. Encontrar o BattleManager do oponente e o peer_id
			var player_id = get_parent().name 
			var opponent_id_str = "2" if player_id == "1" else "1"
			var opponent_bm_path = "/root/Main/" + opponent_id_str + "/BattleManager"
			var opponent_bm = get_node_or_null(opponent_bm_path)
			var multiplayer_ref = get_node("/root/Main") 
			var opponent_peer_id = multiplayer_ref.opponent_peer_id
			
			# 3. Enviar RPC para o oponente
			if is_instance_valid(opponent_bm):
				# J2 (oponente) receberá (índice_atacante_J1)
				opponent_bm.rpc_id(opponent_peer_id, "rpc_receive_direct_attack", attacker_slot_index)
				
			# 4. Executar o ataque localmente
			unselect_selected_monster()
			await battle_manager_ref.direct_attack(card, "Jogador")
		
		
		else: # Seleção para atacar criatura
			if selected_monster == card:
				unselect_selected_monster()
			else:
				select_card_for_battle(card)

# Seleciona visualmente uma carta para atacar
func select_card_for_battle(card: Node2D):
	unselect_selected_monster()
	selected_monster = card
	selected_monster.position.y -= 20 # Move para cima

# Remove a seleção visual da carta
func unselect_selected_monster():
	if is_instance_valid(selected_monster):
		selected_monster.position.y += 20 # Move para baixo
		selected_monster = null

# --- Funções de Raycast e Auxiliares ---

# Verifica se há uma CARTA DO JOGADOR sob o mouse
func raycast_check_for_card() -> Node2D:
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	query.collision_mask = COLLISION_MASK_CARD
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
	query.collision_mask = COLLISION_MASK_CARD_SLOT
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
