extends Node

signal combat_phase_changed(new_phase: CombatPhase)

var phase_button
var battle_timer
var opponent_deck
var opponent_hand
var player_deck # Este script está DENTRO do PlayerField, então este é o "deck" local
var card_manager
var player_health_label
var opponent_health_label
var player_discard
var opponent_discard
var player_energy_label
var opponent_energy_label
var confirm_action_button
var player_slots_container


# --- Constantes e Preloads (sem mudança) ---
const CARD_SCENE_PATH = "res://scenes/card.tscn"
var card_scene = preload(CARD_SCENE_PATH)
const SUMMON_VFX_SCENE = preload("res://scenes/vfx/summon_vfx.tscn") 
# (Certifique-se que o caminho do seu summon_vfx.tscn está correto aqui)
# (Seus preloads de VFX de ataque/destruição também devem estar aqui)
const DESTROY_VFX = preload("res://scenes/vfx/destroy_vfx.tscn")
const NORMAL_ATTACK_VFX = preload("res://scenes/vfx/normal_attack_vfx.tscn")
const HEAVY_ATTACK_VFX = preload("res://scenes/vfx/heavy_attack_vfx.tscn")

var card_database_ref = preload("res://scripts/card_database.gd")

var player_health: int = 20
var opponent_health: int = 20
var player_max_energy: int = 1
var player_current_energy: int = 1
var opponent_max_energy: int = 1
var opponent_current_energy: int = 1
var turns: int = 0

# Contagem de terrenos (substitui max_energy)
var player_lands_in_play: int = 0
var opponent_lands_in_play: int = 0

# Travas de turno
var player_played_land_this_turn: bool = false
var opponent_played_land_this_turn: bool = false

# Arrays de gerenciamento
var player_cards_on_battlefield: Array = []
var opponent_cards_on_battlefield: Array = []
var player_cards_that_attacked_this_turn: Array = []
var opponent_land_slots_ref: Array = []

# Arrays de slots (populados no _ready)
var player_creature_slots_ref: Array = []
var player_land_slots_ref: Array = []
var opponent_creature_slots_ref: Array = []

# Flags de estado
var is_opponent_turn: bool = false
var player_is_attacking: bool = false

# --- NOVO SISTEMA DE TARGETING (sem mudança) ---
var player_is_targeting_spell: bool = false 
var spell_being_cast: Node2D = null
var current_spell_max_targets: int = 0
var current_spell_target_count: int = 0
var current_spell_targets: Array = [] 
var current_spell_target_restrictions: Dictionary = {}
var input_manager_ref 

enum CombatPhase { NONE, BEGIN_COMBAT, DECLARE_ATTACKERS, DECLARE_BLOCKERS, COMBAT_DAMAGE, END_COMBAT }
var current_combat_phase: CombatPhase = CombatPhase.NONE #setget set_current_combat_phase
var declared_attackers: Array[Node2D] = []
var declared_blockers: Dictionary = {}
var blocker_assignments: Dictionary = {}
var currently_selected_blocker: Node2D = null

func _ready(): # Ou func initialize_references():
	await get_tree().process_frame

	if not get_parent().is_multiplayer_authority():
		return

	var player_id = get_parent().name
	var opponent_id = "2" if player_id == "1" else "1"
	var opponent_path = "/root/Main/" + opponent_id
	var local_parent = get_parent()

	phase_button = local_parent.get_node("PhaseButton") 
	battle_timer = local_parent.get_node_or_null("BattleTimer")
	player_deck = local_parent.get_node("Deck")
	card_manager = local_parent.get_node("CardManager")
	player_health_label = local_parent.get_node("PlayerHealthLabel")
	player_discard = local_parent.get_node("PlayerDiscard")
	player_energy_label = local_parent.get_node("PlayerEnergyLabel")
	confirm_action_button = local_parent.get_node("ConfirmActionButton") 
	player_slots_container = local_parent.get_node("PlayerCardSlots")
	input_manager_ref = local_parent.get_node("InputManager")

	opponent_deck = get_node(opponent_path + "/Deck")
	opponent_hand = get_node(opponent_path + "/OpponentHand")
	opponent_health_label = get_node(opponent_path + "/OpponentHealthLabel")
	opponent_discard = get_node(opponent_path + "/OpponentDiscard")
	opponent_energy_label = get_node(opponent_path + "/OpponentEnergyLabel")

	# Lógica original
	update_health_labels()
	update_energy_labels()

	# CONECTAR BOTÕES AOS HANDLERS CORRETOS
	if is_instance_valid(phase_button):
		# REMOVER: phase_button.pressed.connect(_on_end_turn_button_pressed) # Conexão antiga
		phase_button.pressed.connect(_on_phase_button_pressed) # Nova conexão centralizada
	if is_instance_valid(confirm_action_button):
		# Mantém conexão, mas a função mudará de nome/lógica
		confirm_action_button.pressed.connect(_on_confirm_action_button_pressed)

	# Conexões de Sinais (como antes)
	if is_instance_valid(card_manager):
		card_manager.card_played.connect(_on_card_played)
		card_manager.spell_cast_initiated.connect(_on_spell_cast_initiated)
	else:
		printerr("BattleManager: CardManager não encontrado.")

	if is_instance_valid(input_manager_ref):
		input_manager_ref.opponent_card_clicked.connect(_on_opponent_card_clicked)
		input_manager_ref.player_deck_clicked.connect(_on_player_deck_clicked)
	else:
		printerr("BattleManager: InputManager não encontrado.")

	if is_instance_valid(opponent_deck):
		opponent_deck.set_process(false)

	# Pega referências para os slots (como antes)
	# ... (código para popular player_creature_slots_ref, etc.) ...

	update_ui_for_phase() # Define o estado inicial da UI

func initialize_references():
	
	# Não precisamos mais do 'await' aqui, pois o multiplayer.gd já esperou.
	
	# Pega o nome do nosso "campo" pai ("1" ou "2")
	var player_id = get_parent().name 
	# O oponente é o "outro" número
	var opponent_id = "2" if player_id == "1" else "1"
	
	# Caminho para os nossos próprios nós (jogador local)
	var player_path = "/root/Main/" + player_id
	# Caminho para os nós do oponente
	var opponent_path = "/root/Main/" + opponent_id

	# Referências locais (dentro do nosso próprio PlayerField)
	phase_button = get_node(player_path + "/PhaseButton")
	battle_timer = get_node(player_path + "/BattleTimer")
	player_deck = get_node(player_path + "/Deck")
	card_manager = get_node(player_path + "/CardManager")
	player_health_label = get_node(player_path + "/PlayerHealthLabel")
	player_discard = get_node(player_path + "/PlayerDiscard")
	player_energy_label = get_node(player_path + "/PlayerEnergyLabel")
	confirm_action_button = get_node(player_path + "/ConfirmTargetsButton")
	player_slots_container = get_node(player_path + "/PlayerCardSlots")

	# Referências remotas (dentro do OpponentField)
	opponent_deck = get_node(opponent_path + "/Deck") # (Verifique se o seu nó em opponent_field.tscn se chama "Deck")
	opponent_hand = get_node(opponent_path + "/OpponentHand")
	opponent_health_label = get_node(opponent_path + "/OpponentHealthLabel")
	opponent_discard = get_node(opponent_path + "/OpponentDiscard")
	opponent_energy_label = get_node(opponent_path + "/OpponentEnergyLabel")

	# --- Lógica original do _ready() ---
	update_health_labels()
	update_energy_labels()
	phase_button.pressed.connect(_on_phase_button_pressed())
	
	# Desabilita o oponente (este script não controla mais a IA)
	if is_instance_valid(opponent_deck):
		opponent_deck.set_process(false) 
	
	# Pega referências para os slots (lógica antiga ainda funciona)
	var player_creature_slots = get_parent().get_node("PlayerCardSlots")
	for i in range(player_creature_slots.get_child_count()):
		var slot = player_creature_slots.get_child(i)
		if slot.card_slot_type == "Criatura":
			player_creature_slots_ref.append(slot)
		else:
			player_land_slots_ref.append(slot)
	
	var opponent_creature_slots = get_node(opponent_path + "/OpponentCardSlots")
	for i in range(opponent_creature_slots.get_child_count()):
		opponent_creature_slots_ref.append(opponent_creature_slots.get_child(i))

