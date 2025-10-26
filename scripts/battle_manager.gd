extends Node

signal combat_phase_changed(new_phase: CombatPhase)

var phase_button
var battle_timer
var opponent_deck
var opponent_hand
var player_deck
var card_manager
var player_health_label
var opponent_health_label
var player_discard
var opponent_discard
var player_energy_label
var opponent_energy_label
var confirm_action_button
var player_slots_container
var input_manager_ref
var combat_line_drawer_ref: Node2D

const CARD_SCENE_PATH = "res://scenes/card.tscn"
var card_scene = preload(CARD_SCENE_PATH)
const SUMMON_VFX_SCENE = preload("res://scenes/vfx/summon_vfx.tscn")
const DESTROY_VFX = preload("res://scenes/vfx/destroy_vfx.tscn")
const NORMAL_ATTACK_VFX = preload("res://scenes/vfx/normal_attack_vfx.tscn")
const HEAVY_ATTACK_VFX = preload("res://scenes/vfx/heavy_attack_vfx.tscn")

var card_database_ref = preload("res://scripts/card_database.gd")

var player_health: int = Constants.INITIAL_PLAYER_HEALTH
var opponent_health: int = Constants.INITIAL_PLAYER_HEALTH
var player_max_energy: int = 1 # Removido? Usando player_lands_in_play
var player_current_energy: int = 1
var opponent_max_energy: int = 1 # Removido? Usando opponent_lands_in_play
var opponent_current_energy: int = 1
var turns: int = 0

var player_lands_in_play: int = 0
var opponent_lands_in_play: int = 0

var player_played_land_this_turn: bool = false
var opponent_played_land_this_turn: bool = false

var player_cards_on_battlefield: Array = []
var opponent_cards_on_battlefield: Array = []
var player_cards_that_attacked_this_turn: Array = []
var opponent_land_slots_ref: Array = [] # Populado no _ready

var player_creature_slots_ref: Array = []
var player_land_slots_ref: Array = []
var opponent_creature_slots_ref: Array = []

var is_opponent_turn: bool = false
var player_is_attacking: bool = false # Flag para animações de ataque/dano

var player_is_targeting_spell: bool = false
var spell_being_cast: Node2D = null
var current_spell_max_targets: int = 0
var current_spell_target_count: int = 0
var current_spell_targets: Array = []
var current_spell_target_restrictions: Dictionary = {}

enum CombatPhase { NONE, BEGIN_COMBAT, DECLARE_ATTACKERS, DECLARE_BLOCKERS, COMBAT_DAMAGE, END_COMBAT }
var current_combat_phase: CombatPhase = CombatPhase.NONE:
	set(new_phase):
		if current_combat_phase != new_phase:
			current_combat_phase = new_phase
			emit_signal("combat_phase_changed", current_combat_phase)
			update_ui_for_phase()
	get:
		return current_combat_phase

var declared_attackers: Array[Node2D] = []
var declared_blockers: Dictionary = {}
var blocker_assignments: Dictionary = {}
var currently_selected_blocker: Node2D = null

# --- Funções de Ciclo de Vida e Inicialização ---

func _ready():
	await get_tree().process_frame

	if not get_parent().is_multiplayer_authority():
		return

	var player_id = get_parent().name
	var opponent_id = "2" if player_id == "1" else "1"
	var opponent_path = "/root/Main/" + opponent_id
	var local_parent = get_parent()

	combat_line_drawer_ref = local_parent.get_node("CombatLineDrawer")
	phase_button = local_parent.get_node("PhaseButton") # !! RENOMEIE NA CENA para "PhaseButton" !!
	battle_timer = local_parent.get_node_or_null("BattleTimer")
	player_deck = local_parent.get_node("Deck")
	card_manager = local_parent.get_node("CardManager")
	player_health_label = local_parent.get_node("PlayerHealthLabel")
	player_discard = local_parent.get_node("PlayerDiscard")
	player_energy_label = local_parent.get_node("PlayerEnergyLabel")
	confirm_action_button = local_parent.get_node("ConfirmActionButton") # !! RENOMEIE NA CENA para "ConfirmActionButton" !!
	player_slots_container = local_parent.get_node("PlayerCardSlots")
	input_manager_ref = local_parent.get_node("InputManager")

	opponent_deck = get_node(opponent_path + "/Deck")
	opponent_hand = get_node(opponent_path + "/OpponentHand")
	opponent_health_label = get_node(opponent_path + "/OpponentHealthLabel")
	opponent_discard = get_node(opponent_path + "/OpponentDiscard")
	opponent_energy_label = get_node(opponent_path + "/OpponentEnergyLabel")

	update_health_labels()
	update_energy_labels()

	if is_instance_valid(phase_button):
		phase_button.pressed.connect(_on_phase_button_pressed)
	if is_instance_valid(confirm_action_button):
		confirm_action_button.pressed.connect(_on_confirm_action_button_pressed)

	if is_instance_valid(card_manager):
		card_manager.card_played.connect(_on_card_played)
		card_manager.spell_cast_initiated.connect(_on_spell_cast_initiated)
	else:
		printerr("BattleManager: CardManager não encontrado.")

	if is_instance_valid(input_manager_ref):
		input_manager_ref.opponent_card_clicked.connect(_on_opponent_card_clicked)
		input_manager_ref.player_card_clicked.connect(_on_player_card_clicked) # Conexão adicionada
		input_manager_ref.player_deck_clicked.connect(_on_player_deck_clicked)
	else:
		printerr("BattleManager: InputManager não encontrado.")

	if is_instance_valid(opponent_deck):
		opponent_deck.set_process(false)

	for i in range(player_slots_container.get_child_count()):
		var slot = player_slots_container.get_child(i)
		if slot.card_slot_type == "Criatura":
			player_creature_slots_ref.append(slot)
		else:
			player_land_slots_ref.append(slot)

	var opponent_slots_container = get_node_or_null(opponent_path + "/OpponentCardSlots")
	if is_instance_valid(opponent_slots_container):
		for i in range(opponent_slots_container.get_child_count()):
			var slot = opponent_slots_container.get_child(i)
			if slot.card_slot_type == "Criatura":
				opponent_creature_slots_ref.append(slot)
			else:
				opponent_land_slots_ref.append(slot)
	else:
		printerr("BattleManager: OpponentCardSlots não encontrado.")

	update_ui_for_phase()

func set_current_combat_phase(new_phase: CombatPhase) -> void:
	if current_combat_phase != new_phase:
		current_combat_phase = new_phase
		emit_signal("combat_phase_changed", current_combat_phase)
		update_ui_for_phase()

# --- Handlers de Sinais ---

