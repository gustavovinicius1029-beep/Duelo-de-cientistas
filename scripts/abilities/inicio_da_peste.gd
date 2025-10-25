extends Node

# Esta função será chamada pelo BattleManager quando o alvo for selecionado.
# Ela espera receber o BattleManager (para usar suas funções) e o alvo.
func trigger_ability(battle_manager, target_card, spell_card):
	print("HABILIDADE ATIVADA: Início da Peste!")
	
	# 1. Desativa o botão de turno (para evitar cliques duplos)
	battle_manager.end_turn_button.disabled = true
	battle_manager.end_turn_button.visible = false

	# Efeito 1: Aplicar marcador de peste no alvo
	if is_instance_valid(target_card) and target_card.has_method("add_plague_counter"):
		target_card.add_plague_counter(1)
		print("Aplicando Peste em: ", target_card.name)
	
	await battle_manager.wait_seconds(0.5) # Pausa dramática

	# Efeito 2: Contar todos os marcadores de peste em campo
	var total_plague_counters = 0
	
	# Conta marcadores do jogador
	for card in battle_manager.player_cards_on_battlefield:
		if is_instance_valid(card) and "plague_counters" in card:
			total_plague_counters += card.plague_counters
			
	# Conta marcadores do oponente
	for card in battle_manager.opponent_cards_on_battlefield:
		if is_instance_valid(card) and "plague_counters" in card:
			total_plague_counters += card.plague_counters

	print("Total de marcadores de Peste em campo: ", total_plague_counters)

	# Efeito 3: Invocar Ratos da Peste
	if total_plague_counters > 0:
		for i in range(total_plague_counters):
			print("Invocando Rato da Peste ", i + 1)
			# Precisamos criar a função summon_token no BattleManager
			await battle_manager.summon_token("Rato da Peste", "Jogador")
			await battle_manager.wait_seconds(0.3)
	
	# 4. Destruir a carta de feitiço
	await battle_manager.wait_seconds(0.5)
	if is_instance_valid(spell_card):
		await battle_manager.destroy_card(spell_card, "Jogador")
		
	# 5. Verificar se o alvo morreu DEPOIS que o feitiço foi para o cemitério
	if is_instance_valid(target_card) and target_card.current_health <= 0:
		print(target_card.name, " sucumbiu à Peste.")
		await battle_manager.wait_seconds(0.5)
		await battle_manager.destroy_card(target_card, "Oponente") # Assumindo que o alvo é do oponente

	# 6. Reativa o botão de turno
	battle_manager.end_turn_button.disabled = false
	battle_manager.end_turn_button.visible = true