func set_current_combat_phase(new_phase: CombatPhase) -> void:
	if current_combat_phase != new_phase:
		current_combat_phase = new_phase
		emit_signal("combat_phase_changed", current_combat_phase)
		update_ui_for_phase()

func _on_phase_button_pressed():
	# Verifica se é nosso turno e não estamos em animação
	if is_opponent_turn or player_is_attacking:
		return

	match current_combat_phase:
		CombatPhase.NONE:
			# Estava na fase principal, entra em combate
			enter_begin_combat_phase()
		CombatPhase.BEGIN_COMBAT:
			# Estava no início do combate, declara atacantes
			enter_declare_attackers_phase()
		CombatPhase.DECLARE_ATTACKERS:
			# O botão principal não faz nada aqui, espera o botão de confirmação
			pass
		CombatPhase.DECLARE_BLOCKERS:
			# O jogador defensor clica para confirmar (ou não) bloqueadores
			# Aqui seria a confirmação se não houver bloqueios
			# Chamaremos a confirmação pelo outro botão
			pass # Ou talvez avançar direto para dano se não houver atacantes?
		CombatPhase.COMBAT_DAMAGE:
			# Após o dano, vai para o fim do combate
			enter_end_combat_phase()
		CombatPhase.END_COMBAT:
			# Após fim do combate, volta para a Fase Principal 2 (ou direto fim do turno)
			end_player_turn() # Função para passar o turno

	update_ui_for_phase() # Garante que a UI reflita a nova fase


func enter_begin_combat_phase():
	print("Entrando na Fase: Início de Combate")
	set_current_combat_phase(CombatPhase.BEGIN_COMBAT)
	# TODO: Disparar habilidades "no início do combate"
	# TODO: Permitir mágicas/habilidades
	# Avança automaticamente (ou espera clique no botão?)
	# Por enquanto, vamos fazer avançar ao clicar no botão de novo
	update_ui_for_phase()

func enter_declare_attackers_phase():
	print("Entrando na Fase: Declarar Atacantes")
	set_current_combat_phase(CombatPhase.DECLARE_ATTACKERS)
	# O CardManager permitirá a seleção de atacantes agora
	update_ui_for_phase()

func confirm_attackers():
	print("Confirmando Atacantes...")
	if not is_instance_valid(card_manager): return

	# Pega os atacantes selecionados do CardManager
	declared_attackers = card_manager.selected_attackers.duplicate() # Copia a lista
	card_manager.clear_attacker_selection() # Limpa a seleção visual no CardManager

	if declared_attackers.is_empty():
		print("Nenhum atacante declarado.")
		# Pula direto para o fim do combate? Ou para a fase principal 2?
		enter_end_combat_phase() # Simplificação por agora
		return

	# TODO: Enviar RPC para o oponente com os atacantes (índices ou IDs)
	rpc_declare_attackers(get_attacker_indices())

	# TODO: Disparar habilidades "quando ataca"

	# Avança para a próxima etapa (espera o oponente bloquear)
	enter_declare_blockers_phase()
	update_ui_for_phase()

func enter_declare_blockers_phase():
	print("Entrando na Fase: Declarar Bloqueadores (Esperando Oponente)")
	set_current_combat_phase(CombatPhase.DECLARE_BLOCKERS)
	# O jogador local espera. O oponente (ou IA) escolherá bloqueadores.
	# A UI deve indicar espera ou permitir apenas ações instantâneas.
	update_ui_for_phase() # Desabilitará botões principais

# Em scripts/battle_manager.gd

@rpc("any_peer")
func rpc_receive_blockers(blocker_data: Dictionary):
	print("RPC Recebido: Bloqueadores declarados: ", blocker_data)
	declared_blockers.clear()
	blocker_assignments.clear()

	for attacker_index_str in blocker_data:
		var attacker_index = int(attacker_index_str)
		# CORREÇÃO: Busca o atacante diretamente no array de cartas do jogador usando o índice do slot
		var attacker_card = find_card_in_slot_array(player_creature_slots_ref, player_cards_on_battlefield, attacker_index) # Busca no campo, não em declared_attackers

		if is_instance_valid(attacker_card):
			# Verifica se este atacante ainda está na lista de atacantes declarados (pode ter sido removido por um efeito)
			if not declared_attackers.has(attacker_card):
				print("Aviso: Atacante no índice ", attacker_index, " não está mais na lista de atacantes declarados.")
				continue # Pula para o próximo atacante

			var blocker_node_list = []
			var blocker_indices = blocker_data[attacker_index_str]
			for blocker_index in blocker_indices:
				var blocker_card = find_card_in_slot_array(opponent_creature_slots_ref, opponent_cards_on_battlefield, blocker_index)
				if is_instance_valid(blocker_card):
					blocker_node_list.append(blocker_card)
					if blocker_card.has_method("show_block_indicator"):
						blocker_card.show_block_indicator(true)
					blocker_assignments[blocker_card] = attacker_card
				else:
					printerr("RPC rpc_receive_blockers: Bloqueador não encontrado no índice ", blocker_index)

			if not blocker_node_list.is_empty():
				declared_blockers[attacker_card] = blocker_node_list
		else:
			printerr("RPC rpc_receive_blockers: Atacante não encontrado no slot de índice ", attacker_index)

	# TODO: Lidar com ordem de dano se múltiplos bloqueadores.

	resolve_combat_damage()

func confirm_blockers():
	print("Confirmando Bloqueadores...")
	# Limpa qualquer seleção pendente de bloqueador
	if is_instance_valid(currently_selected_blocker):
		currently_selected_blocker.show_block_indicator(false)
		currently_selected_blocker = null

	# Prepara dados para RPC: { "indice_atacante": [indice_bloqueador1, ...], ... }
	var blocker_data_for_rpc = {}
	# Itera sobre os atacantes que FORAM bloqueados (chaves do dict declared_blockers)
	for attacker_card in declared_blockers:
		# Encontra o índice do slot do atacante (que é uma carta do oponente para nós)
		var attacker_slot_index = opponent_creature_slots_ref.find(attacker_card.card_slot_card_is_in)
		if attacker_slot_index != -1:
			var blocker_indices = []
			# Pega a lista de bloqueadores para este atacante
			var blockers_list = declared_blockers[attacker_card]
			for blocker_card in blockers_list:
				# Encontra o índice do slot do bloqueador (que é uma carta nossa)
				var blocker_slot_index = player_creature_slots_ref.find(blocker_card.card_slot_card_is_in)
				if blocker_slot_index != -1:
					blocker_indices.append(blocker_slot_index)
				else:
					printerr("ERRO (confirm_blockers): Índice do slot do bloqueador ", blocker_card.card_name, " não encontrado.")

			# Adiciona ao dicionário do RPC se houver bloqueadores válidos
			if not blocker_indices.is_empty():
				blocker_data_for_rpc[str(attacker_slot_index)] = blocker_indices # Usa string como chave para garantir compatibilidade RPC
		else:
			printerr("ERRO (confirm_blockers): Índice do slot do atacante ", attacker_card.card_name, " não encontrado.")

	print("Enviando dados de bloqueio via RPC: ", blocker_data_for_rpc)
	# Envia RPC para o oponente (atacante) informando os bloqueios
	var opponent_bm = get_opponent_battle_manager()
	var opponent_peer_id = get_opponent_peer_id()
	if is_instance_valid(opponent_bm) and opponent_peer_id != 0:
		opponent_bm.rpc_id(opponent_peer_id, "rpc_receive_blockers", blocker_data_for_rpc)
	else:
		printerr("ERRO (confirm_blockers): Oponente BM ou Peer ID inválido.")

	# TODO: Lidar com a ordem de atribuição de dano se um atacante for bloqueado por múltiplas criaturas (o atacante decide a ordem).

	# Avança para a fase de dano localmente (ambos os jogadores devem fazer isso após a sincronização)
	resolve_combat_damage()