func _on_card_played(card: Node2D):
	player_cards_on_battlefield.append(card)
	var slot_index = -1
	var card_type = card.card_type

	if card_type == "Criatura":
		slot_index = player_creature_slots_ref.find(card.card_slot_card_is_in)
	elif card_type == "Terreno":
		slot_index = player_land_slots_ref.find(card.card_slot_card_is_in)
		player_lands_in_play += card.energy_generation
		update_energy_labels()

	if slot_index != -1:
		var opponent_bm = get_opponent_battle_manager()
		var opponent_peer_id = get_opponent_peer_id()
		if is_instance_valid(opponent_bm) and opponent_peer_id != 0:
			opponent_bm.rpc_id(opponent_peer_id, "rpc_opponent_played_card", card.card_name, card_type, slot_index)
		else:
			printerr("ERRO (_on_card_played): Oponente BM ou Peer ID inválido.")

func _on_spell_cast_initiated(spell_card: Node2D):
	var spell_name = spell_card.card_name

	if spell_name == "Início da Peste":
		var restrictions = {"type": "Criatura"}
		setup_targeting_state(spell_card, 1, restrictions, false)
	elif spell_name == "Surto da Peste":
		var restrictions = {"type": "Criatura", "max_health": 2}
		setup_targeting_state(spell_card, 2, restrictions, true)
	elif spell_name == "A Peste":
		var opponent_bm = get_opponent_battle_manager()
		var opponent_peer_id = get_opponent_peer_id()
		if is_instance_valid(opponent_bm) and opponent_peer_id != 0:
			opponent_bm.rpc_id(opponent_peer_id, "rpc_opponent_cast_global_spell", "A Peste")
		if spell_card.ability_script != null:
			await spell_card.ability_script.trigger_ability(self, spell_card, "Jogador")
		else:
			printerr("ERRO: 'A Peste' sem ability_script!")
		reset_targeting_state()
	else:
		printerr("ERRO: Feitiço desconhecido iniciado: ", spell_name)
		if is_instance_valid(spell_card): spell_card.queue_free()
		reset_targeting_state()

func _on_player_card_clicked(card: Node2D):
	if current_combat_phase == CombatPhase.DECLARE_BLOCKERS and is_instance_valid(card) and player_cards_on_battlefield.has(card):
		if is_opponent_turn:
			handle_blocker_declaration_click(card)
			return 
	if not is_opponent_turn and player_is_targeting_spell:
		handle_spell_target_selection(card)
		return
	if is_opponent_turn:
		return

# Em scripts/battle_manager.gd

func _on_opponent_card_clicked(card: Node2D):
	if current_combat_phase == CombatPhase.DECLARE_BLOCKERS and is_instance_valid(card) and opponent_cards_on_battlefield.has(card):
		if is_opponent_turn: 
			handle_blocker_declaration_click(card)
			return
	if not is_opponent_turn and player_is_targeting_spell:
		handle_spell_target_selection(card)
		return
	if is_opponent_turn:
		return

func _on_player_deck_clicked():
	if is_opponent_turn: return
	if is_instance_valid(player_deck):
		if player_deck.drawn_card_this_turn:
			print("BattleManager: Já comprou carta neste turno.")
		else:
			rpc_draw_my_card()
			var opponent_bm = get_opponent_battle_manager()
			var opponent_peer_id = get_opponent_peer_id()
			if is_instance_valid(opponent_bm) and opponent_peer_id != 0:
				opponent_bm.rpc_id(opponent_peer_id, "rpc_draw_opponent_card")
			else:
				printerr("ERRO (_on_player_deck_clicked): Oponente BM ou Peer ID inválido.")
			player_deck.drawn_card_this_turn = true
	else:
		printerr("ERRO (BattleManager): Referência ao player_deck inválida.")

func _on_phase_button_pressed():
	if is_opponent_turn or player_is_attacking: return

	match current_combat_phase:
		CombatPhase.NONE: enter_begin_combat_phase()
		CombatPhase.BEGIN_COMBAT: enter_declare_attackers_phase()
		CombatPhase.DECLARE_ATTACKERS: pass # Espera confirmação
		CombatPhase.DECLARE_BLOCKERS: pass # Espera confirmação (do defensor)
		CombatPhase.COMBAT_DAMAGE: enter_end_combat_phase()
		CombatPhase.END_COMBAT: end_player_turn()

	update_ui_for_phase()

# Em scripts/battle_manager.gd

func _on_confirm_action_button_pressed():
	if (is_opponent_turn and current_combat_phase != CombatPhase.DECLARE_BLOCKERS) or player_is_attacking:
		print("Ação bloqueada: Turno do oponente ou atacando.")
		return
	match current_combat_phase:
		CombatPhase.DECLARE_ATTACKERS:
			if not is_opponent_turn:
				confirm_attackers()
		CombatPhase.DECLARE_BLOCKERS:
			if is_opponent_turn:
				confirm_blockers()
			if not is_opponent_turn and player_is_targeting_spell and is_instance_valid(spell_being_cast):
				if spell_being_cast.ability_script != null:
					var spell_name = spell_being_cast.card_name
					var target_data_array = []
					for target in current_spell_targets:
						var target_owner = ""
						var target_slot_index = -1
						if player_cards_on_battlefield.has(target):
							target_owner = "Jogador"
							target_slot_index = player_creature_slots_ref.find(target.card_slot_card_is_in)
						elif opponent_cards_on_battlefield.has(target):
							target_owner = "Oponente"
							target_slot_index = opponent_creature_slots_ref.find(target.card_slot_card_is_in)

						if target_slot_index != -1:
							target_data_array.append({"owner": target_owner, "slot_index": target_slot_index})

					var opponent_bm = get_opponent_battle_manager()
					var opponent_peer_id = get_opponent_peer_id()
					if is_instance_valid(opponent_bm) and opponent_peer_id != 0:
						opponent_bm.rpc_id(opponent_peer_id, "rpc_opponent_cast_targeted_spell", spell_name, target_data_array)

					await spell_being_cast.ability_script.trigger_ability(self, current_spell_targets, spell_being_cast, "Jogador")
				else:
					printerr("ERRO: Feitiço sem ability_script!")
					enable_game_inputs()

				reset_targeting_state()
			else:
				reset_targeting_state()

@rpc("any_peer", "call_local")
func start_turn(player_or_opponent: String):
	
	if is_instance_valid(combat_line_drawer_ref): combat_line_drawer_ref.clear_drawing()
	
	print("Iniciando turno de: ", player_or_opponent)
	current_combat_phase = CombatPhase.NONE
	declared_attackers.clear()
	declared_blockers.clear()
	blocker_assignments.clear()
	if is_instance_valid(card_manager): card_manager.clear_attacker_selection()
	clear_all_combat_indicators()

	if player_or_opponent == "Jogador":
		is_opponent_turn = false
		player_played_land_this_turn = false
		player_current_energy = player_lands_in_play
		player_cards_that_attacked_this_turn.clear()
		update_energy_labels()
		if is_instance_valid(player_deck): player_deck.reset_draw()
	elif player_or_opponent == "Oponente":
		is_opponent_turn = true
		opponent_played_land_this_turn = false
		opponent_current_energy = opponent_lands_in_play
		update_energy_labels()

	update_ui_for_phase()

