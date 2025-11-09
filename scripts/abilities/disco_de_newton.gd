func trigger_on_blocked_effect(battle_manager, attacking_card, blockers: Array, attacker_owner: String):
	print("HABILIDADE DISPARADA: Disco de Newton foi bloqueado!")
	
	var enemy_battlefield = []
	var enemy_owner_string = ""
	
	if attacker_owner == "Jogador":
		enemy_battlefield = battle_manager.opponent_cards_on_battlefield
		enemy_owner_string = "Oponente"
	else:
		enemy_battlefield = battle_manager.player_cards_on_battlefield
		enemy_owner_string = "Jogador"

	var cards_to_damage = []
	for card in enemy_battlefield:
		if is_instance_valid(card) and card.card_type == "Criatura":
			cards_to_damage.append(card)
	
	if cards_to_damage.is_empty():
		return # Sem alvos

	print("Disco de Newton causando 2 de dano em ", cards_to_damage.size(), " criaturas inimigas.")
	
	var cards_to_destroy = []
	
	# Pega a cena de VFX do battle_manager
	var vfx_scene = battle_manager.NORMAL_ATTACK_VFX # Reutilizando VFX de ataque

	for target_card in cards_to_damage:
		if not is_instance_valid(target_card):
			continue
			
		# Aplica o dano
		target_card.current_health = max(0, target_card.current_health - 2)
		
		# Toca VFX
		if vfx_scene != null:
			var vfx = vfx_scene.instantiate()
			vfx.global_position = target_card.global_position
			if is_instance_valid(battle_manager.card_manager):
				battle_manager.card_manager.add_child(vfx)
			else:
				battle_manager.get_tree().root.add_child(vfx) # Fallback
		
		# Atualiza a UI da carta
		if target_card.has_method("update_stats_display"):
			target_card.update_stats_display()
		
		if target_card.has_method("update_details_popup_if_visible"):
			target_card.update_details_popup_if_visible()
		
		# Checa se a carta morreu
		if target_card.current_health <= 0:
			if not cards_to_destroy.any(func(d): return d.card == target_card):
				cards_to_destroy.append({"card": target_card, "owner": enemy_owner_string})

		await battle_manager.get_tree().create_timer(0.1).timeout # Pequena pausa

	# Destrói as cartas que morreram (depois que todas levaram dano)
	if not cards_to_destroy.is_empty():
		await battle_manager.get_tree().create_timer(0.3).timeout
		for item in cards_to_destroy:
			if is_instance_valid(item.card):
				# destroy_card também chama update_all_static_effects,
				# o que é bom caso uma aura seja removida.
				await battle_manager.destroy_card(item.card, item.owner)
				await battle_manager.get_tree().create_timer(0.1).timeout