# Em scripts/battle_manager.gd

func resolve_combat_damage():
	print("Resolvendo Dano de Combate")
	set_current_combat_phase(CombatPhase.COMBAT_DAMAGE)
	update_ui_for_phase()

	var cards_to_destroy: Array = []
	var attackers_to_process = declared_attackers.duplicate()
	var current_blockers = declared_blockers.duplicate()

	# --- Etapa 1: Dano entre Criaturas Bloqueadas ---
	for attacker in attackers_to_process:
		if current_blockers.has(attacker):
			var blockers = current_blockers[attacker]
			if not blockers.is_empty():
				var first_blocker = blockers[0]
				print("Combate: ", attacker.card_name, " vs ", first_blocker.card_name)
				var damage_results = _apply_creature_damage(attacker, first_blocker)
				if damage_results["attacker_died"]:
					cards_to_destroy.append({"card": attacker, "owner": "Jogador"})
				if damage_results["defender_died"]:
					cards_to_destroy.append({"card": first_blocker, "owner": "Oponente"})

				for i in range(1, blockers.size()):
					var other_blocker = blockers[i]
					if is_instance_valid(attacker) and attacker.current_health > 0 and is_instance_valid(other_blocker):
						attacker.current_health = max(0, attacker.current_health - other_blocker.attack)
						if attacker.has_node("Attribute2"): attacker.attribute2_label.text = str(attacker.current_health)
						if attacker.current_health <= 0 and not cards_to_destroy.any(func(d): return d.card == attacker):
							cards_to_destroy.append({"card": attacker, "owner": "Jogador"})

			declared_attackers.erase(attacker) # Remove atacante bloqueado da lista de dano direto

	# --- Etapa 2: Dano Direto ao Oponente ---
	for attacker in declared_attackers:
		if is_instance_valid(attacker) and attacker.current_health > 0:
			# Marca que atacou ANTES de aplicar dano
			if not player_cards_that_attacked_this_turn.has(attacker):
				player_cards_that_attacked_this_turn.append(attacker)
			print("Dano Direto: ", attacker.card_name, " (Atk:", attacker.attack, ")")
			_apply_direct_damage(attacker)


	# --- Etapa 3: Atualizar Vida e Limpar Indicadores ANTES de Destruir ---
	update_health_labels()
	clear_all_combat_indicators() # Limpa indicadores de ataque/bloqueio

	# --- Etapa 4: Destruir Cartas ---
	if not cards_to_destroy.is_empty():
		for item in cards_to_destroy:
			if is_instance_valid(item.card):
				await destroy_card(item.card, item.owner)
				await get_tree().create_timer(0.1).timeout

	# --- Etapa 5: Limpar Estado e Avançar ---
	declared_attackers.clear()
	declared_blockers.clear()
	blocker_assignments.clear()

	# TODO: Disparar habilidades "quando causa dano" ou "quando morre"

	await get_tree().create_timer(0.5).timeout
	enter_end_combat_phase()

func enter_end_combat_phase():
	print("Entrando na Fase: Fim de Combate")
	set_current_combat_phase(CombatPhase.END_COMBAT)
	# TODO: Disparar habilidades "no fim do combate"
	# Limpa indicadores visuais restantes
	clear_all_combat_indicators()
	# Volta para a fase principal (ou permite clicar para finalizar turno)
	# set_current_combat_phase(CombatPhase.NONE) # Ou direto para fim do turno?
	update_ui_for_phase()

func end_player_turn():
	print("Finalizando turno do jogador.")
	set_current_combat_phase(CombatPhase.NONE) # Reseta fase de combate
	# Limpa indicadores visuais e atacantes/bloqueadores (redundante se feito em END_COMBAT)
	if is_instance_valid(card_manager): card_manager.clear_attacker_selection()
	clear_all_combat_indicators()
	declared_attackers.clear()
	declared_blockers.clear()
	blocker_assignments.clear()

	# Lógica original de passar o turno via RPC
	start_turn("Oponente")
	var player_id = get_parent().name
	var opponent_id_str = "2" if player_id == "1" else "1"
	var opponent_bm_path = "/root/Main/" + opponent_id_str + "/BattleManager"
	var opponent_bm = get_node_or_null(opponent_bm_path)
	var multiplayer_ref = get_node("/root/Main")
	var opponent_peer_id = multiplayer_ref.opponent_peer_id if multiplayer_ref else 0

	if is_instance_valid(opponent_bm) and opponent_peer_id != 0:
		opponent_bm.rpc_id(opponent_peer_id, "start_turn", "Jogador")
	else:
		printerr("ERRO (end_player_turn): Oponente BM ou Peer ID inválido.")
	update_ui_for_phase() # Atualiza UI para estado de espera


@rpc("any_peer", "call_local")
func start_turn(player_or_opponent: String):
	print("Iniciando turno de: ", player_or_opponent)
	current_combat_phase = CombatPhase.NONE # Reseta a fase de combate
	# Limpa listas relacionadas ao combate anterior (segurança)
	declared_attackers.clear()
	declared_blockers.clear()
	blocker_assignments.clear()
	if is_instance_valid(card_manager): card_manager.clear_attacker_selection()
	clear_all_combat_indicators()


	if player_or_opponent == "Jogador":
		is_opponent_turn = false
		player_played_land_this_turn = false
		player_current_energy = player_lands_in_play # Ganha energia igual aos terrenos
		player_cards_that_attacked_this_turn.clear()
		update_energy_labels()
		if is_instance_valid(player_deck): player_deck.reset_draw()
		# Botão será controlado por update_ui_for_phase
	elif player_or_opponent == "Oponente":
		is_opponent_turn = true
		opponent_played_land_this_turn = false
		opponent_current_energy = opponent_lands_in_play
		update_energy_labels()
		# Botões serão controlados por update_ui_for_phase

	update_ui_for_phase() # Atualiza a UI no início do turno

func wait_seconds(time: float):
	battle_timer.wait_time = time; battle_timer.start(); await battle_timer.timeout

func direct_attack(attacking_card: Node2D, attacker: String):
	player_is_attacking = true; phase_button.disabled = true; phase_button.visible = false
	attacking_card.z_index = 5
	var target_y = get_viewport().size.y if attacker == "Oponente" else 0
	var target_pos = Vector2(attacking_card.global_position.x, target_y)
	animate_card_to_position_and_scale(attacking_card, target_pos, attacking_card.scale, 0.15); await wait_seconds(0.15)
	if attacker == "Oponente": player_health = max(0, player_health - attacking_card.attack)
	else: opponent_health = max(0, opponent_health - attacking_card.attack); player_cards_that_attacked_this_turn.append(attacking_card)
	update_health_labels(); await wait_seconds(0.5)
	if is_instance_valid(attacking_card.card_slot_card_is_in): animate_card_to_position_and_scale(attacking_card, attacking_card.card_slot_card_is_in.global_position, attacking_card.scale, 0.15); await wait_seconds(0.15)
	attacking_card.z_index = -1
	player_is_attacking = false; 
	if get_parent().is_multiplayer_authority() and not is_opponent_turn:
		phase_button.disabled = false; phase_button.visible = true