func end_player_turn():
	
	if is_instance_valid(combat_line_drawer_ref): combat_line_drawer_ref.clear_drawing()
	
	print("Finalizando turno do jogador.")
	set_current_combat_phase(CombatPhase.NONE)
	if is_instance_valid(card_manager): card_manager.clear_attacker_selection()
	clear_all_combat_indicators()
	declared_attackers.clear()
	declared_blockers.clear()
	blocker_assignments.clear()

	start_turn("Oponente") # Muda estado localmente
	var opponent_bm = get_opponent_battle_manager()
	var opponent_peer_id = get_opponent_peer_id()
	if is_instance_valid(opponent_bm) and opponent_peer_id != 0:
		opponent_bm.rpc_id(opponent_peer_id, "start_turn", "Jogador") # Informa oponente para iniciar
	else:
		printerr("ERRO (end_player_turn): Oponente BM ou Peer ID inválido.")
	update_ui_for_phase()

func enter_begin_combat_phase():
	print("Entrando na Fase: Início de Combate")
	set_current_combat_phase(CombatPhase.BEGIN_COMBAT)
	update_ui_for_phase()

func enter_declare_attackers_phase():
	print("Entrando na Fase: Declarar Atacantes")
	set_current_combat_phase(CombatPhase.DECLARE_ATTACKERS)
	update_ui_for_phase()

func enter_declare_blockers_phase():
	print("Entrando na Fase: Declarar Bloqueadores (Esperando Oponente)")
	set_current_combat_phase(CombatPhase.DECLARE_BLOCKERS)
	update_ui_for_phase()

# Em scripts/battle_manager.gd
# Em scripts/battle_manager.gd
func enter_declare_blockers_phase_as_defender():
	print("Entrando na Fase: Declarar Bloqueadores (Como Defensor)")
	set_current_combat_phase(CombatPhase.DECLARE_BLOCKERS)
	blocker_assignments.clear()
	declared_blockers.clear()
	if is_instance_valid(combat_line_drawer_ref):
		combat_line_drawer_ref.clear_drawing()
	update_ui_for_phase_defender()

func enter_end_combat_phase():
	print("Entrando na Fase: Fim de Combate")
	set_current_combat_phase(CombatPhase.END_COMBAT)
	clear_all_combat_indicators()
	update_ui_for_phase()

func _apply_creature_damage(attacking_card: Node2D, defending_card: Node2D) -> Dictionary:
	var results = {"attacker_died": false, "defender_died": false}
	if not is_instance_valid(attacking_card) or not is_instance_valid(defending_card):
		return results
		
	var vfx_scene = null
	if attacking_card.attack >= 5 and HEAVY_ATTACK_VFX: 
		vfx_scene = HEAVY_ATTACK_VFX
	elif NORMAL_ATTACK_VFX: 
		vfx_scene = NORMAL_ATTACK_VFX
	if vfx_scene != null:
		var vfx = vfx_scene.instantiate()
		vfx.global_position = defending_card.global_position 
		if is_instance_valid(card_manager):
			card_manager.add_child(vfx)
		else:
			get_tree().root.add_child(vfx) 
	
	if is_instance_valid(attacking_card.card_slot_card_is_in):
		animate_card_to_position_and_scale(attacking_card, attacking_card.card_slot_card_is_in.global_position, attacking_card.scale, 0.15)
	attacking_card.z_index = -1
	
	defending_card.current_health = max(0, defending_card.current_health - attacking_card.attack)
	attacking_card.current_health = max(0, attacking_card.current_health - defending_card.attack)

	if defending_card.has_node("Attribute2"):
		defending_card.attribute2_label.text = str(defending_card.current_health)
	if attacking_card.has_node("Attribute2"):
		attacking_card.attribute2_label.text = str(attacking_card.current_health)

	if attacking_card.current_health <= 0:
		results["attacker_died"] = true
	if defending_card.current_health <= 0:
		results["defender_died"] = true

	return results

func _apply_direct_damage(attacking_card: Node2D) -> void:
	if not is_instance_valid(attacking_card):
		return
	opponent_health = max(0, opponent_health - attacking_card.attack)
	update_health_labels()

func confirm_attackers():
	print("Confirmando Atacantes...")
	if not is_instance_valid(card_manager): return

	declared_attackers = card_manager.selected_attackers.duplicate()
	card_manager.clear_attacker_selection()

	if declared_attackers.is_empty():
		print("Nenhum atacante declarado.")
		enter_end_combat_phase()
		return

	var attacker_indices = get_attacker_indices()
	var opponent_bm = get_opponent_battle_manager()
	var opponent_peer_id = get_opponent_peer_id()
	if is_instance_valid(opponent_bm) and opponent_peer_id != 0:
		opponent_bm.rpc_id(opponent_peer_id, "rpc_declare_attackers", attacker_indices)
	else:
		printerr("ERRO (confirm_attackers): Oponente BM ou Peer ID inválido.")

	enter_declare_blockers_phase() # Atacante agora espera bloqueadores

func confirm_blockers():
	print("Confirmando Bloqueadores...")
	if is_instance_valid(currently_selected_blocker):
		currently_selected_blocker.show_block_indicator(false)
		currently_selected_blocker = null

	var blocker_data_for_rpc = {}
	for attacker_card in declared_blockers:
		var attacker_slot_index = opponent_creature_slots_ref.find(attacker_card.card_slot_card_is_in)
		if attacker_slot_index != -1:
			var blocker_indices = []
			var blockers_list = declared_blockers[attacker_card]
			for blocker_card in blockers_list:
				var blocker_slot_index = player_creature_slots_ref.find(blocker_card.card_slot_card_is_in)
				if blocker_slot_index != -1:
					blocker_indices.append(blocker_slot_index)
				else:
					printerr("ERRO (confirm_blockers): Índice do slot do bloqueador ", blocker_card.card_name, " não encontrado.")
			if not blocker_indices.is_empty():
				blocker_data_for_rpc[str(attacker_slot_index)] = blocker_indices
		else:
			printerr("ERRO (confirm_blockers): Índice do slot do atacante ", attacker_card.card_name, " não encontrado.")

	print("Enviando dados de bloqueio via RPC: ", blocker_data_for_rpc)
	var opponent_bm = get_opponent_battle_manager()
	var opponent_peer_id = get_opponent_peer_id()
	if is_instance_valid(opponent_bm) and opponent_peer_id != 0:
		opponent_bm.rpc_id(opponent_peer_id, "rpc_receive_blockers", blocker_data_for_rpc)
	else:
		printerr("ERRO (confirm_blockers): Oponente BM ou Peer ID inválido.")
	if is_instance_valid(combat_line_drawer_ref):
		combat_line_drawer_ref.clear_drawing()
	resolve_combat_damage()

