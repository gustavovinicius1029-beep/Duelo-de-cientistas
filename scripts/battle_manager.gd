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

const OPPONENT_CARD_MOVE_SPEED = 0.2
const OPPONENT_STARTING_HAND_SIZE = 5
const OPPONENT_TURN_TIME = 1

# --- Constantes de Jogo ---
const BATTLE_POS_OFFSET_Y = 25

# --- Variáveis de Estado ---
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

# Arrays de slots (populados no _ready)
var player_creature_slots_ref: Array = []
var player_land_slots_ref: Array = []
var opponent_creature_slots_ref: Array = []
var empty_opponent_creature_card_slots: Array = [] # (Vem do script antigo)
var empty_opponent_land_card_slots: Array = [] # (Vem do script antigo)

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

func _ready():
	
	await get_tree().process_frame
	
	if not get_parent().is_multiplayer_authority():
		return 
	
	# Pega o nome do nosso "campo" pai ("1" ou "2")
	var player_id = get_parent().name 
	# O oponente é o "outro" número
	var opponent_id = "2" if player_id == "1" else "1"
	
	# Caminho para os nós do oponente
	var opponent_path = "/root/Main/" + opponent_id

	# --- INÍCIO DA CORREÇÃO ---
	# Referências locais (usando get_parent() para pegar siblings)
	# "get_parent()" aqui se refere ao nó "1" (PlayerField)
	var local_parent = get_parent()
	end_turn_button = local_parent.get_node("EndTurnButton")
	battle_timer = local_parent.get_node("BattleTimer")
	player_deck = local_parent.get_node("Deck")
	card_manager = local_parent.get_node("CardManager")
	player_health_label = local_parent.get_node("PlayerHealthLabel")
	player_discard = local_parent.get_node("PlayerDiscard")
	player_energy_label = local_parent.get_node("PlayerEnergyLabel")
	confirm_targets_button = local_parent.get_node("ConfirmTargetsButton")
	player_slots_container = local_parent.get_node("PlayerCardSlots")

	# Referências remotas (dentro do OpponentField - aqui usamos caminho absoluto)
	opponent_deck = get_node(opponent_path + "/Deck")
	opponent_hand = get_node(opponent_path + "/OpponentHand")
	opponent_health_label = get_node(opponent_path + "/OpponentHealthLabel")
	opponent_discard = get_node(opponent_path + "/OpponentDiscard")
	opponent_energy_label = get_node(opponent_path + "/OpponentEnergyLabel")
	# --- FIM DA CORREÇÃO ---

	# --- Lógica original do _ready() (agora podemos usá-la) ---
	update_health_labels()
	update_energy_labels()
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	
	# Desabilita o oponente
	opponent_deck.set_process(false) 
	
	# Pega referências para os slots (lógica antiga ainda funciona)
	# (Já temos 'player_slots_container' da correção acima)
	for i in range(player_slots_container.get_child_count()):
		var slot = player_slots_container.get_child(i)
		if slot.card_slot_type == "Criatura":
			player_creature_slots_ref.append(slot)
		else:
			player_land_slots_ref.append(slot)
	
	var opponent_creature_slots = get_node(opponent_path + "/OpponentCardSlots")
	for i in range(opponent_creature_slots.get_child_count()):
		opponent_creature_slots_ref.append(opponent_creature_slots.get_child(i))

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
	end_turn_button.disabled = true; end_turn_button.visible = false
	is_opponent_turn = true
	player_cards_that_attacked_this_turn.clear()
	start_turn("Oponente")

func start_turn(player_or_opponent: String):
	print("Iniciando turno de: ", player_or_opponent)
	if player_or_opponent == "Jogador":
		is_opponent_turn = false
		player_played_land_this_turn = false
		player_current_energy = player_lands_in_play
		update_energy_labels()
		player_deck.reset_draw()
		end_turn_button.disabled = false; end_turn_button.visible = true
	elif player_or_opponent == "Oponente":
		is_opponent_turn = true
		opponent_played_land_this_turn = false
		opponent_current_energy = opponent_lands_in_play
		update_energy_labels()


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
	player_is_attacking = false; end_turn_button.disabled = false; end_turn_button.visible = true


func attack(attacking_card: Node2D, defending_card: Node2D, attacker: String):
	player_is_attacking = true; end_turn_button.disabled = true; end_turn_button.visible = false
	attacking_card.z_index = 5
	var target_pos = defending_card.global_position + Vector2(0, BATTLE_POS_OFFSET_Y)
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
	if attacker == "Jogador": player_cards_that_attacked_this_turn.append(attacking_card)
	var destroyed = false
	if attacking_card.current_health <= 0: await destroy_card(attacking_card, attacker); destroyed = true
	if is_instance_valid(defending_card) and defending_card.current_health <= 0:
		var defender_owner = "Oponente" if attacker == "Jogador" else "Jogador"; await destroy_card(defending_card, defender_owner); destroyed = true
	if destroyed: await wait_seconds(0.5)
	player_is_attacking = false; end_turn_button.disabled = false; end_turn_button.visible = true


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
			if is_instance_valid(card_to_destroy.card_slot_card_is_in): empty_opponent_land_card_slots.append(card_to_destroy.card_slot_card_is_in)
		elif card_to_destroy.card_type == "Criatura" and is_instance_valid(card_to_destroy.card_slot_card_is_in):
			empty_opponent_creature_card_slots.append(card_to_destroy.card_slot_card_is_in)
			
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