func attack(attacking_card: Node2D, defending_card: Node2D, attacker: String):
	player_is_attacking = true; phase_button.disabled = true; phase_button.visible = false
	attacking_card.z_index = 5
	var target_pos = defending_card.global_position + Vector2(0, Constants.BATTLE_POS_OFFSET_Y)
	animate_card_to_position_and_scale(attacking_card, target_pos, attacking_card.scale, 0.15); await wait_seconds(0.15)
	var vfx_scene = null
	if attacking_card.attack >= 5:
		vfx_scene = HEAVY_ATTACK_VFX
	else:
		vfx_scene = NORMAL_ATTACK_VFX
	
	if vfx_scene != null:
		var vfx = vfx_scene.instantiate()
		vfx.global_position = defending_card.global_position
		card_manager.add_child(vfx) # Adiciona à cena principal
	defending_card.current_health = max(0, defending_card.current_health - attacking_card.attack)
	attacking_card.current_health = max(0, attacking_card.current_health - defending_card.attack)
	if is_instance_valid(defending_card.attribute2_label): defending_card.attribute2_label.text = str(defending_card.current_health)
	if is_instance_valid(attacking_card.attribute2_label) and attacker == "Jogador": attacking_card.attribute2_label.text = str(attacking_card.current_health)
	await wait_seconds(0.5)
	if is_instance_valid(attacking_card.card_slot_card_is_in): animate_card_to_position_and_scale(attacking_card, attacking_card.card_slot_card_is_in.global_position, attacking_card.scale, 0.15); await wait_seconds(0.15)
	attacking_card.z_index = -1
	
	if attacker == "Jogador" and get_parent().is_multiplayer_authority():
		player_cards_that_attacked_this_turn.append(attacking_card)
	
	var destroyed = false
	if attacking_card.current_health <= 0: await destroy_card(attacking_card, attacker); destroyed = true
	if is_instance_valid(defending_card) and defending_card.current_health <= 0:
		var defender_owner = "Oponente" if attacker == "Jogador" else "Jogador"; await destroy_card(defending_card, defender_owner); destroyed = true
	if destroyed: await wait_seconds(0.5)
	player_is_attacking = false
	if get_parent().is_multiplayer_authority() and not is_opponent_turn:
		phase_button.disabled = false; phase_button.visible = true

func destroy_card(card_to_destroy: Node2D, card_owner: String):
	
	if is_instance_valid(card_to_destroy) and card_to_destroy.card_type == "Criatura":
		var vfx = DESTROY_VFX.instantiate()
		vfx.global_position = card_to_destroy.global_position
		card_manager.add_child(vfx) # Adiciona à cena principal
	
	var discard_pos
	if card_owner == "Jogador":
		discard_pos = player_discard.global_position; player_cards_on_battlefield.erase(card_to_destroy)
		if card_to_destroy.card_type == "Terreno": player_lands_in_play = max(0, player_lands_in_play - card_to_destroy.energy_generation); update_energy_labels()
	else: # Oponente
		discard_pos = opponent_discard.global_position; opponent_cards_on_battlefield.erase(card_to_destroy)
		if card_to_destroy.card_type == "Terreno":
			opponent_lands_in_play = max(0, opponent_lands_in_play - card_to_destroy.energy_generation); update_energy_labels()
			if is_instance_valid(card_to_destroy.card_slot_card_is_in):
				pass
		elif card_to_destroy.card_type == "Criatura" and is_instance_valid(card_to_destroy.card_slot_card_is_in):
			pass
			
	if is_instance_valid(card_to_destroy.card_slot_card_is_in):
		var slot = card_to_destroy.card_slot_card_is_in; slot.card_in_slot = false
		var area = slot.get_node_or_null("Area2D"); 
		if is_instance_valid(area):
			var shape = area.get_node_or_null("CollisionShape2D")
			if is_instance_valid(shape): shape.disabled = false
		card_to_destroy.card_slot_card_is_in = null
		
	if card_to_destroy.has_method("set_defeated"): card_to_destroy.set_defeated(true)
	
	animate_card_to_position_and_scale(card_to_destroy, discard_pos, Constants.CARD_SMALLER_SCALE, 0.2)
	await wait_seconds(0.2)

func _on_card_played(card: Node2D):
	# Chamada pelo sinal card_played do CardManager
	player_cards_on_battlefield.append(card)

	var slot_index = -1
	var card_type = card.card_type

	if card_type == "Criatura":
		slot_index = player_creature_slots_ref.find(card.card_slot_card_is_in)
	elif card_type == "Terreno":
		slot_index = player_land_slots_ref.find(card.card_slot_card_is_in)
		player_lands_in_play += card.energy_generation
		update_energy_labels()

	# Envia RPC para o Oponente
	if slot_index != -1:
		var player_id = get_parent().name
		var opponent_id = "2" if player_id == "1" else "1"
		var opponent_path = "/root/Main/" + opponent_id
		var opponent_bm = get_node_or_null(opponent_path + "/BattleManager")
		var multiplayer_ref = get_node("/root/Main")
		var opponent_peer_id = multiplayer_ref.opponent_peer_id if multiplayer_ref else 0

		if is_instance_valid(opponent_bm) and opponent_peer_id != 0:
			opponent_bm.rpc_id(opponent_peer_id, "rpc_opponent_played_card", card.card_name, card_type, slot_index)
		else:
			printerr("ERRO (_on_card_played): Oponente BM ou Peer ID inválido.")

func animate_card_to_position_and_scale(card: Node2D, target_position: Vector2, target_scale: Vector2, speed: float):
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_QUAD); tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "global_position", target_position, speed)
	tween.tween_property(card, "scale", target_scale, speed)

func update_health_labels():
	player_health_label.text = str(player_health)
	opponent_health_label.text = str(opponent_health)

func update_energy_labels():
	player_energy_label.text = "E: " + str(player_current_energy) + "/" + str(player_lands_in_play)
	opponent_energy_label.text = "E: " + str(opponent_current_energy) + "/" + str(opponent_lands_in_play)

func _on_spell_cast_initiated(spell_card: Node2D):
	# Esta função é chamada quando o CardManager emite o sinal spell_cast_initiated
	var spell_name = spell_card.card_name

	# Determina se o feitiço tem alvo ou é global
	if spell_name == "Início da Peste":
		var restrictions = {"type": "Criatura"}
		setup_targeting_state(spell_card, 1, restrictions, true) # Alvo único, sem botão de confirmação
	elif spell_name == "Surto da Peste":
		var restrictions = {"type": "Criatura", "max_health": 2}
		setup_targeting_state(spell_card, 2, restrictions, true) # Múltiplos alvos, precisa de botão
	elif spell_name == "A Peste":
		# Feitiço global - Lógica de RPC e execução local
		var player_id = get_parent().name
		var opponent_id_str = "2" if player_id == "1" else "1"
		var opponent_bm_path = "/root/Main/" + opponent_id_str + "/BattleManager"
		var opponent_bm = get_node_or_null(opponent_bm_path)
		var multiplayer_ref = get_node("/root/Main")
		var opponent_peer_id = multiplayer_ref.opponent_peer_id if multiplayer_ref else 0

		# Enviar RPC para o oponente executar o feitiço global
		if is_instance_valid(opponent_bm) and opponent_peer_id != 0:
			opponent_bm.rpc_id(opponent_peer_id, "rpc_opponent_cast_global_spell", "A Peste")

		# Executar localmente (O AWAIT acontece dentro da função da habilidade)
		if spell_card.ability_script != null:
			await spell_card.ability_script.trigger_ability(self, spell_card, "Jogador") # Passa a carta e o dono
		else:
			print("ERRO: 'A Peste' sem ability_script!")
		reset_targeting_state() # Limpa qualquer estado residual (embora não devesse ter)
	else:
		print("ERRO: Feitiço desconhecido iniciado: ", spell_name)
		# Opcional: Devolver a carta para a mão ou destruir
		if is_instance_valid(spell_card):
			spell_card.queue_free() # Ou outra lógica de falha
		reset_targeting_state()