# Em scripts/battle_manager.gd

func resolve_combat_damage():
	print("Resolvendo Dano de Combate")
	set_current_combat_phase(CombatPhase.COMBAT_DAMAGE)
	player_is_attacking = true # Ativa flag para bloquear outras ações durante animação
	disable_game_inputs() # Desabilita botões
	var cards_to_destroy: Array = []
	var attackers_to_process = declared_attackers.duplicate()
	var current_blockers = declared_blockers.duplicate()
	var processed_attackers: Array = [] # Para evitar processar duas vezes
	for attacker in current_blockers: # Itera sobre os atacantes que foram bloqueados
		if not is_instance_valid(attacker): continue
		processed_attackers.append(attacker) # Marca como processado
		var blockers = current_blockers[attacker]
		if blockers.is_empty() or not is_instance_valid(blockers[0]): continue
		var primary_blocker = blockers[0] # Pega o primeiro bloqueador para a animação principal
		var original_attacker_pos = attacker.global_position
		var attack_target_pos = primary_blocker.global_position + Vector2(0, Constants.BATTLE_POS_OFFSET_Y)
		attacker.z_index = 5
		await animate_card_to_position_and_scale(attacker, attack_target_pos, attacker.scale, 0.15)
		print("Combate: ", attacker.card_name, " vs ", primary_blocker.card_name)
		var damage_results = _apply_creature_damage(attacker, primary_blocker) # Isso também toca o VFX
		if damage_results["attacker_died"]: cards_to_destroy.append({"card": attacker, "owner": "Jogador"})
		if damage_results["defender_died"]: cards_to_destroy.append({"card": primary_blocker, "owner": "Oponente"}) # Assumindo que bloqueador é do oponente
		for i in range(1, blockers.size()):
			var other_blocker = blockers[i]
			if is_instance_valid(attacker) and attacker.current_health > 0 and is_instance_valid(other_blocker):
				attacker.current_health = max(0, attacker.current_health - other_blocker.attack)
				if attacker.has_node("Attribute2"): attacker.attribute2_label.text = str(attacker.current_health)
				if attacker.current_health <= 0 and not cards_to_destroy.any(func(d): return d.card == attacker):
					cards_to_destroy.append({"card": attacker, "owner": "Jogador"})
		await get_tree().create_timer(0.3).timeout # Pausa curta após hit
		if is_instance_valid(attacker):
			await animate_card_to_position_and_scale(attacker, original_attacker_pos, attacker.scale, 0.15)
			attacker.z_index = -1
		await get_tree().create_timer(0.1).timeout # Pequena pausa entre combates
	for attacker in attackers_to_process:
		if processed_attackers.has(attacker) or not is_instance_valid(attacker): continue # Pula se já combateu ou inválido
		if attacker.current_health > 0: # Só ataca se estiver vivo
			var original_pos = attacker.global_position
			var target_y = opponent_health_label.global_position.y # Mira no label de vida do oponente
			var target_pos = Vector2(attacker.global_position.x, target_y)
			attacker.z_index = 5
			await animate_card_to_position_and_scale(attacker, target_pos, attacker.scale, 0.15)
			print("Dano Direto: ", attacker.card_name)
			if NORMAL_ATTACK_VFX:
				var vfx = NORMAL_ATTACK_VFX.instantiate(); vfx.global_position = target_pos # Posição aproximada do oponente
				if is_instance_valid(card_manager): 
					card_manager.add_child(vfx); 
				else: 
					get_tree().root.add_child(vfx)
			_apply_direct_damage(attacker)
			if not player_cards_that_attacked_this_turn.has(attacker):
				player_cards_that_attacked_this_turn.append(attacker)
			await get_tree().create_timer(0.3).timeout
			await animate_card_to_position_and_scale(attacker, original_pos, attacker.scale, 0.15)
			attacker.z_index = -1
			await get_tree().create_timer(0.1).timeout

	# --- Finalização ---
	update_health_labels()
	clear_all_combat_indicators()
	if is_instance_valid(combat_line_drawer_ref): combat_line_drawer_ref.clear_drawing()

	# Destruir Cartas marcadas
	if not cards_to_destroy.is_empty():
		await get_tree().create_timer(0.2).timeout # Pequena pausa antes de destruir
		for item in cards_to_destroy:
			if is_instance_valid(item.card):
				await destroy_card(item.card, item.owner)
				await get_tree().create_timer(0.1).timeout

	# Limpar Estado
	declared_attackers.clear()
	declared_blockers.clear()
	blocker_assignments.clear()
	player_is_attacking = false # Libera flag de animação
	enable_game_inputs()      # Reabilita botões (se for nosso turno)

	await get_tree().create_timer(0.3).timeout # Pausa final
	enter_end_combat_phase()

func handle_blocker_declaration_click(clicked_card: Node2D):

	if player_cards_on_battlefield.has(clicked_card) and clicked_card.card_type == "Criatura":
		var potential_blocker = clicked_card
		var can_select = not blocker_assignments.has(potential_blocker) or currently_selected_blocker == potential_blocker
		if not can_select:
			if is_instance_valid(currently_selected_blocker):
				currently_selected_blocker.show_block_indicator(false) # Remove: needs_redraw = true
				currently_selected_blocker = null
			return

		if currently_selected_blocker == potential_blocker:
			potential_blocker.show_block_indicator(false) # Remove: needs_redraw = true
			currently_selected_blocker = null
			if blocker_assignments.has(potential_blocker):
				var previous_attacker = blocker_assignments[potential_blocker]
				if declared_blockers.has(previous_attacker) and declared_blockers[previous_attacker].has(potential_blocker):
					declared_blockers[previous_attacker].erase(potential_blocker)
					if declared_blockers[previous_attacker].is_empty(): declared_blockers.erase(previous_attacker)
				blocker_assignments.erase(potential_blocker) # Remove: needs_redraw = true
		else:
			if is_instance_valid(currently_selected_blocker):
				currently_selected_blocker.show_block_indicator(false) # Remove: needs_redraw = true
			currently_selected_blocker = potential_blocker
			potential_blocker.show_block_indicator(true) # Remove: needs_redraw = true

	elif opponent_cards_on_battlefield.has(clicked_card) and is_instance_valid(currently_selected_blocker):
		var attacker_to_block = clicked_card
		if declared_attackers.has(attacker_to_block):
			if blocker_assignments.has(currently_selected_blocker):
				var previous_attacker = blocker_assignments[currently_selected_blocker]
				if declared_blockers.has(previous_attacker) and declared_blockers[previous_attacker].has(currently_selected_blocker):
					declared_blockers[previous_attacker].erase(currently_selected_blocker)
					if declared_blockers[previous_attacker].is_empty(): declared_blockers.erase(previous_attacker)
				blocker_assignments.erase(currently_selected_blocker) # Remove: needs_redraw = true

			blocker_assignments[currently_selected_blocker] = attacker_to_block # Remove: needs_redraw = true
			if not declared_blockers.has(attacker_to_block): declared_blockers[attacker_to_block] = []
			if not declared_blockers[attacker_to_block].has(currently_selected_blocker):
				declared_blockers[attacker_to_block].append(currently_selected_blocker)

			currently_selected_blocker.show_block_indicator(false)
			currently_selected_blocker = null
		else:
			if is_instance_valid(currently_selected_blocker):
				currently_selected_blocker.show_block_indicator(false) # Remove: needs_redraw = true
				currently_selected_blocker = null

	elif opponent_cards_on_battlefield.has(clicked_card) and not is_instance_valid(currently_selected_blocker):
		var attacker_clicked = clicked_card
		if declared_blockers.has(attacker_clicked):
			var blockers_to_remove = declared_blockers[attacker_clicked].duplicate()
			for blocker in blockers_to_remove:
				if is_instance_valid(blocker):
					if blocker.has_method("show_block_indicator"): blocker.show_block_indicator(false)
					if blocker_assignments.has(blocker): blocker_assignments.erase(blocker) # Remove: needs_redraw = true
			declared_blockers.erase(attacker_clicked) # Remove: needs_redraw = true

	else:
		if is_instance_valid(currently_selected_blocker):
			currently_selected_blocker.show_block_indicator(false) # Remove: needs_redraw = true
			currently_selected_blocker = null

	combat_line_drawer_ref.update_drawing(declared_blockers, not blocker_assignments.is_empty())

