extends Node2D

# Referência ao label que mostrará a contagem
@onready var count_label = $CountLabel

# A lista de nomes das cartas no cemitério
var card_names: Array[String] = []
var graveyard_viewer_ref: Control

func _ready():
	# Espera um frame para garantir que a autoridade multiplayer esteja definida
	await get_tree().process_frame
	graveyard_viewer_ref = get_node_or_null("/root/Main/GraveyardViewer")
	var my_field = get_parent()
	var local_player_input_manager = null
	
	# Esta lógica complexa é necessária para encontrar o InputManager do jogador local,
	# não importa de qual campo (jogador ou oponente) este script está sendo executado.
	
	if my_field.is_multiplayer_authority():
		# CASO 1: Este é o cemitério do Jogador Local.
		# O InputManager é um "irmão" neste mesmo campo.
		local_player_input_manager = my_field.get_node_or_null("InputManager")
		
		if is_instance_valid(local_player_input_manager):
			# Conecta ao sinal específico do cemitério do jogador
			local_player_input_manager.player_graveyard_clicked.connect(show_contents)
		else:
			printerr("Graveyard (Player): Não foi possível encontrar o nó InputManager!")
			
	else:

		var my_field_id = my_field.name # Ex: "2"
		var local_player_field_id = "2" if my_field_id == "1" else "1" # Ex: "1"
		var local_player_field_path = "/root/Main/" + local_player_field_id
		
		var local_player_field = get_node_or_null(local_player_field_path)
		
		if is_instance_valid(local_player_field):
			local_player_input_manager = local_player_field.get_node_or_null("InputManager")
			if is_instance_valid(local_player_input_manager):
				# Conecta ao sinal específico do cemitério do oponente
				local_player_input_manager.opponent_graveyard_clicked.connect(show_contents)
			else:
				printerr("Graveyard (Opponent): Não encontrou InputManager em " + local_player_field_path)
		else:
			printerr("Graveyard (Opponent): Não encontrou o campo do jogador local em " + local_player_field_path)
	update_count_label()
	
@rpc("any_peer", "call_local")
func rpc_add_card(card_name: String):
	card_names.append(card_name)
	update_count_label()
	print(get_parent().name + " Graveyard: Added " + card_name + ". Total: " + str(card_names.size()))

func update_count_label():
	if is_instance_valid(count_label):
		count_label.text = str(card_names.size())

func show_contents():
	if not is_instance_valid(graveyard_viewer_ref):
		print("ERRO: Referência do GraveyardViewer é inválida. Mostrando no console como fallback.")
		# Fallback para o console
		var title_fallback = "Seu Cemitério" if get_parent().is_multiplayer_authority() else "Cemitério do Oponente"
		print("--- CONTEÚDO (" + title_fallback + ") ---")
		if card_names.is_empty():
			print(" (Vazio) ")
		else:
			for card_name in card_names: 
				print("- " + card_name)
		print("---------------------------------")
		return
	var title = "Seu Cemitério"
	if not get_parent().is_multiplayer_authority():
		title = "Cemitério do Oponente"
	graveyard_viewer_ref.populate_and_show(card_names, title)