func remove_player_card_from_battlefield(card: Node2D):
	# Decremento de terrenos agora é feito em destroy_card
	if player_cards_on_battlefield.has(card):
		player_cards_on_battlefield.erase(card)

func _on_player_deck_clicked():
	# Esta função é chamada quando o InputManager emite o sinal player_deck_clicked
	if is_opponent_turn: return # Não pode comprar no turno do oponente

	if is_instance_valid(player_deck):
		if player_deck.drawn_card_this_turn:
			print("BattleManager: Já comprou carta neste turno.")
		else:
			# Chama o RPC para si mesmo comprar a carta
			rpc_draw_my_card()

			# Chama o RPC para o oponente ver a animação de compra dele
			var player_id = get_parent().name
			var opponent_id_str = "2" if player_id == "1" else "1"
			var opponent_bm_path = "/root/Main/" + opponent_id_str + "/BattleManager"
			var multiplayer_ref = get_node("/root/Main")
			var opponent_peer_id = multiplayer_ref.opponent_peer_id if multiplayer_ref else 0
			var opponent_bm_node = get_node_or_null(opponent_bm_path)

			if is_instance_valid(opponent_bm_node) and opponent_peer_id != 0:
				opponent_bm_node.rpc_id(opponent_peer_id, "rpc_draw_opponent_card")
			else:
				print("ERRO (_on_player_deck_clicked): Oponente BM ou Peer ID inválido.")

			player_deck.drawn_card_this_turn = true # Marca que já comprou
	else:
		print("ERRO (BattleManager): Referência ao player_deck inválida.")

func player_has_creatures() -> bool:
	for card in player_cards_on_battlefield:
		if is_instance_valid(card) and card.card_type == "Criatura": return true
	return false

func opponent_has_creatures() -> bool:
	for card in opponent_cards_on_battlefield:
		if is_instance_valid(card) and card.card_type == "Criatura": return true
	return false
	
# NOVA FUNÇÃO (Coloque no final do battle_manager.gd)
func summon_token(card_name: String, owner: String):
	
	var empty_slot = null
	var slots_array = []
	var card_to_instance = null
# 1. Selecionar os recursos corretos com base no 'owner'
	if owner == "Jogador":
		slots_array = player_creature_slots_ref
		card_to_instance = card_scene # res://scenes/card.tscn
	elif owner == "Oponente":
		slots_array = opponent_creature_slots_ref
		card_to_instance = preload("res://scenes/opponent_card.tscn")
	else:
		print("ERRO summon_token: 'owner' desconhecido: ", owner)
		return

	# 2. Encontrar um slot vazio no array correto
	for slot in slots_array:
		if is_instance_valid(slot) and not slot.card_in_slot:
			empty_slot = slot
			break
			
	if not is_instance_valid(empty_slot):
		print("BattleManager: Não há slots de criatura vazios para invocar para ", owner)
		return
		
	# 3. Instanciar VFX (Animação de Invocação)
	var vfx_instance = SUMMON_VFX_SCENE.instantiate()
	vfx_instance.global_position = empty_slot.global_position
	card_manager.add_child(vfx_instance)
	await wait_seconds(0.3) # Espera a animação de "poof"
	
	# 4. Instanciar a carta
	var new_card = card_to_instance.instantiate()
	new_card.name = "Token_" + card_name.replace(" ", "_")
	new_card.card_name = card_name
	card_manager.add_child(new_card) # Adiciona à cena principal
	
	# 5. Preencher dados do Database
	var card_data = card_database_ref.CARDS[card_name]
	new_card.attack = card_data[0]
	new_card.base_health = card_data[1]
	new_card.current_health = card_data[1]
	new_card.card_type = card_data[3]
	
	new_card.energy_cost = 0

	new_card.energy_generation = card_data[5]
	
	var card_image_path = card_database_ref.CARD_IMAGE_PATHS[card_name]
	new_card.set_card_image_texture(card_image_path)
	
	# 6. Posicionar a carta no slot
	new_card.global_position = empty_slot.global_position
	new_card.scale = Constants.CARD_SMALLER_SCALE
	new_card.z_index = -1 
	
	# Tocar animação de virar
	if new_card.has_node("AnimationPlayer"):
		new_card.animation_player.play("card_flip")
		await new_card.animation_player.animation_finished 
	
	new_card.setup_card_display()

	# 7. Atualizar estados (Manualmente, sem chamar add_player_card_to_battlefield)
	empty_slot.card_in_slot = true
	new_card.card_slot_card_is_in = empty_slot
	
	if owner == "Jogador":
		player_cards_on_battlefield.append(new_card) # Adiciona ao array local
	else: # Oponente
		opponent_cards_on_battlefield.append(new_card) # Adiciona ao array local
	
	# 8. Desabilitar colisão do slot
	var slot_area = empty_slot.get_node_or_null("Area2D")
	if is_instance_valid(slot_area):
		var slot_shape = slot_area.get_node_or_null("CollisionShape2D")
		if is_instance_valid(slot_shape): slot_shape.disabled = true


func player_card_selected_for_spell(card: Node2D):
	if player_is_targeting_spell:
		handle_spell_target_selection(card)

func _on_confirm_action_button_pressed(): # Nome corrigido
	if is_opponent_turn or player_is_attacking:
		return

	match current_combat_phase:
		CombatPhase.DECLARE_ATTACKERS:
			confirm_attackers()
		CombatPhase.DECLARE_BLOCKERS:
			confirm_blockers()
		_:
			if player_is_targeting_spell and is_instance_valid(spell_being_cast):
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

# Chamada pelo CardManager ao iniciar o feitiço
func setup_targeting_state(spell_card: Node2D, max_targets: int, restrictions: Dictionary, needs_confirmation: bool):
	player_is_targeting_spell = true
	spell_being_cast = spell_card
	current_spell_max_targets = max_targets
	current_spell_target_restrictions = restrictions
	
	# Limpa seleções anteriores
	current_spell_target_count = 0
	current_spell_targets.clear()
	
	if needs_confirmation:
		confirm_action_button.visible = true

# Desativa a UI durante a resolução de um feitiço
func disable_game_inputs():
	phase_button.disabled = true
	phase_button.visible = false
	# (Opcional: desabilitar InputManager)

# Reativa a UI
func enable_game_inputs():
	if not is_opponent_turn: # Só reativa se for turno do jogador
		phase_button.disabled = false
		phase_button.visible = true


# --- NOVA FUNÇÃO CENTRAL DE TARGETING ---
func handle_spell_target_selection(target_card: Node2D):
	# 1. Checa se o alvo já está selecionado (para removê-lo)
	if current_spell_targets.has(target_card):
		current_spell_targets.erase(target_card)
		current_spell_target_count -= 1
		target_card.modulate = Color(1, 1, 1) # Remove highlight
		print("Alvo removido.")
		return
		
	# 2. Checa se já atingimos o máximo de alvos
	if current_spell_target_count >= current_spell_max_targets:
		print("Número máximo de alvos (", current_spell_max_targets, ") já selecionado.")
		return
		
	# 3. Valida o alvo contra as restrições
	var valid_target = true
	
	# Restrição de Tipo (ex: "Criatura")
	if current_spell_target_restrictions.has("type"):
		if not (target_card.card_type == current_spell_target_restrictions.type):
			valid_target = false
			print("Alvo inválido: Tipo incorreto (Requer: ", current_spell_target_restrictions.type, ")")
			
	# Restrição de Vida Máxima (ex: "max_health": 2)
	if valid_target and current_spell_target_restrictions.has("max_health"):
		if not (target_card.current_health <= current_spell_target_restrictions.max_health):
			valid_target = false
			print("Alvo inválido: Resistência muito alta (Max: ", current_spell_target_restrictions.max_health, ")")
	
	# (Você pode adicionar mais restrições aqui, ex: "owner": "Oponente")
	
	# 4. Se for válido, adiciona
	if valid_target:
		current_spell_targets.append(target_card)
		current_spell_target_count += 1
		target_card.modulate = Color(1, 0.5, 0.5) # Highlight (avermelhado)
		print("Alvo adicionado: ", target_card.name)
		
		# 5. Se for um feitiço de ALVO ÚNICO (sem botão), dispara imediatamente
		if not confirm_action_button.visible and current_spell_target_count == current_spell_max_targets:
			if is_instance_valid(spell_being_cast) and spell_being_cast.ability_script != null:
				# Passa o ALVO (não o array) para feitiços de alvo único
				spell_being_cast.ability_script.trigger_ability(self, [target_card], spell_being_cast, "Jogador")
			else:
				print("ERRO: Feitiço de alvo único falhou.")
			
			reset_targeting_state() # Limpa o estado
	else:
		print("Alvo inválido.")