func add_player_card_to_battlefield(card: Node2D):
	player_cards_on_battlefield.append(card)
	if card.card_type == "Terreno":
		player_lands_in_play += card.energy_generation
		update_energy_labels() # Atualiza display do max

func remove_player_card_from_battlefield(card: Node2D):
	# Decremento de terrenos agora é feito em destroy_card
	if player_cards_on_battlefield.has(card):
		player_cards_on_battlefield.erase(card)

# Chamada pelo InputManager quando jogador clica em carta oponente
# Chamada pelo InputManager quando jogador clica em carta oponente
func opponent_card_selected(defending_card: Node2D):
	
	# --- INÍCIO DA MUDANÇA: LÓGICA DE TARGETING ---
	# Se estamos selecionando alvo para feitiço, usa a nova lógica
	if player_is_targeting_spell:
		handle_spell_target_selection(defending_card)
		return # Pula a lógica de ataque
	# --- FIM DA MUDANÇA ---
	
	# Lógica original de ataque (baseada no seu script original)
	if is_opponent_turn or player_is_attacking: return
	var attacking_card = card_manager.selected_monster
	if is_instance_valid(attacking_card) and player_cards_on_battlefield.has(attacking_card):
		if is_instance_valid(defending_card) and opponent_cards_on_battlefield.has(defending_card):
			if defending_card.card_type == "Criatura": # Só pode atacar criaturas
				if not player_cards_that_attacked_this_turn.has(attacking_card):
					player_is_attacking = true; card_manager.unselect_selected_monster()
					await attack(attacking_card, defending_card, "Jogador")
					# player_is_attacking é resetado dentro de attack()
				else: pass # Já atacou
			else: pass # Alvo inválido
		else: card_manager.unselect_selected_monster()
	else: card_manager.unselect_selected_monster()


# --- Funções Auxiliares de Verificação ---
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
	# Por enquanto, só o jogador invoca
	if owner != "Jogador":
		print("Invocação de token pelo oponente não implementada.")
		return

	# 1. Encontrar um slot de criatura vazio
	var empty_slot = null
	for slot in player_slots_container.get_children():
		if is_instance_valid(slot) and slot.card_slot_type == "Criatura" and not slot.card_in_slot:
			empty_slot = slot
			break
			
	if not is_instance_valid(empty_slot):
		print("BattleManager: Não há slots de criatura vazios para invocar!")
		return
		
	var vfx_instance = SUMMON_VFX_SCENE.instantiate()
	vfx_instance.global_position = empty_slot.global_position
	card_manager.add_child(vfx_instance)
	await wait_seconds(0.3)
	# 2. Instanciar a carta (baseado no deck.gd)
	var new_card = card_scene.instantiate()
	new_card.name = "Card_" + card_name
	new_card.card_name = card_name
	card_manager.add_child(new_card) # Adiciona à cena principal
	
	var card_data = card_database_ref.CARDS[card_name]
			
	new_card.attack = card_data[0]
	new_card.base_health = card_data[1]
	new_card.current_health = card_data[1]
	new_card.card_type = card_data[3]
	new_card.energy_cost = card_data[4]
	new_card.energy_generation = card_data[5]
	
	var card_image_path = card_database_ref.CARD_IMAGE_PATHS[card_name]
	new_card.set_card_image_texture(card_image_path)
	
	# 3. Posicionar a carta no slot
	new_card.global_position = empty_slot.global_position
	new_card.scale = card_manager.CARD_SMALLER_SCALE # Usa a escala do CardManager
	new_card.z_index = -1 
	if new_card.has_node("AnimationPlayer"):
		new_card.animation_player.play("card_flip")
		# Espera a animação de flip terminar
		await new_card.animation_player.animation_finished 
	
	# Agora sim, configura os labels (quais devem ser visíveis, etc.)
	new_card.setup_card_display()

	# 4. Atualizar estados
	empty_slot.card_in_slot = true
	new_card.card_slot_card_is_in = empty_slot
	add_player_card_to_battlefield(new_card) # Adiciona ao array do BM
	
	# 5. Desabilitar colisão do slot
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
			await spell_being_cast.ability_script.trigger_ability(self, current_spell_targets, spell_being_cast)
		else:
			print("ERRO: Feitiço sem ability_script!")
			enable_game_inputs() # Failsafe
		
		reset_targeting_state()
	else:
		reset_targeting_state() # Failsafe

# --- NOVAS FUNÇÕES DE CONTROLE DE ESTADO ---

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
