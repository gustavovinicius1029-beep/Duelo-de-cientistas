extends Node

var end_turn_button
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
var confirm_targets_button
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

var input_manager_ref # Adicione se não existir

func _ready(): # Ou func initialize_references():
	await get_tree().process_frame

	if not get_parent().is_multiplayer_authority():
		return

	var player_id = get_parent().name
	var opponent_id = "2" if player_id == "1" else "1"
	var opponent_path = "/root/Main/" + opponent_id
	var local_parent = get_parent()

	# Obter Referências
	end_turn_button = local_parent.get_node("EndTurnButton")
	battle_timer = local_parent.get_node_or_null("BattleTimer") # Use or_null se removeu o timer
	player_deck = local_parent.get_node("Deck")
	card_manager = local_parent.get_node("CardManager") # Necessário para conectar
	player_health_label = local_parent.get_node("PlayerHealthLabel")
	player_discard = local_parent.get_node("PlayerDiscard")
	player_energy_label = local_parent.get_node("PlayerEnergyLabel")
	confirm_targets_button = local_parent.get_node("ConfirmTargetsButton")
	player_slots_container = local_parent.get_node("PlayerCardSlots")
	input_manager_ref = local_parent.get_node("InputManager") # Necessário para conectar

	opponent_deck = get_node(opponent_path + "/Deck")
	opponent_hand = get_node(opponent_path + "/OpponentHand")
	opponent_health_label = get_node(opponent_path + "/OpponentHealthLabel")
	opponent_discard = get_node(opponent_path + "/OpponentDiscard")
	opponent_energy_label = get_node(opponent_path + "/OpponentEnergyLabel")

	# Lógica original
	update_health_labels()
	update_energy_labels()
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	if is_instance_valid(confirm_targets_button):
		confirm_targets_button.pressed.connect(_on_confirm_targets_button_pressed)

	# --- NOVAS CONEXÕES DE SINAL ---
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
	# --- FIM DAS NOVAS CONEXÕES ---

	if is_instance_valid(opponent_deck):
		opponent_deck.set_process(false)

	# Pega referências para os slots
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
	end_turn_button = get_node(player_path + "/EndTurnButton")
	battle_timer = get_node(player_path + "/BattleTimer")
	player_deck = get_node(player_path + "/Deck")
	card_manager = get_node(player_path + "/CardManager")
	player_health_label = get_node(player_path + "/PlayerHealthLabel")
	player_discard = get_node(player_path + "/PlayerDiscard")
	player_energy_label = get_node(player_path + "/PlayerEnergyLabel")
	confirm_targets_button = get_node(player_path + "/ConfirmTargetsButton")
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
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	
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

func _on_end_turn_button_pressed():

	start_turn("Oponente") 
	
	# 2. Encontra o BattleManager do oponente e o peer_id
	var player_id = get_parent().name 
	var opponent_id_str = "2" if player_id == "1" else "1"
	var opponent_bm_path = "/root/Main/" + opponent_id_str + "/BattleManager"
	var opponent_bm = get_node_or_null(opponent_bm_path)
	
	# Pega a referência do script multiplayer para saber o ID do oponente
	var multiplayer_ref = get_node("/root/Main") 
	var opponent_peer_id = multiplayer_ref.opponent_peer_id
	
	# 3. Envia RPC para o oponente iniciar o turno dele
	if is_instance_valid(opponent_bm):
		opponent_bm.rpc_id(opponent_peer_id, "start_turn", "Jogador")
	else:
		print("ERRO: Não foi possível encontrar o BattleManager do oponente para passar o turno.")

@rpc("any_peer", "call_local")
func start_turn(player_or_opponent: String):
	print("Iniciando turno de: ", player_or_opponent)
	if player_or_opponent == "Jogador":
		is_opponent_turn = false
		player_played_land_this_turn = false
		player_current_energy = player_lands_in_play
		player_cards_that_attacked_this_turn.clear()
		update_energy_labels()
		player_deck.reset_draw()
		end_turn_button.disabled = false; end_turn_button.visible = true
	elif player_or_opponent == "Oponente":
		is_opponent_turn = true
		opponent_played_land_this_turn = false
		opponent_current_energy = opponent_lands_in_play
		update_energy_labels()
		if is_instance_valid(end_turn_button):
			end_turn_button.disabled = true
			end_turn_button.visible = false


# --- FUNÇÃO try_play_opponent_land CORRIGIDA ---


func wait_seconds(time: float):
	battle_timer.wait_time = time; battle_timer.start(); await battle_timer.timeout

func direct_attack(attacking_card: Node2D, attacker: String):
	player_is_attacking = true; end_turn_button.disabled = true; end_turn_button.visible = false
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
		end_turn_button.disabled = false; end_turn_button.visible = true

func attack(attacking_card: Node2D, defending_card: Node2D, attacker: String):
	player_is_attacking = true; end_turn_button.disabled = true; end_turn_button.visible = false
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
		end_turn_button.disabled = false; end_turn_button.visible = true

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
	
	animate_card_to_position_and_scale(card_to_destroy, discard_pos, card_manager.CARD_SMALLER_SCALE, 0.2)
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
		setup_targeting_state(spell_card, 1, restrictions, false) # Alvo único, sem botão de confirmação
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