# Limpa tudo após o feitiço ser lançado ou cancelado
func reset_targeting_state():
	player_is_targeting_spell = false
	spell_being_cast = null
	current_spell_max_targets = 0
	current_spell_target_count = 0
	current_spell_target_restrictions.clear()
	confirm_action_button.visible = false
	
	# Garante que todas as cartas voltem ao normal
	for card in current_spell_targets:
		if is_instance_valid(card):
			card.modulate = Color(1, 1, 1) # Remove highlight
	current_spell_targets.clear()

# --- NOVA FUNÇÃO DE VERIFICAÇÃO DE CONDIÇÃO ---
# Verifica se a condição para "A Peste" foi atendida
func check_plague_condition() -> bool:
	
	# 1. Checa por "Rato da Peste" (jogador ou oponente)
	for card in player_cards_on_battlefield:
		if is_instance_valid(card) and card.card_name == "Rato da Peste":
			return true
	for card in opponent_cards_on_battlefield:
		if is_instance_valid(card) and card.card_name == "Rato da Peste":
			return true
			
	# 2. Checa por "marcadores Peste" (jogador ou oponente)
	for card in player_cards_on_battlefield:
		if is_instance_valid(card) and "plague_counters" in card and card.plague_counters > 0:
			return true
	for card in opponent_cards_on_battlefield:
		if is_instance_valid(card) and "plague_counters" in card and card.plague_counters > 0:
			return true
			
	# 3. Se nada for encontrado
	return false

@rpc("any_peer", "call_local")
func rpc_set_my_deck(deck_list: Array):
	# 'player_deck' é o nó "Deck" do PlayerField (o seu)
	if is_instance_valid(player_deck):
		print(get_parent().name, ": Recebendo minha lista de deck. Contagem: ", deck_list.size())
		player_deck.set_deck_list(deck_list)

# Chamada pelo Host para configurar a contagem do deck do oponente
@rpc("any_peer", "call_local")
func rpc_set_opponent_deck_size(deck_size: int):
	# 'opponent_deck' é o nó "Deck" do OpponentField (o do oponente)
	if is_instance_valid(opponent_deck):
		print(get_parent().name, ": Recebendo contagem do oponente: ", deck_size)
		opponent_deck.set_card_count(deck_size)

# Chamada pelo Host (para a mão inicial)
@rpc("any_peer", "call_local")
func rpc_draw_my_card():
	if is_instance_valid(player_deck):
		player_deck.draw_card()

# Chamada pelo Host (para a mão inicial) E pelo oponente (para compra manual)
@rpc("any_peer", "call_local")
func rpc_draw_opponent_card():
	if is_instance_valid(opponent_deck):
		opponent_deck.draw_card()

@rpc("any_peer")
func rpc_opponent_played_card(card_name: String, card_type: String, slot_index: int):
	print("Oponente jogou: ", card_name, " no slot ", slot_index)
	
	# 1. Encontrar o slot alvo (lógica antiga)
	var target_slot = null
	if card_type == "Criatura":
		if slot_index < opponent_creature_slots_ref.size():
			target_slot = opponent_creature_slots_ref[slot_index]
	elif card_type == "Terreno":
		if slot_index < opponent_land_slots_ref.size():
			target_slot = opponent_land_slots_ref[slot_index]
	
	if not is_instance_valid(target_slot) or target_slot.card_in_slot:
		print("ERRO: Slot do oponente inválido ou ocupado!")
		return
		
	# --- INÍCIO DA ALTERAÇÃO (Lógica de Animação) ---
		
	# 2. Tentar pegar a carta "verso" da mão do oponente
	var card_to_play = opponent_hand.remove_card_from_hand_by_rpc()
	
	# 3. Se a mão estava vazia (fallback), cria uma nova carta na posição do deck
	if not is_instance_valid(card_to_play):
		print("AVISO: Mão do oponente vazia. Criando carta no deck.")
		card_to_play = preload("res://scenes/opponent_card.tscn").instantiate()
		card_manager.add_child(card_to_play) # Adiciona à cena
		card_to_play.global_position = opponent_deck.global_position # Posição inicial
	
	# 4. Preencher os dados da carta (reutilizando a instância 'card_to_play')
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
	
	# 5. Atualizar estados (antes da animação)
	target_slot.card_in_slot = true
	card_to_play.card_slot_card_is_in = target_slot
	opponent_cards_on_battlefield.append(card_to_play)
	
	# 6. Atualizar energia do oponente
	if card_to_play.card_type == "Terreno":
		opponent_lands_in_play += card_to_play.energy_generation
	else: # Se for criatura, deduz o custo
		opponent_current_energy -= card_to_play.energy_cost
	update_energy_labels()
	
	# 7. Animar a carta (verso) da mão/deck para o slot
	card_to_play.z_index = 10 # Traz para frente durante a animação
	await animate_card_to_position_and_scale(card_to_play, target_slot.global_position, Constants.CARD_SMALLER_SCALE, 0.3)
	card_to_play.z_index = -1 # Coloca de volta no slot
	
	# 8. Tocar animação de virar (DEPOIS que a animação de movimento terminar)
	if card_to_play.has_node("AnimationPlayer"):
		card_to_play.animation_player.play("card_flip")
		await card_to_play.animation_player.animation_finished 
	
	card_to_play.setup_card_display()
	
@rpc("any_peer")
func rpc_receive_attack(attacker_slot_index: int, defender_slot_index: int):
	# Esta função é chamada no Defensor (o oponente)
	
	var attacking_card: Node2D = null # A carta do oponente
	var defending_card: Node2D = null # A nossa carta

	# Encontra a carta atacante (que para nós, está em um slot de oponente)
	if attacker_slot_index >= 0 and attacker_slot_index < opponent_creature_slots_ref.size():
		var attacker_slot_node = opponent_creature_slots_ref[attacker_slot_index]
		for card in opponent_cards_on_battlefield:
			if card.card_slot_card_is_in == attacker_slot_node:
				attacking_card = card
				break
				
	# Encontra a carta defensora (que para nós, é uma de nossas cartas)
	if defender_slot_index >= 0 and defender_slot_index < player_creature_slots_ref.size():
		var defender_slot_node = player_creature_slots_ref[defender_slot_index]
		for card in player_cards_on_battlefield:
			if card.card_slot_card_is_in == defender_slot_node:
				defending_card = card
				break

	if is_instance_valid(attacking_card) and is_instance_valid(defending_card):
		# Chama o ataque localmente com a perspectiva invertida ("Oponente" é o atacante)
		await attack(attacking_card, defending_card, "Oponente")
	else:
		print("ERRO RPC: rpc_receive_attack não encontrou as cartas.")

