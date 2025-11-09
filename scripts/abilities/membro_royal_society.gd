func apply_aura_effect(battle_manager, aura_card, owner_battlefield_cards: Array):
	for card in owner_battlefield_cards:
		if not is_instance_valid(card) or card == aura_card:
			continue
		if card.card_type == "Criatura":
			card.apply_stat_buff(1, 0)