# --- Funções de Rede (RPCs) ---

@rpc("any_peer", "call_local")
func rpc_set_my_deck(deck_list: Array):
	if is_instance_valid(player_deck):
		player_deck.set_deck_list(deck_list)

@rpc("any_peer", "call_local")
func rpc_set_opponent_deck_size(deck_size: int):
	if is_instance_valid(opponent_deck):
		opponent_deck.set_card_count(deck_size)

@rpc("any_peer", "call_local")
func rpc_draw_my_card():
	if is_instance_valid(player_deck):
		player_deck.draw_card()

@rpc("any_peer", "call_local")
func rpc_draw_opponent_card():
	if is_instance_valid(opponent_deck):
		opponent_deck.draw_card()

@rpc("any_peer")
func rpc_opponent_played_card(card_name: String, card_type: String, slot_index: int):
	var target_slot = null
	if card_type == "Criatura":
		if slot_index >= 0 and slot_index < opponent_creature_slots_ref.size():
			target_slot = opponent_creature_slots_ref[slot_index]
	elif card_type == "Terreno":
		if slot_index >= 0 and slot_index < opponent_land_slots_ref.size():
			target_slot = opponent_land_slots_ref[slot_index]

	if not is_instance_valid(target_slot) or target_slot.card_in_slot:
		printerr("ERRO RPC rpc_opponent_played_card: Slot inválido ou ocupado!")
		return

	var card_to_play = opponent_hand.remove_card_from_hand_by_rpc()
	if not is_instance_valid(card_to_play):
		card_to_play = preload("res://scenes/opponent_card.tscn").instantiate()
		if is_instance_valid(card_manager): card_manager.add_child(card_to_play)
		else: printerr("ERRO RPC rpc_opponent_played_card: CardManager inválido."); card_to_play.queue_free(); return
		if is_instance_valid(opponent_deck): card_to_play.global_position = opponent_deck.global_position
		else: card_to_play.global_position = Vector2.ZERO # Fallback

	card_to_play.name = "OppCard_" + card_name.replace(" ", "_")
	card_to_play.card_name = card_name

	var card_data = card_database_ref.CARDS[card_name]
	card_to_play.attack = card_data[0]
	card_to_play.base_health = card_data[1]
	card_to_play.current_health = card_data[1]
	card_to_play.card_type = card_data[3]
	card_to_play.energy_cost = card_data[4]
	card_to_play.energy_generation = card_data[5]

	var card_image_path = card_database_ref.CARD_IMAGE_PATHS[card_name]
	card_to_play.set_card_image_texture(card_image_path)

	target_slot.card_in_slot = true
	card_to_play.card_slot_card_is_in = target_slot
	opponent_cards_on_battlefield.append(card_to_play)

	if card_to_play.card_type == "Terreno": opponent_lands_in_play += card_to_play.energy_generation
	else: opponent_current_energy -= card_to_play.energy_cost
	update_energy_labels()

	card_to_play.z_index = 10
	await animate_card_to_position_and_scale(card_to_play, target_slot.global_position, Constants.CARD_SMALLER_SCALE, 0.3)
	card_to_play.z_index = -1

	if card_to_play.has_node("AnimationPlayer"):
		card_to_play.animation_player.play("card_flip")
		await card_to_play.animation_player.animation_finished
	card_to_play.setup_card_display()

@rpc("any_peer")
func rpc_receive_attack(attacker_slot_index: int, defender_slot_index: int):
	var attacking_card: Node2D = null
	var defending_card: Node2D = null

	if attacker_slot_index >= 0 and attacker_slot_index < opponent_creature_slots_ref.size():
		var attacker_slot_node = opponent_creature_slots_ref[attacker_slot_index]
		for card in opponent_cards_on_battlefield:
			if card.card_slot_card_is_in == attacker_slot_node: attacking_card = card; break

	if defender_slot_index >= 0 and defender_slot_index < player_creature_slots_ref.size():
		var defender_slot_node = player_creature_slots_ref[defender_slot_index]
		for card in player_cards_on_battlefield:
			if card.card_slot_card_is_in == defender_slot_node: defending_card = card; break

	if is_instance_valid(attacking_card) and is_instance_valid(defending_card):
		await attack(attacking_card, defending_card, "Oponente")
	else:
		printerr("ERRO RPC: rpc_receive_attack não encontrou as cartas.")

@rpc("any_peer")
func rpc_receive_direct_attack(attacker_slot_index: int):
	var attacking_card: Node2D = null
	if attacker_slot_index >= 0 and attacker_slot_index < opponent_creature_slots_ref.size():
		var attacker_slot_node = opponent_creature_slots_ref[attacker_slot_index]
		for card in opponent_cards_on_battlefield:
			if card.card_slot_card_is_in == attacker_slot_node: attacking_card = card; break
	if is_instance_valid(attacking_card):
		await direct_attack(attacking_card, "Oponente")
	else:
		printerr("ERRO RPC: rpc_receive_direct_attack não encontrou a carta.")