@rpc("any_peer")
func rpc_receive_direct_attack(attacker_slot_index: int):
	# Esta função é chamada no Defensor (o oponente)
	var attacking_card: Node2D = null

	# Encontra a carta atacante (que para nós, está em um slot de oponente)
	if attacker_slot_index >= 0 and attacker_slot_index < opponent_creature_slots_ref.size():
		var attacker_slot_node = opponent_creature_slots_ref[attacker_slot_index]
		for card in opponent_cards_on_battlefield:
			if card.card_slot_card_is_in == attacker_slot_node:
				attacking_card = card
				break
	
	if is_instance_valid(attacking_card):
		# Chama o ataque direto localmente com a perspectiva invertida
		await direct_attack(attacking_card, "Oponente")
	else:
		print("ERRO RPC: rpc_receive_direct_attack não encontrou a carta.")


@rpc("any_peer")
func rpc_opponent_cast_targeted_spell(spell_name: String, target_data_array: Array):
	print("Oponente está a lançar o feitiço com alvo: ", spell_name)

	# 1. Obter dados do feitiço
	if not card_database_ref.CARDS.has(spell_name): return
	var card_data = card_database_ref.CARDS[spell_name]
	var energy_cost = card_data[4]
	var ability_path = card_data[6]
	if ability_path == null: return

	# 2. Simular o oponente a jogar a carta
	opponent_current_energy -= energy_cost
	update_energy_labels()
	var fake_spell_card = opponent_hand.remove_card_from_hand_by_rpc()
	if not is_instance_valid(fake_spell_card):
		fake_spell_card = preload("res://scenes/opponent_card.tscn").instantiate()
		card_manager.add_child(fake_spell_card)
		fake_spell_card.visible = false

	# 3. Construir a lista de alvos local
	var local_target_nodes = []
	for target_data in target_data_array:
		var target_node = null
		var target_owner = target_data["owner"]
		var target_slot_index = target_data["slot_index"]
		
		# Inverte a perspetiva!
		if target_owner == "Jogador":
			# O alvo era uma carta do "Jogador" (o lançador)
			# Para nós, é uma carta do "Oponente"
			target_node = find_card_in_slot_array(opponent_creature_slots_ref, opponent_cards_on_battlefield, target_slot_index)
		elif target_owner == "Oponente":
			# O alvo era uma carta do "Oponente" (o alvo do lançador)
			# Para nós, é uma carta do "Jogador"
			target_node = find_card_in_slot_array(player_creature_slots_ref, player_cards_on_battlefield, target_slot_index)
			
		if is_instance_valid(target_node):
			local_target_nodes.append(target_node)

	# 4. Carregar e disparar a habilidade
	var ability_script = load(ability_path).new()
	await ability_script.trigger_ability(self, local_target_nodes, fake_spell_card, "Oponente")

# RPC para feitiços globais (sem alvo)
@rpc("any_peer")
func rpc_opponent_cast_global_spell(spell_name: String):
	print("Oponente está a lançar o feitiço global: ", spell_name)

	# 1. Obter dados do feitiço
	if not card_database_ref.CARDS.has(spell_name):
		print("ERRO RPC: Oponente lançou feitiço desconhecido: ", spell_name)
		return
		
	var card_data = card_database_ref.CARDS[spell_name]
	var energy_cost = card_data[4]
	var ability_path = card_data[6]
	
	if ability_path == null:
		print("ERRO RPC: Feitiço sem script de habilidade: ", spell_name)
		return

	# 2. Simular o oponente a jogar a carta
	opponent_current_energy -= energy_cost
	update_energy_labels()
	
	# Pega a carta "verso" da mão dele
	var fake_spell_card = opponent_hand.remove_card_from_hand_by_rpc()
	
	if not is_instance_valid(fake_spell_card):
		# Fallback se a mão estiver dessincronizada
		fake_spell_card = preload("res://scenes/opponent_card.tscn").instantiate()
		card_manager.add_child(fake_spell_card)
		fake_spell_card.visible = false # Não precisamos de a mostrar
	
	# 3. Carregar o script da habilidade
	var ability_script = load(ability_path).new()
	
	# 4. Disparar a habilidade, passando "Oponente" como o dono
	# O 'await' é crucial para que o jogo espere que o feitiço termine
	await ability_script.trigger_ability(self, fake_spell_card, "Oponente")

func find_card_in_slot_array(slot_array: Array, card_array: Array, slot_index: int) -> Node2D:
	if slot_index < 0 or slot_index >= slot_array.size():
		return null
		
	var target_slot_node = slot_array[slot_index]
	
	for card in card_array:
		if card.card_slot_card_is_in == target_slot_node:
			return card
			
	return null

func update_ui_for_phase():
	if not is_instance_valid(phase_button) or not is_instance_valid(confirm_action_button):
		return

	# Controla visibilidade/texto baseado na fase e se é nosso turno
	if is_opponent_turn:
		phase_button.visible = false
		confirm_action_button.visible = false
		return

	confirm_action_button.visible = false # Esconde por padrão

	match current_combat_phase:
		CombatPhase.NONE:
			phase_button.text = "Iniciar Combate"
			phase_button.disabled = false
			phase_button.visible = true
			confirm_action_button.visible = player_is_targeting_spell # Mostra se estiver mirando feitiço
		CombatPhase.BEGIN_COMBAT:
			phase_button.text = "Declarar Atacantes"
			phase_button.disabled = false
			phase_button.visible = true
		CombatPhase.DECLARE_ATTACKERS:
			phase_button.text = "Declarar Atacantes" # Ou esconder?
			phase_button.disabled = true
			phase_button.visible = true # Ou false?
			confirm_action_button.text = "Confirmar Atacantes"
			confirm_action_button.visible = true
		CombatPhase.DECLARE_BLOCKERS:
			phase_button.text = "Esperando Bloqueio..." # Ou esconder
			phase_button.disabled = true
			phase_button.visible = true # Ou false?
			# Botão de confirmação só aparece para o defensor
			confirm_action_button.visible = false # (Lógica para o defensor será separada)
		CombatPhase.COMBAT_DAMAGE:
			phase_button.text = "Dano Resolvido" # Ou esconder
			phase_button.disabled = true
			phase_button.visible = true # Ou false?
		CombatPhase.END_COMBAT:
			phase_button.text = "Finalizar Turno"
			phase_button.disabled = false
			phase_button.visible = true

# Função auxiliar para limpar indicadores visuais
func clear_all_combat_indicators():
	for card in player_cards_on_battlefield:
		if is_instance_valid(card) and card.has_method("hide_combat_indicators"):
			card.hide_combat_indicators()
	for card in opponent_cards_on_battlefield:
		if is_instance_valid(card) and card.has_method("hide_combat_indicators"):
			card.hide_combat_indicators()

# Função auxiliar para obter índices dos atacantes para RPC
func get_attacker_indices() -> Array[int]:
	var indices: Array[int] = []
	for attacker in declared_attackers:
		if is_instance_valid(attacker) and is_instance_valid(attacker.card_slot_card_is_in):
			var index = player_creature_slots_ref.find(attacker.card_slot_card_is_in)
			if index != -1:
				indices.append(index)
	return indices

# --- RPCs para sincronizar combate ---
@rpc("any_peer")
func rpc_declare_attackers(attacker_indices: Array[int]):
	# Chamado no oponente (defensor) quando o jogador confirma atacantes
	print("RPC Recebido: Atacantes declarados nos índices: ", attacker_indices)
	declared_attackers.clear()
	for index in attacker_indices:
		var card = find_card_in_slot_array(opponent_creature_slots_ref, opponent_cards_on_battlefield, index)
		if is_instance_valid(card):
			declared_attackers.append(card)
			card.show_attack_indicator(true) # Mostra indicador no oponente
		else:
			printerr("RPC rpc_declare_attackers: Não foi possível encontrar atacante no índice ", index)

	# Agora o jogador local (que recebeu o RPC) está na fase de declarar bloqueadores
	enter_declare_blockers_phase_as_defender()

