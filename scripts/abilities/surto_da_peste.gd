extends Node

# Esta função espera um ARRAY de alvos
func trigger_ability(battle_manager, target_cards: Array, spell_card, caster_owner: String):
	print("HABILIDADE ATIVADA: Surto da Peste!")
	
	battle_manager.disable_game_inputs()

	if target_cards.is_empty():
		print("Nenhum alvo foi selecionado para o Surto da Peste.")
	else:
		for target in target_cards:
			if is_instance_valid(target):
				print("Destruindo alvo: ", target.name)
				
				# Determina o dono da carta para a função destroy_card
				var card_owner = ""
				if battle_manager.player_cards_on_battlefield.has(target):
					card_owner = "Jogador"
				elif battle_manager.opponent_cards_on_battlefield.has(target):
					card_owner = "Oponente"
					
				if card_owner:
					await battle_manager.destroy_card(target, card_owner)
					await battle_manager.get_tree().create_timer(0.3).timeout
				else:
					print("ERRO: Não foi possível encontrar o dono de ", target.name)

	# Espera e destrói o feitiço
	await battle_manager.get_tree().create_timer(0.5).timeout
	if is_instance_valid(spell_card):
		await battle_manager.destroy_card(spell_card, caster_owner)
		
	# Reativa os botões
	battle_manager.phase_button.disabled = false
	battle_manager.confirm_action_button.disabled = true