@rpc("any_peer")
func rpc_opponent_cast_targeted_spell(spell_name: String, target_data_array: Array):
	if not card_database_ref.CARDS.has(spell_name): return
	var card_data = card_database_ref.CARDS[spell_name]
	var energy_cost = card_data[4]; var ability_path = card_data[6]
	if ability_path == null: return

	opponent_current_energy -= energy_cost; update_energy_labels()
	var fake_spell_card = opponent_hand.remove_card_from_hand_by_rpc()
	if not is_instance_valid(fake_spell_card):
		fake_spell_card = preload("res://scenes/opponent_card.tscn").instantiate()
		if is_instance_valid(card_manager): card_manager.add_child(fake_spell_card)
		else: printerr("ERRO RPC target spell: CardManager inválido."); fake_spell_card.queue_free(); return
		fake_spell_card.visible = false

	var local_target_nodes = []
	for target_data in target_data_array:
		var target_node = null; var target_owner = target_data["owner"]; var target_slot_index = target_data["slot_index"]
		if target_owner == "Jogador": target_node = find_card_in_slot_array(opponent_creature_slots_ref, opponent_cards_on_battlefield, target_slot_index)
		elif target_owner == "Oponente": target_node = find_card_in_slot_array(player_creature_slots_ref, player_cards_on_battlefield, target_slot_index)
		if is_instance_valid(target_node): local_target_nodes.append(target_node)

	var ability_script = load(ability_path).new()
	await ability_script.trigger_ability(self, local_target_nodes, fake_spell_card, "Oponente")

@rpc("any_peer")
func rpc_opponent_cast_global_spell(spell_name: String):
	if not card_database_ref.CARDS.has(spell_name): printerr("ERRO RPC global spell: Feitiço desconhecido: ", spell_name); return
	var card_data = card_database_ref.CARDS[spell_name]
	var energy_cost = card_data[4]; var ability_path = card_data[6]
	if ability_path == null: printerr("ERRO RPC global spell: Sem script: ", spell_name); return

	opponent_current_energy -= energy_cost; update_energy_labels()
	var fake_spell_card = opponent_hand.remove_card_from_hand_by_rpc()
	if not is_instance_valid(fake_spell_card):
		fake_spell_card = preload("res://scenes/opponent_card.tscn").instantiate()
		if is_instance_valid(card_manager): card_manager.add_child(fake_spell_card)
		else: printerr("ERRO RPC global spell: CardManager inválido."); fake_spell_card.queue_free(); return
		fake_spell_card.visible = false

	var ability_script = load(ability_path).new()
	await ability_script.trigger_ability(self, fake_spell_card, "Oponente") # Passa a carta fake

@rpc("any_peer")
func rpc_declare_attackers(attacker_indices: Array[int]):
	print("RPC Recebido: Atacantes declarados nos índices: ", attacker_indices)
	declared_attackers.clear()
	for index in attacker_indices:
		var card = find_card_in_slot_array(opponent_creature_slots_ref, opponent_cards_on_battlefield, index)
		if is_instance_valid(card):
			declared_attackers.append(card)
			if card.has_method("show_attack_indicator"): card.show_attack_indicator(true)
		else:
			printerr("RPC rpc_declare_attackers: Não foi possível encontrar atacante no índice ", index)
	enter_declare_blockers_phase_as_defender()

@rpc("any_peer")
func rpc_receive_blockers(blocker_data: Dictionary):
	print("RPC Recebido: Bloqueadores declarados: ", blocker_data)
	declared_blockers.clear()
	blocker_assignments.clear()

	for attacker_index_str in blocker_data:
		var attacker_index = int(attacker_index_str)
		var attacker_card = find_card_in_slot_array(player_creature_slots_ref, player_cards_on_battlefield, attacker_index) # Busca no campo

		if is_instance_valid(attacker_card):
			if not declared_attackers.has(attacker_card):
				print("Aviso: Atacante no índice ", attacker_index, " não está mais na lista de atacantes declarados.")
				continue

			var blocker_node_list = []
			var blocker_indices = blocker_data[attacker_index_str]
			for blocker_index in blocker_indices:
				var blocker_card = find_card_in_slot_array(opponent_creature_slots_ref, opponent_cards_on_battlefield, blocker_index)
				if is_instance_valid(blocker_card):
					blocker_node_list.append(blocker_card)
					if blocker_card.has_method("show_block_indicator"): blocker_card.show_block_indicator(true)
					blocker_assignments[blocker_card] = attacker_card
				else:
					printerr("RPC rpc_receive_blockers: Bloqueador não encontrado no índice ", blocker_index)

			if not blocker_node_list.is_empty():
				declared_blockers[attacker_card] = blocker_node_list
		else:
			printerr("RPC rpc_receive_blockers: Atacante não encontrado no slot de índice ", attacker_index)

	if is_instance_valid(combat_line_drawer_ref):
		combat_line_drawer_ref.update_drawing(declared_blockers, not blocker_assignments.is_empty())
	resolve_combat_damage()

func animate_card_to_position_and_scale(card: Node2D, target_position: Vector2, target_scale: Vector2, speed: float):
	if not is_instance_valid(card): return # Checagem de validade
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_QUAD); tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "global_position", target_position, speed)
	tween.tween_property(card, "scale", target_scale, speed)
	await tween.finished # Espera a animação terminar

func destroy_card(card_to_destroy: Node2D, card_owner: String):
	if not is_instance_valid(card_to_destroy): return

	# Instancia VFX se for criatura
	if card_to_destroy.card_type == "Criatura" and DESTROY_VFX:
		var vfx = DESTROY_VFX.instantiate()
		vfx.global_position = card_to_destroy.global_position
		# Adiciona o VFX como filho do CardManager para estar na camada correta
		if is_instance_valid(card_manager): card_manager.add_child(vfx)
		else: get_tree().root.add_child(vfx) # Fallback

	var discard_node = player_discard if card_owner == "Jogador" else opponent_discard
	var discard_pos = discard_node.global_position if is_instance_valid(discard_node) else Vector2(0, -200) # Posição fallback

	# Remove dos arrays de controle
	if card_owner == "Jogador":
		if player_cards_on_battlefield.has(card_to_destroy): player_cards_on_battlefield.erase(card_to_destroy)
		if player_cards_that_attacked_this_turn.has(card_to_destroy): player_cards_that_attacked_this_turn.erase(card_to_destroy)
		if card_to_destroy.card_type == "Terreno": player_lands_in_play = max(0, player_lands_in_play - card_to_destroy.energy_generation)
	else: # Oponente
		if opponent_cards_on_battlefield.has(card_to_destroy): opponent_cards_on_battlefield.erase(card_to_destroy)
		if card_to_destroy.card_type == "Terreno": opponent_lands_in_play = max(0, opponent_lands_in_play - card_to_destroy.energy_generation)

	update_energy_labels() # Atualiza energia caso um terreno seja destruído

	# Libera o slot
	if is_instance_valid(card_to_destroy.card_slot_card_is_in):
		var slot = card_to_destroy.card_slot_card_is_in
		slot.card_in_slot = false
		var area = slot.get_node_or_null("Area2D")
		if is_instance_valid(area):
			var shape = area.get_node_or_null("CollisionShape2D")
			if is_instance_valid(shape): shape.disabled = false
		card_to_destroy.card_slot_card_is_in = null

	if card_to_destroy.has_method("set_defeated"): card_to_destroy.set_defeated(true)

	# Anima para o descarte e remove
	await animate_card_to_position_and_scale(card_to_destroy, discard_pos, Constants.CARD_SMALLER_SCALE, 0.2)
	card_to_destroy.queue_free() # Remove a carta da cena