func enter_declare_blockers_phase_as_defender():
	print("Entrando na Fase: Declarar Bloqueadores (Como Defensor)")
	set_current_combat_phase(CombatPhase.DECLARE_BLOCKERS)
	# TODO: Habilitar seleção de bloqueadores (clicar nas suas cartas, depois no atacante a bloquear)
	# TODO: Atualizar UI para mostrar botão "Confirmar Bloqueadores"
	update_ui_for_phase_defender() # Função separada para UI do defensor

func update_ui_for_phase_defender():
	# Similar a update_ui_for_phase, mas para o estado de defesa
	if not is_instance_valid(phase_button) or not is_instance_valid(confirm_action_button):
		return

	phase_button.visible = false # Esconde botão de fase principal
	confirm_action_button.text = "Confirmar Bloqueadores"
	confirm_action_button.disabled = false # Habilita para o defensor confirmar
	confirm_action_button.visible = true

# Placeholder para RPC de bloqueadores (a ser enviado pelo defensor)
# @rpc("any_peer")
# func rpc_declare_blockers(blocker_data: Dictionary):
	# Chamado no atacante quando o defensor confirma bloqueios
	# receive_blockers(blocker_data)

# Em scripts/battle_manager.gd

func handle_blocker_declaration_click(clicked_card: Node2D):
	# Verifica se é uma carta do jogador (potencial bloqueador)
	if player_cards_on_battlefield.has(clicked_card) and clicked_card.card_type == "Criatura":
		var potential_blocker = clicked_card

		# Se já estava selecionado, deseleciona
		if currently_selected_blocker == potential_blocker:
			potential_blocker.show_block_indicator(false)
			currently_selected_blocker = null
		# Se outro bloqueador estava selecionado, deseleciona o anterior
		elif is_instance_valid(currently_selected_blocker):
			currently_selected_blocker.show_block_indicator(false)
			currently_selected_blocker = potential_blocker
			potential_blocker.show_block_indicator(true)
		# Se nenhum estava selecionado, seleciona este
		else:
			currently_selected_blocker = potential_blocker
			potential_blocker.show_block_indicator(true)

	# Verifica se é uma carta do oponente (atacante declarado) E se temos um bloqueador selecionado
	elif opponent_cards_on_battlefield.has(clicked_card) and is_instance_valid(currently_selected_blocker):
		var attacker_to_block = clicked_card

		# Verifica se a carta clicada é realmente um dos atacantes declarados
		if declared_attackers.has(attacker_to_block):
			print("Declarando bloqueio: ", currently_selected_blocker.card_name, " -> ", attacker_to_block.card_name)

			# Remove bloqueio anterior do bloqueador selecionado, se houver
			if blocker_assignments.has(currently_selected_blocker):
				var previous_attacker = blocker_assignments[currently_selected_blocker]
				if declared_blockers.has(previous_attacker) and declared_blockers[previous_attacker].has(currently_selected_blocker):
					declared_blockers[previous_attacker].erase(currently_selected_blocker)
					if declared_blockers[previous_attacker].is_empty():
						declared_blockers.erase(previous_attacker) # Limpa entrada se não houver mais bloqueadores

			# Associa o bloqueador ao novo atacante
			blocker_assignments[currently_selected_blocker] = attacker_to_block

			# Adiciona o bloqueador à lista do atacante
			if not declared_blockers.has(attacker_to_block):
				declared_blockers[attacker_to_block] = []
			# Evita adicionar duplicatas se clicar várias vezes
			if not declared_blockers[attacker_to_block].has(currently_selected_blocker):
				declared_blockers[attacker_to_block].append(currently_selected_blocker)

			# TODO: Adicionar feedback visual (ex: linha, mover carta)

			# Limpa a seleção atual
			currently_selected_blocker.show_block_indicator(false)
			currently_selected_blocker = null
		else:
			print("Clique inválido: Carta não está atacando.")
			# Opcional: Desselecionar bloqueador atual se clicar em não-atacante?
			# if is_instance_valid(currently_selected_blocker):
			# 	 currently_selected_blocker.show_block_indicator(false)
			# 	 currently_selected_blocker = null

	# Se clicar em um atacante sem ter um bloqueador selecionado, não faz nada
	elif opponent_cards_on_battlefield.has(clicked_card) and not is_instance_valid(currently_selected_blocker):
		print("Selecione uma de suas criaturas primeiro para declarar bloqueio.")
		
func _on_player_card_clicked(card: Node2D):
	# Se estamos declarando bloqueadores E é nosso turno (atuando como defensor)
	if current_combat_phase == CombatPhase.DECLARE_BLOCKERS and not is_opponent_turn: # Garante que é o defensor local
		handle_blocker_declaration_click(card)
	# Se estamos selecionando alvo para feitiço (lógica antiga)
	elif player_is_targeting_spell:
		handle_spell_target_selection(card)
	# (Não faz nada em outras fases por enquanto)

func _on_opponent_card_clicked(card: Node2D):
	# Se estamos declarando bloqueadores E é nosso turno (atuando como defensor)
	if current_combat_phase == CombatPhase.DECLARE_BLOCKERS and not is_opponent_turn: # Garante que é o defensor local
		handle_blocker_declaration_click(card)
	# Se estamos selecionando alvo para feitiço (lógica antiga)
	elif player_is_targeting_spell:
		handle_spell_target_selection(card)
	# Se estamos em fase de ataque normal (Lógica antiga de ataque direto/seleção - remover ou ajustar depois)
	# elif not is_opponent_turn and not player_is_attacking and current_combat_phase != CombatPhase.DECLARE_ATTACKERS:
		# Lógica de ataque direto / seleção de alvo para ataque (PRECISA SER AJUSTADA/REMOVIDA POIS O ATAQUE AGORA É POR FASE)
		# ... (código antigo comentado ou removido) ...
	# (Não faz nada em outras fases por enquanto)

# Em scripts/battle_manager.gd

func get_opponent_battle_manager() -> Node:
	var player_id = get_parent().name
	var opponent_id_str = "2" if player_id == "1" else "1"
	var opponent_bm_path = "/root/Main/" + opponent_id_str + "/BattleManager"
	return get_node_or_null(opponent_bm_path)

func get_opponent_peer_id() -> int:
	var multiplayer_ref = get_node("/root/Main")
	return multiplayer_ref.opponent_peer_id if multiplayer_ref else 0

func _apply_creature_damage(attacking_card: Node2D, defending_card: Node2D) -> Dictionary:
	var results = {"attacker_died": false, "defender_died": false}
	if not is_instance_valid(attacking_card) or not is_instance_valid(defending_card):
		return results # Retorna se alguma carta for inválida

	# Aplica dano
	defending_card.current_health = max(0, defending_card.current_health - attacking_card.attack)
	attacking_card.current_health = max(0, attacking_card.current_health - defending_card.attack)

	# Atualiza labels de vida (se existirem)
	if defending_card.has_node("Attribute2"): # Assumindo que Attribute2 é o label de vida
		defending_card.attribute2_label.text = str(defending_card.current_health)
	if attacking_card.has_node("Attribute2"):
		attacking_card.attribute2_label.text = str(attacking_card.current_health)

	# Verifica mortes
	if attacking_card.current_health <= 0:
		results["attacker_died"] = true
	if defending_card.current_health <= 0:
		results["defender_died"] = true

	return results

# Aplica dano direto ao jogador oponente
func _apply_direct_damage(attacking_card: Node2D) -> void:
	if not is_instance_valid(attacking_card):
		return
	opponent_health = max(0, opponent_health - attacking_card.attack)
	# A atualização do label será feita uma vez no final da resolução
