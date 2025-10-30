extends Node

# Esta função espera um ARRAY de alvos.
# Para "Maçã Caindo", o battle_manager deve ser configurado para enviar apenas 1 alvo.
func trigger_ability(battle_manager, target_cards: Array, spell_card, caster_owner: String):
	print("HABILIDADE ATIVADA: Maçã Caindo!")
	
	# 1. Desativa entradas
	battle_manager.disable_game_inputs()

	if target_cards.is_empty():
		print("Nenhum alvo foi selecionado para a Maçã Caindo.")
	else:
		# Itera sobre os alvos (deve ser apenas um)
		for target in target_cards:
			if is_instance_valid(target) and target.card_type == "Criatura":
				
				# 2. Determina o dono da carta alvo
				var card_owner = ""
				if battle_manager.player_cards_on_battlefield.has(target):
					card_owner = "Jogador"
				elif battle_manager.opponent_cards_on_battlefield.has(target):
					card_owner = "Oponente"
					
				if card_owner:
					print("Maçã Caindo atingiu: ", target.name, " por 2 de dano.")
					
					# 3. Aplica o dano (reduzindo a vida atual)
					target.current_health = max(0, target.current_health - 2)
					
					# 4. Atualiza a UI da carta alvo (label da vida)
					# (Baseado em como o battle_manager aplica dano em combate)
					if is_instance_valid(target.attribute2_label):
						target.attribute2_label.text = str(target.current_health)
					
					# Atualiza o popup se estiver visível
					if target.has_method("update_details_popup_if_visible"):
						target.update_details_popup_if_visible()
						
					# 5. Checa se a criatura foi destruída
					if target.current_health <= 0:
						print(target.name, " foi destruído pelo dano.")
						# Usa a função destroy_card do battle_manager
						await battle_manager.destroy_card(target, card_owner)
					
					# Pausa dramática
					await battle_manager.get_tree().create_timer(0.3).timeout
				else:
					print("ERRO (Maçã Caindo): Não foi possível encontrar o dono de ", target.name)

	# 6. Espera e destrói o feitiço
	await battle_manager.get_tree().create_timer(0.5).timeout
	if is_instance_valid(spell_card):
		await battle_manager.destroy_card(spell_card, caster_owner)
		
	# 7. Reativa as entradas
	battle_manager.enable_game_inputs()