# --- Funções de Ataque (para efeitos ou IA, NÃO para combate normal) ---

func direct_attack(attacking_card: Node2D, attacker: String):
	# Esta função é para ataques diretos fora da fase de combate normal (ex: feitiços)
	if not is_instance_valid(attacking_card): return
	player_is_attacking = true; disable_game_inputs() # Simplificado, sem gerenciar botões aqui
	attacking_card.z_index = 5
	var target_y = get_viewport().size.y if attacker == "Oponente" else 0
	var target_pos = Vector2(attacking_card.global_position.x, target_y)
	await animate_card_to_position_and_scale(attacking_card, target_pos, attacking_card.scale, 0.15)

	if attacker == "Oponente": player_health = max(0, player_health - attacking_card.attack)
	else: opponent_health = max(0, opponent_health - attacking_card.attack)
	update_health_labels()

	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(attacking_card.card_slot_card_is_in):
		await animate_card_to_position_and_scale(attacking_card, attacking_card.card_slot_card_is_in.global_position, attacking_card.scale, 0.15)
	attacking_card.z_index = -1
	player_is_attacking = false; enable_game_inputs() # Simplificado

func attack(attacking_card: Node2D, defending_card: Node2D, attacker: String):
	# Esta função é para ataques fora da fase de combate normal
	if not is_instance_valid(attacking_card) or not is_instance_valid(defending_card): return
	player_is_attacking = true; disable_game_inputs()
	attacking_card.z_index = 5
	var target_pos = defending_card.global_position + Vector2(0, Constants.BATTLE_POS_OFFSET_Y)
	await animate_card_to_position_and_scale(attacking_card, target_pos, attacking_card.scale, 0.15)

	var vfx_scene = NORMAL_ATTACK_VFX if attacking_card.attack < 5 else HEAVY_ATTACK_VFX
	if vfx_scene != null:
		var vfx = vfx_scene.instantiate()
		vfx.global_position = defending_card.global_position
		if is_instance_valid(card_manager): card_manager.add_child(vfx)
		else: get_tree().root.add_child(vfx)

	var damage_results = _apply_creature_damage(attacking_card, defending_card) # Usa a função auxiliar

	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(attacking_card.card_slot_card_is_in):
		await animate_card_to_position_and_scale(attacking_card, attacking_card.card_slot_card_is_in.global_position, attacking_card.scale, 0.15)
	attacking_card.z_index = -1

	# Marca atacante se for jogador e ataque fora de fase
	if attacker == "Jogador" and get_parent().is_multiplayer_authority() and not player_cards_that_attacked_this_turn.has(attacking_card):
		player_cards_that_attacked_this_turn.append(attacking_card)

	# Destruição
	var destroyed = false
	if damage_results["attacker_died"]:
		await destroy_card(attacking_card, attacker)
		destroyed = true
	if damage_results["defender_died"] and is_instance_valid(defending_card): # Checa validade de novo
		var defender_owner = "Oponente" if attacker == "Jogador" else "Jogador"
		await destroy_card(defending_card, defender_owner)
		destroyed = true
	if destroyed: await get_tree().create_timer(0.5).timeout

	player_is_attacking = false; enable_game_inputs()

# --- Funções de Targeting de Feitiços ---

func setup_targeting_state(spell_card: Node2D, max_targets: int, restrictions: Dictionary, needs_confirmation: bool):
	player_is_targeting_spell = true
	spell_being_cast = spell_card
	current_spell_max_targets = max_targets
	current_spell_target_restrictions = restrictions
	current_spell_target_count = 0
	current_spell_targets.clear()
	if is_instance_valid(confirm_action_button): confirm_action_button.visible = needs_confirmation

func reset_targeting_state():
	player_is_targeting_spell = false
	spell_being_cast = null
	current_spell_max_targets = 0
	current_spell_target_count = 0
	current_spell_target_restrictions.clear()
	if is_instance_valid(confirm_action_button): confirm_action_button.visible = false
	for card in current_spell_targets:
		if is_instance_valid(card): card.modulate = Color(1, 1, 1)
	current_spell_targets.clear()

func handle_spell_target_selection(target_card: Node2D):
	if current_spell_targets.has(target_card):
		current_spell_targets.erase(target_card)
		current_spell_target_count -= 1
		target_card.modulate = Color(1, 1, 1)
		return

	if current_spell_target_count >= current_spell_max_targets: return

	var valid_target = true
	if current_spell_target_restrictions.has("type"):
		if not (target_card.card_type == current_spell_target_restrictions.type): valid_target = false
	if valid_target and current_spell_target_restrictions.has("max_health"):
		if not (target_card.current_health <= current_spell_target_restrictions.max_health): valid_target = false

	if valid_target:
		current_spell_targets.append(target_card)
		current_spell_target_count += 1
		target_card.modulate = Color(1, 0.5, 0.5)

		# Dispara feitiço de alvo único imediatamente
		var needs_confirmation = is_instance_valid(confirm_action_button) and confirm_action_button.visible
		if not needs_confirmation and current_spell_target_count == current_spell_max_targets:
			if is_instance_valid(spell_being_cast) and spell_being_cast.ability_script != null:
				await spell_being_cast.ability_script.trigger_ability(self, [target_card], spell_being_cast, "Jogador")
			else:
				printerr("ERRO: Feitiço de alvo único falhou.")
			reset_targeting_state()

# --- Funções de UI e Auxiliares ---

func update_health_labels():
	if is_instance_valid(player_health_label): player_health_label.text = str(player_health)
	if is_instance_valid(opponent_health_label): opponent_health_label.text = str(opponent_health)

func update_energy_labels():
	if is_instance_valid(player_energy_label): player_energy_label.text = "E: " + str(player_current_energy) + "/" + str(player_lands_in_play)
	if is_instance_valid(opponent_energy_label): opponent_energy_label.text = "E: " + str(opponent_current_energy) + "/" + str(opponent_lands_in_play)

func disable_game_inputs():
	if is_instance_valid(phase_button): phase_button.disabled = true
	if is_instance_valid(confirm_action_button): confirm_action_button.disabled = true
	# Considerar desabilitar input_manager se necessário

