extends Node

# Esta habilidade não tem alvo, ela afeta o campo global
func trigger_ability(battle_manager, spell_card, caster_owner: String):
	print("HABILIDADE ATIVADA: A Peste!")
	
	# 1. Desativa entradas
	battle_manager.disable_game_inputs()

	var destroyed_creature_count = 0
	
	# 2. Precisamos copiar os arrays antes de iterar,
	# pois 'destroy_card' vai modificar os arrays originais.
	var player_creatures = battle_manager.player_cards_on_battlefield.duplicate()
	var opponent_creatures = battle_manager.opponent_cards_on_battlefield.duplicate()

	# 3. Destrói criaturas do jogador
	for card in player_creatures:
		if is_instance_valid(card) and card.card_type == "Criatura":
			await battle_manager.destroy_card(card, "Jogador")
			destroyed_creature_count += 1
			await battle_manager.wait_seconds(0.1) # Pausa dramática

	# 4. Destrói criaturas do oponente
	for card in opponent_creatures:
		if is_instance_valid(card) and card.card_type == "Criatura":
			await battle_manager.destroy_card(card, "Oponente")
			destroyed_creature_count += 1
			await battle_manager.wait_seconds(0.1) # Pausa dramática
	
	print("Total de criaturas destruídas pela Peste: ", destroyed_creature_count)

	# 5. Invoca Ratos da Peste
	if destroyed_creature_count > 0:
		for i in range(destroyed_creature_count):
			print("Invocando Rato da Peste ", i + 1)
			# --- INÍCIO DA ALTERAÇÃO ---
			# 2. Usa 'caster_owner' para invocar o token
			await battle_manager.summon_token("Rato da Peste", caster_owner)
			# --- FIM DA ALTERAÇÃO ---
			await battle_manager.wait_seconds(0.2)
	
	# 6. Destrói a própria carta de feitiço
	await battle_manager.wait_seconds(0.5)
	if is_instance_valid(spell_card):
		await battle_manager.destroy_card(spell_card, caster_owner)
		
	# 7. Reativa entradas
	battle_manager.enable_game_inputs()
