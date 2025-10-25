extends Node

# Esta função espera um ARRAY de alvos
func trigger_ability(battle_manager, target_cards: Array, spell_card):
	print("HABILIDADE ATIVADA: Surto da Peste!")
	
	# Desativa botões enquanto o feitiço resolve
	battle_manager.disable_game_inputs()

	if target_cards.is_empty():
		print("Nenhum alvo foi selecionado para o Surto da Peste.")
	else:
		for target in target_cards:
			if is_instance_valid(target):
				print("Destruindo alvo: ", target.name)
				
				# Determina o dono da carta para a função destroy_card
				var owner = ""
				if battle_manager.player_cards_on_battlefield.has(target):
					owner = "Jogador"
				elif battle_manager.opponent_cards_on_battlefield.has(target):
					owner = "Oponente"
					
				if owner:
					await battle_manager.destroy_card(target, owner)
					await battle_manager.wait_seconds(0.3) # Pausa entre destruições
				else:
					print("ERRO: Não foi possível encontrar o dono de ", target.name)

	# Espera e destrói o feitiço
	await battle_manager.wait_seconds(0.5)
	if is_instance_valid(spell_card):
		await battle_manager.destroy_card(spell_card, "Jogador")
		
	# Reativa os botões
	battle_manager.enable_game_inputs()