func enable_game_inputs():
	# Só reabilita se for turno do jogador e não estiver em animação
	if not is_opponent_turn and not player_is_attacking:
		update_ui_for_phase() # Deixa a função de UI decidir o estado dos botões

func update_ui_for_phase():
	if not is_instance_valid(phase_button) or not is_instance_valid(confirm_action_button): return

	if is_opponent_turn:
		phase_button.visible = false; confirm_action_button.visible = false; return

	confirm_action_button.visible = false; phase_button.visible = true; phase_button.disabled = false

	match current_combat_phase:
		CombatPhase.NONE: phase_button.text = "Iniciar Combate"; confirm_action_button.visible = player_is_targeting_spell
		CombatPhase.BEGIN_COMBAT: phase_button.text = "Declarar Atacantes"
		CombatPhase.DECLARE_ATTACKERS: phase_button.disabled = true; confirm_action_button.text = "Confirmar Atacantes"; confirm_action_button.visible = true; confirm_action_button.disabled = false
		CombatPhase.DECLARE_BLOCKERS: phase_button.text = "Esperando Bloqueio..."; phase_button.disabled = true # Defensor usa confirm
		CombatPhase.COMBAT_DAMAGE: phase_button.text = "Resolvendo Dano..."; phase_button.disabled = true
		CombatPhase.END_COMBAT: phase_button.text = "Finalizar Turno"

func update_ui_for_phase_defender():
	if not is_instance_valid(phase_button) or not is_instance_valid(confirm_action_button): return
	phase_button.visible = false
	confirm_action_button.text = "Confirmar Bloqueadores"
	confirm_action_button.disabled = false
	confirm_action_button.visible = true

func clear_all_combat_indicators():
	for card in player_cards_on_battlefield:
		if is_instance_valid(card) and card.has_method("hide_combat_indicators"): card.hide_combat_indicators()
	for card in opponent_cards_on_battlefield:
		if is_instance_valid(card) and card.has_method("hide_combat_indicators"): card.hide_combat_indicators()

func get_attacker_indices() -> Array[int]:
	var indices: Array[int] = []
	for attacker in declared_attackers:
		if is_instance_valid(attacker) and is_instance_valid(attacker.card_slot_card_is_in):
			var index = player_creature_slots_ref.find(attacker.card_slot_card_is_in)
			if index != -1: indices.append(index)
	return indices

func find_card_in_slot_array(slot_array: Array, card_array: Array, slot_index: int) -> Node2D:
	if slot_index < 0 or slot_index >= slot_array.size(): return null
	var target_slot_node = slot_array[slot_index]
	for card in card_array:
		if is_instance_valid(card) and card.card_slot_card_is_in == target_slot_node: return card
	return null

func get_opponent_battle_manager() -> Node:
	var player_id = get_parent().name
	var opponent_id_str = "2" if player_id == "1" else "1"
	var opponent_bm_path = "/root/Main/" + opponent_id_str + "/BattleManager"
	return get_node_or_null(opponent_bm_path)

func get_opponent_peer_id() -> int:
	var multiplayer_ref = get_node("/root/Main")
	return multiplayer_ref.opponent_peer_id if multiplayer_ref else 0

# --- Funções de Checagem (Exemplo) ---

func check_plague_condition() -> bool:
	for card in player_cards_on_battlefield:
		if is_instance_valid(card) and card.card_name == "Rato da Peste": return true
		if is_instance_valid(card) and "plague_counters" in card and card.plague_counters > 0: return true
	for card in opponent_cards_on_battlefield:
		if is_instance_valid(card) and card.card_name == "Rato da Peste": return true
		if is_instance_valid(card) and "plague_counters" in card and card.plague_counters > 0: return true
	return false

func player_has_creatures() -> bool:
	for card in player_cards_on_battlefield:
		if is_instance_valid(card) and card.card_type == "Criatura": return true
	return false

func opponent_has_creatures() -> bool:
	for card in opponent_cards_on_battlefield:
		if is_instance_valid(card) and card.card_type == "Criatura": return true
	return false

# --- Função de Invocar Token ---
func summon_token(card_name: String, owner: String):
	var empty_slot = null; var slots_array = []; var card_to_instance = null
	if owner == "Jogador": slots_array = player_creature_slots_ref; card_to_instance = card_scene
	elif owner == "Oponente": slots_array = opponent_creature_slots_ref; card_to_instance = preload("res://scenes/opponent_card.tscn")
	else: printerr("ERRO summon_token: 'owner' desconhecido: ", owner); return

	for slot in slots_array:
		if is_instance_valid(slot) and not slot.card_in_slot: empty_slot = slot; break
	if not is_instance_valid(empty_slot): print("BattleManager: Sem slots vazios para ", owner); return

	# Instancia VFX
	if SUMMON_VFX_SCENE:
		var vfx_instance = SUMMON_VFX_SCENE.instantiate()
		vfx_instance.global_position = empty_slot.global_position
		if is_instance_valid(card_manager): card_manager.add_child(vfx_instance)
		else: get_tree().root.add_child(vfx_instance) # Fallback
		await get_tree().create_timer(0.3).timeout

	# Instancia Carta
	var new_card = card_to_instance.instantiate()
	new_card.name = "Token_" + card_name.replace(" ", "_")
	new_card.card_name = card_name
	if is_instance_valid(card_manager): card_manager.add_child(new_card)
	else: get_tree().root.add_child(new_card); printerr("ERRO summon_token: CardManager inválido.") # Fallback

	# Preenche dados
	var card_data = card_database_ref.CARDS[card_name]
	new_card.attack = card_data[0]; new_card.base_health = card_data[1]; new_card.current_health = card_data[1]
	new_card.card_type = card_data[3]; new_card.energy_cost = 0; new_card.energy_generation = card_data[5]
	var card_image_path = card_database_ref.CARD_IMAGE_PATHS[card_name]
	new_card.set_card_image_texture(card_image_path)

	# Posiciona
	new_card.global_position = empty_slot.global_position
	new_card.scale = Constants.CARD_SMALLER_SCALE; new_card.z_index = -1

	# Anima e mostra display
	if new_card.has_node("AnimationPlayer"):
		new_card.animation_player.play("card_flip")
		await new_card.animation_player.animation_finished
	new_card.setup_card_display()

	# Atualiza estado
	empty_slot.card_in_slot = true
	new_card.card_slot_card_is_in = empty_slot
	if owner == "Jogador": player_cards_on_battlefield.append(new_card)
	else: opponent_cards_on_battlefield.append(new_card)

	# Desabilita colisão do slot
	var slot_area = empty_slot.get_node_or_null("Area2D")
	if is_instance_valid(slot_area):
		var slot_shape = slot_area.get_node_or_null("CollisionShape2D")
		if is_instance_valid(slot_shape): 
			slot_shape.disabled = true
