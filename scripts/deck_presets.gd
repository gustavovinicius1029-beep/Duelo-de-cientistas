# Em scripts/deck_presets.gd
extends Node

# Carrega a base de dados de cartas para poder ler os IDs e tipos
var card_database_ref = preload("res://scripts/card_database.gd")

const MAX_NON_TERRENO_COPIES = 4
const MAX_TERRENO_COPIES = 10

func get_automatic_preset(preset_id_prefix: String) -> Array[String]:
	var deck_list: Array[String] = []
	var card_db = card_database_ref.CARDS
	for card_name in card_db:
		var card_data = card_db[card_name]
		if not card_data.has("id") or card_data["id"] == null:
			continue
		var card_id: String = card_data["id"]
		if card_id.begins_with(preset_id_prefix):
			var card_type = card_data["tipo"]
			var copies = 0
			if card_type == "Terreno":
				copies = MAX_TERRENO_COPIES
			else:
				copies = MAX_NON_TERRENO_COPIES
			for i in range(copies):
				deck_list.append(card_name)
	print("Deck automático gerado para '", preset_id_prefix, "' com ", deck_list.size(), " cartas.")
	return deck_list

func get_manual_preset(preset_name: String) -> Array[String]:
	var deck_list: Array[String] = []
	match preset_name:
		"Newton":
			deck_list = [
				"Rato da Peste", "Rato da Peste", "Rato da Peste", "Rato da Peste",
				"Membro da Royal Society", "Membro da Royal Society", "Membro da Royal Society", "Membro da Royal Society",
				"Guardião da Casa da Moeda", "Guardião da Casa da Moeda", "Guardião da Casa da Moeda", "Guardião da Casa da Moeda",
				"Disco de Newton", "Disco de Newton", "Disco de Newton",
				"Canhão de Newton", "Canhão de Newton",
				"Início da Peste", "Início da Peste",
				"Surto da Peste",
				"A Peste",
				"Trinity College", "Trinity College", "Trinity College", "Trinity College", "Trinity College",
				"Woolsthorpe Manor", "Woolsthorpe Manor", "Woolsthorpe Manor", "Woolsthorpe Manor", "Woolsthorpe Manor"
			]
			print("ERRO: Preset manual '", preset_name, "' não encontrado.")
	print("Deck manual gerado para '", preset_name, "' com ", deck_list.size(), " cartas.")
	return deck_list