# Chamada pelo InputManager quando jogador clica em carta oponente
# Chamada pelo InputManager quando jogador clica em carta oponente
func _on_opponent_card_clicked(defending_card: Node2D):
	# Se estamos selecionando alvo para feitiço, usa a lógica de targeting
	if player_is_targeting_spell:
		handle_spell_target_selection(defending_card)
		return # Pula a lógica de ataque

	# Lógica original de ataque
	if is_opponent_turn or player_is_attacking: return
	var attacking_card = card_manager.selected_monster # Pega do CardManager
	if is_instance_valid(attacking_card) and player_cards_on_battlefield.has(attacking_card):
		if is_instance_valid(defending_card) and opponent_cards_on_battlefield.has(defending_card):
			if defending_card.card_type == "Criatura":
				if not player_cards_that_attacked_this_turn.has(attacking_card):
					# Encontrar índices
					var attacker_slot_node = attacking_card.card_slot_card_is_in
					var defender_slot_node = defending_card.card_slot_card_is_in
					var attacker_slot_index = player_creature_slots_ref.find(attacker_slot_node)
					var defender_slot_index = opponent_creature_slots_ref.find(defender_slot_node)

					if attacker_slot_index == -1 or defender_slot_index == -1:
						print("ERRO: Não foi possível encontrar os índices de slot para o ataque.")
						return

					# Encontrar o BattleManager do oponente e o peer_id
					var player_id = get_parent().name
					var opponent_id_str = "2" if player_id == "1" else "1"
					var opponent_bm_path = "/root/Main/" + opponent_id_str + "/BattleManager"
					var opponent_bm = get_node_or_null(opponent_bm_path)
					var multiplayer_ref = get_node("/root/Main")
					var opponent_peer_id = multiplayer_ref.opponent_peer_id if multiplayer_ref else 0

					# Enviar RPC para o oponente executar o ataque
					if is_instance_valid(opponent_bm) and opponent_peer_id != 0:
						opponent_bm.rpc_id(opponent_peer_id, "rpc_receive_attack", attacker_slot_index, defender_slot_index)
					else:
						print("ERRO (_on_opponent_card_clicked): Oponente BM ou Peer ID inválido.")

					# Executar o ataque localmente
					card_manager.unselect_selected_monster() # Pede ao CardManager para deselecionar visualmente
					await attack(attacking_card, defending_card, "Jogador")
				# else: # Já atacou (não faz nada)
			# else: # Alvo inválido (não é criatura)
		else:
			if is_instance_valid(card_manager): card_manager.unselect_selected_monster()
	else:
		if is_instance_valid(card_manager): card_manager.unselect_selected_monster()

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
	new_card.scale = card_manager.CARD_SMALLER_SCALE
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

func _on_confirm_targets_button_pressed():
	if player_is_targeting_spell and is_instance_valid(spell_being_cast):
		if spell_being_cast.ability_script != null:
			
			# --- INÍCIO DA ALTERAÇÃO ---
			var spell_name = spell_being_cast.card_name
			var target_data_array = []
			
			# 1. Construir o array de dados dos alvos
			for target in current_spell_targets:
				var target_owner = ""
				var target_slot_index = -1
				
				if player_cards_on_battlefield.has(target):
					target_owner = "Jogador"
					# Assumindo que feitiços com alvo só podem atingir criaturas
					target_slot_index = player_creature_slots_ref.find(target.card_slot_card_is_in)
				elif opponent_cards_on_battlefield.has(target):
					target_owner = "Oponente"
					target_slot_index = opponent_creature_slots_ref.find(target.card_slot_card_is_in)
					
				if target_slot_index != -1:
					target_data_array.append({"owner": target_owner, "slot_index": target_slot_index})
				else:
					print("AVISO: Não foi possível encontrar o índice de slot para o alvo: ", target.name)

			# 2. Encontrar o oponente e enviar o RPC
			var player_id = get_parent().name 
			var opponent_id_str = "2" if player_id == "1" else "1"
			var opponent_bm_path = "/root/Main/" + opponent_id_str + "/BattleManager"
			var opponent_bm = get_node_or_null(opponent_bm_path)
			var multiplayer_ref = get_node("/root/Main") 
			var opponent_peer_id = multiplayer_ref.opponent_peer_id
			
			if is_instance_valid(opponent_bm):
				opponent_bm.rpc_id(opponent_peer_id, "rpc_opponent_cast_targeted_spell", spell_name, target_data_array)

			# 3. Executar a habilidade localmente
			await spell_being_cast.ability_script.trigger_ability(self, current_spell_targets, spell_being_cast, "Jogador")
			# --- FIM DA ALTERAÇÃO ---
			
		else:
			print("ERRO: Feitiço sem ability_script!")
			enable_game_inputs() # Failsafe
		
		reset_targeting_state()
	else:
		reset_targeting_state() # Failsafe

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
		confirm_targets_button.visible = true

# Desativa a UI durante a resolução de um feitiço
func disable_game_inputs():
	end_turn_button.disabled = true
	end_turn_button.visible = false
	# (Opcional: desabilitar InputManager)

# Reativa a UI
func enable_game_inputs():
	if not is_opponent_turn: # Só reativa se for turno do jogador
		end_turn_button.disabled = false
		end_turn_button.visible = true


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
		if not confirm_targets_button.visible and current_spell_target_count == current_spell_max_targets:
			if is_instance_valid(spell_being_cast) and spell_being_cast.ability_script != null:
				# Passa o ALVO (não o array) para feitiços de alvo único
				spell_being_cast.ability_script.trigger_ability(self, target_card, spell_being_cast)
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
	confirm_targets_button.visible = false
	
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
	await animate_card_to_position_and_scale(card_to_play, target_slot.global_position, card_manager.CARD_SMALLER_SCALE, 0.3)
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
