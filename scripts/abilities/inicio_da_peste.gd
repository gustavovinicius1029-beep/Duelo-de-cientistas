func trigger_ability(battle_manager, target_cards: Array, spell_card, caster_owner: String):
# --- FIM DA ALTERAÇÃO ---
	print("HABILIDADE ATIVADA: Início da Peste!")
	
	battle_manager.phase_button.disabled = true
	battle_manager.phase_button.visible = false

	# --- INÍCIO DA ALTERAÇÃO ---
	# 2. Pega o primeiro (e único) alvo do array
	var target_card = null
	if not target_cards.is_empty():
		target_card = target_cards[0] 
	# --- FIM DA ALTERAÇÃO ---

	# Efeito 1: Aplicar marcador de peste no alvo (usa target_card)
	if is_instance_valid(target_card) and target_card.has_method("add_plague_counter"):
		target_card.add_plague_counter(1)
		print("Aplicando Peste em: ", target_card.name)
	
	await battle_manager.get_tree().create_timer(0.3).timeout

	# Efeito 2: Contar marcadores (sem alteração)
	var total_plague_counters = 0
	for card in battle_manager.player_cards_on_battlefield:
		if is_instance_valid(card) and "plague_counters" in card:
			total_plague_counters += card.plague_counters
	for card in battle_manager.opponent_cards_on_battlefield:
		if is_instance_valid(card) and "plague_counters" in card:
			total_plague_counters += card.plague_counters
	print("Total de marcadores de Peste em campo: ", total_plague_counters)

	# Efeito 3: Invocar Ratos da Peste
	if total_plague_counters > 0:
		for i in range(total_plague_counters):
			print("Invocando Rato da Peste ", i + 1)
			# --- INÍCIO DA ALTERAÇÃO ---
			# 3. Usa caster_owner para invocar
			await battle_manager.summon_token("Rato da Peste", caster_owner)
			# --- FIM DA ALTERAÇÃO ---
			await battle_manager.get_tree().create_timer(0.3).timeout
	
	# 4. Destruir a carta de feitiço
	await battle_manager.get_tree().create_timer(0.5).timeout
	if is_instance_valid(spell_card):
		# --- INÍCIO DA ALTERAÇÃO ---
		# 4. Usa caster_owner para destruir
		await battle_manager.destroy_card(spell_card, caster_owner)
		# --- FIM DA ALTERAÇÃO ---
		
	# 5. Verificar se o alvo morreu (usa target_card)
	if is_instance_valid(target_card) and target_card.current_health <= 0:
		print(target_card.name, " sucumbiu à Peste.")
		await battle_manager.get_tree().create_timer(0.5).timeout
		
		# Determina o dono do alvo para a destruição
		var target_owner = ""
		if battle_manager.player_cards_on_battlefield.has(target_card):
			target_owner = "Jogador"
		elif battle_manager.opponent_cards_on_battlefield.has(target_card):
			target_owner = "Oponente"
		
		if target_owner:
			await battle_manager.destroy_card(target_card, target_owner) 

	# 6. Reativa o botão de turno (sem alteração)
	battle_manager.phase_button.disabled = false
	battle_manager.phase_button.visible = true
