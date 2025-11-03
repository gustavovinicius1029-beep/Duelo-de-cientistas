extends Node2D

# Referências para a UI do Lobby
@onready var ip_address_line_edit = $IPAddressLineEdit
@onready var host_button = $HostButton
@onready var join_button = $JoinButton
@onready var host_ip_label = $HostIPLabel
@onready var keep_hand_button = $KeepHandButton 
@onready var mulligan_button = $MulliganButton 
@onready var p1_deck_select: OptionButton = $DeckSelectButton
@onready var deck_text: = $HostIPLabel2

# As cenas que representam os "lados" do campo de batalha
var player_field_scene = preload("res://scenes/player_field.tscn")
var opponent_field_scene = preload("res://scenes/opponent_field.tscn")
var deck_preset_loader = preload("res://scripts/deck_presets.gd").new()

var p1_deck_choice: String = ""
var opponent_peer_id: int = 0
var opponent_deck_choice: String = ""

var local_player_mulligan_decision_made = false
var opponent_mulligan_decision_made = false
var local_player_kept_hand = false
var opponent_kept_hand = false
var game_started: bool = false

const DEFAULT_PORT = 4910

func _ready():
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	keep_hand_button.pressed.connect(_on_keep_hand_button_pressed)
	mulligan_button.pressed.connect(_on_mulligan_button_pressed)
	host_button.disabled = true
	join_button.disabled = true
	_populate_deck_options(p1_deck_select)
	p1_deck_select.item_selected.connect(_on_deck_selected)
	multiplayer.connected_to_server.connect(_on_connected_to_server) 
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _populate_deck_options(option_button: OptionButton):
	if not is_instance_valid(option_button):
		print("AVISO: OptionButton de deck não encontrado.")
		return
	option_button.clear()
	option_button.add_item("Escolha seu Cientista...")
	option_button.add_item("Newton")
	option_button.add_item("Einstein (Em Breve)")
	option_button.add_item("Marie Curie (Em Breve)") 
	option_button.set_item_disabled(0, true)
	option_button.set_item_disabled(2, true)
	option_button.set_item_disabled(3, true)
	option_button.select(0)

func _display_host_ip():
	var local_addresses = IP.get_local_addresses()
	var host_ip = "IP não encontrado."
	for ip in local_addresses:
		if ip != "127.0.0.1" and not ":" in ip:
			host_ip = ip
			break
	if is_instance_valid(host_ip_label):
		host_ip_label.text = "Seu IP de Host: " + host_ip
	else:
		print("AVISO: Nó 'HostIPLabel' não encontrado em main.tscn. Não é possível exibir o IP.")

func _on_deck_selected(index):
	if index > 0:
		p1_deck_choice = p1_deck_select.get_item_text(index)
		print("Deck local selecionado: ", p1_deck_choice)
		host_button.disabled = false
		join_button.disabled = false
	else:
		p1_deck_choice = ""
		host_button.disabled = true
		join_button.disabled = true

func _on_host_button_pressed():
	if p1_deck_choice == "":
		print("ERRO: Tentativa de Host sem deck selecionado.")
		return
	print("Iniciando como Host (Servidor)...")
	host_ip_label.visible = true
	_display_host_ip()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT)
	if error:
		print("Falha ao criar o servidor: ", error)
		return
	multiplayer.multiplayer_peer = peer
	print("Servidor criado. Aguardando jogador...")
	hide_lobby_ui()

func _on_join_button_pressed():
	if p1_deck_choice == "":
		print("ERRO: Tentativa de Join sem deck selecionado.")
		return
	print("Tentando se conectar como Cliente...")
	var host_ip = ip_address_line_edit.text
	if host_ip == "":
		host_ip = "127.0.0.1" # Padrão para localhost se vazio
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(host_ip, DEFAULT_PORT)
	if error:
		print("Falha ao iniciar o cliente: ", error)
		return
	multiplayer.multiplayer_peer = peer
	print("Tentando conectar ao Host em ", host_ip)
	hide_lobby_ui()

func _on_peer_connected(peer_id):
	print("Peer (Cliente) conectado! ID: ", peer_id)
	opponent_peer_id = peer_id
	print("Host: Aguardando escolha de deck do cliente...")
	
func _on_connected_to_server():
	print("Cliente: Conexão bem sucedida!")
	print("Cliente: Enviando escolha de deck '", p1_deck_choice, "' para o Host.")
	rpc_id(1, "rpc_receive_client_deck_choice", p1_deck_choice)
	if not multiplayer.is_server() and not get_node_or_null("2"):
		print("Cliente: Iniciando o jogo (Jogador 2).")
		opponent_peer_id = 1
		start_game(2, opponent_peer_id)

func _on_connection_failed():
	print("Cliente: Falha ao conectar.")
	multiplayer.multiplayer_peer = null
	show_lobby_ui()

func _on_peer_disconnected(peer_id):
	GameManager.goto_main_menu()
	print("Peer desconectado: ", peer_id)

@rpc("any_peer")
func rpc_receive_client_deck_choice(deck_name: String):
	if not multiplayer.is_server():
		return
	print("Host: Recebida a escolha de deck do cliente: ", deck_name)
	opponent_deck_choice = deck_name
	if multiplayer.is_server() and not get_node_or_null("1"):
		print("Host: Iniciando o jogo (Jogador 1).")
		start_game(1, opponent_peer_id)

func hide_lobby_ui():
	ip_address_line_edit.visible = false
	host_button.visible = false
	join_button.visible = false
	p1_deck_select.visible = false
	deck_text.visible = false
	

func show_lobby_ui():
	ip_address_line_edit.visible = true
	host_button.visible = true
	join_button.visible = true
	p1_deck_select.visible = true
	host_button.disabled = true
	join_button.disabled = true
	if is_instance_valid(p1_deck_select):
		p1_deck_select.select(0)
	p1_deck_choice = ""
	opponent_deck_choice = ""

func start_game(player_id, opponent_id_arg):
	host_ip_label.visible = false
	var player_field = player_field_scene.instantiate() #
	var opponent_field = opponent_field_scene.instantiate() #
	game_started = false
	local_player_mulligan_decision_made = false
	opponent_mulligan_decision_made = false
	local_player_kept_hand = false
	opponent_kept_hand = false
	if player_id == 1: #
		player_field.name = "1" #
		opponent_field.name = "2" #
	else: #
		player_field.name = "2" #
		opponent_field.name = "1" #
	add_child(player_field) #
	add_child(opponent_field) #
	player_field.set_multiplayer_authority(multiplayer.get_unique_id()) #
	opponent_field.set_multiplayer_authority(opponent_id_arg) #
	await get_tree().process_frame #
	await get_tree().process_frame #
	local_player_mulligan_decision_made = false
	opponent_mulligan_decision_made = false
	local_player_kept_hand = false
	opponent_kept_hand = false
	if multiplayer.is_server(): #
		if p1_deck_choice == "" or opponent_deck_choice == "":
			printerr("ERRO CRÍTICO: O Host está iniciando o jogo sem as duas escolhas de deck!")
			printerr("Host (P1): ", p1_deck_choice, " | Cliente (P2): ", opponent_deck_choice)
			if p1_deck_choice == "": p1_deck_choice = "Newton"
			if opponent_deck_choice == "": opponent_deck_choice = "Newton"
		print("Host: Carregando Deck P1 (Host) como '", p1_deck_choice, "'")
		var deck_1_list = deck_preset_loader.get_automatic_preset(p1_deck_choice)
		print("Host: Carregando Deck P2 (Cliente) como '", opponent_deck_choice, "'")
		var deck_2_list = deck_preset_loader.get_automatic_preset(opponent_deck_choice)
		print("Host: Sincronizando decks...") 
		deck_1_list.shuffle() 
		deck_2_list.shuffle() 
		if opponent_peer_id == 0: 
			print("ERRO: ID do oponente desconhecido!") 
			return 
		var bm_host = get_node("/root/Main/1/BattleManager") 
		var bm_client = get_node("/root/Main/2/BattleManager") 
		if not is_instance_valid(bm_host) or not is_instance_valid(bm_client): 
			print("ERRO CRÍTICO: BattleManagers não encontrados! Abortando.") 
			return 
		bm_host.rpc_id(1, "rpc_set_my_deck", deck_1_list) 
		bm_host.rpc_id(1, "rpc_set_opponent_deck_size", deck_2_list.size()) 
		bm_client.rpc_id(opponent_peer_id, "rpc_set_my_deck", deck_2_list) 
		bm_client.rpc_id(opponent_peer_id, "rpc_set_opponent_deck_size", deck_1_list.size()) 
		await get_tree().create_timer(0.5).timeout 
		print("Host: Enviando RPCs para comprar mãos iniciais...") 
		for i in range(Constants.STARTING_HAND_SIZE): 
			bm_host.call_deferred("rpc_id", 1, "rpc_draw_my_card") 
			bm_host.call_deferred("rpc_id", 1, "rpc_draw_opponent_card") 
			bm_client.call_deferred("rpc_id", opponent_peer_id, "rpc_draw_my_card") 
			bm_client.call_deferred("rpc_id", opponent_peer_id, "rpc_draw_opponent_card") 
			await get_tree().create_timer(0.1).timeout 
		rpc("show_mulligan_buttons_rpc")

@rpc("any_peer", "call_local")
func show_mulligan_buttons_rpc():
	await get_tree().process_frame
	print(multiplayer.get_unique_id(), ": Mostrando botões de Mulligan.")
	keep_hand_button.visible = true
	mulligan_button.visible = true
	mulligan_button.disabled = false

@rpc("any_peer", "call_local")
func hide_mulligan_buttons_rpc():
	print(multiplayer.get_unique_id(), ": Escondendo botões de Mulligan.")
	keep_hand_button.visible = false
	mulligan_button.visible = false

func _set_local_decision_and_notify(kept_hand: bool):
	print(multiplayer.get_unique_id(), ": Definindo local_player_mulligan_decision_made = true. Manteve: ", kept_hand)
	local_player_mulligan_decision_made = true
	local_player_kept_hand = kept_hand
	if kept_hand:
		hide_mulligan_buttons_rpc()
		mulligan_button.visible = true
		mulligan_button.disabled = true
	else:
		mulligan_button.disabled = true
	print(multiplayer.get_unique_id(), ": Enviando decisão para o oponente ", opponent_peer_id, ". Manteve: ", kept_hand)
	rpc_id(opponent_peer_id, "rpc_receive_opponent_mulligan_decision", kept_hand)
	check_both_players_ready()

# Função Helper para centralizar a lógica de decisão
func _make_mulligan_decision(kept_hand: bool):
	if local_player_mulligan_decision_made:
		print(multiplayer.get_unique_id(), ": Decisão já tomada, ignorando.")
		return

	print(multiplayer.get_unique_id(), ": Definindo local_player_mulligan_decision_made = true. Manteve: ", kept_hand)
	local_player_mulligan_decision_made = true
	local_player_kept_hand = kept_hand # Registra a escolha desta rodada

	if kept_hand:
		hide_mulligan_buttons_rpc()
		mulligan_button.visible = true
	else:
		# Se fez mulligan, só desabilita o botão de mulligan
		mulligan_button.disabled = true
		keep_hand_button.visible = true # Garante que "Manter" ainda está visível

	# Envia a decisão para o oponente
	print(multiplayer.get_unique_id(), ": Enviando decisão para o oponente ", opponent_peer_id, ". Manteve: ", kept_hand)
	rpc_id(opponent_peer_id, "rpc_opponent_made_mulligan_decision", kept_hand)

	# Verifica se ambos estão prontos APÓS definir o estado local e enviar RPC
	check_both_players_ready()

func _on_keep_hand_button_pressed():
	print(multiplayer.get_unique_id(), ": Botão Manter Mão pressionado.")
	if not local_player_mulligan_decision_made:
		_set_local_decision_and_notify(true) 
		keep_hand_button.visible = true
		keep_hand_button.disabled = true
		#mulligan_button.disabled = true
		#mulligan_button.visible = false

func _on_mulligan_button_pressed():
	var local_id = multiplayer.get_unique_id()
	print(local_id, ": Botão Mulligan pressionado.")
	if local_player_mulligan_decision_made or mulligan_button.disabled:
		print(local_id, ": Decisão de mulligan ignorada (já decidida ou botão desabilitado).")
		return
	var player_field_node_name = "1" if multiplayer.is_server() else "2"
	var player_hand_path = player_field_node_name + "/PlayerHand"
	var player_deck_path = player_field_node_name + "/Deck"
	var player_hand = get_node_or_null(player_hand_path)
	var player_deck = get_node_or_null(player_deck_path)
	if not is_instance_valid(player_hand) or not is_instance_valid(player_deck):
		printerr("Erro crítico ao obter nós em _on_mulligan_button_pressed")
		if not local_player_mulligan_decision_made:
			_set_local_decision_and_notify(false)
		return
	print(local_id, ": Chamando player_hand.return_hand_to_deck()")
	var cards_to_return = player_hand.return_hand_to_deck()
	print(local_id, ": Chamando player_deck.rpc_perform_mulligan_draw()")
	player_deck.rpc_perform_mulligan_draw(cards_to_return)
	print(local_id, ": Resetando local_player_mulligan_decision_made para false após Mulligan.")
	local_player_mulligan_decision_made = false 
	mulligan_button.disabled = true
	print(local_id, ": Enviando notificação de Mulligan para o oponente ", opponent_peer_id)
	rpc_id(opponent_peer_id, "rpc_receive_opponent_mulligan_decision", false)
	check_both_players_ready()

@rpc("any_peer")
func rpc_receive_opponent_mulligan_decision(kept_hand: bool): 
	var sender_id = multiplayer.get_remote_sender_id()
	print(multiplayer.get_unique_id(), ": Recebido do oponente ", sender_id, ". Manteve: ", kept_hand)
	opponent_mulligan_decision_made = true 
	opponent_kept_hand = kept_hand 
	if not kept_hand: 
		print(multiplayer.get_unique_id(), ": Oponente fez Mulligan. Resetando opponent_mulligan_decision_made para false.")
		opponent_mulligan_decision_made = false 
	check_both_players_ready()

func check_both_players_ready():
	print(multiplayer.get_unique_id(), ": Checando prontidão - Local: ", local_player_mulligan_decision_made, "(Manteve:", local_player_kept_hand, ") Oponente: ", opponent_mulligan_decision_made, "(Manteve:", opponent_kept_hand, ")")
	if local_player_mulligan_decision_made and opponent_mulligan_decision_made and \
	   local_player_kept_hand and opponent_kept_hand:
		if not game_started:
			print("Ambos jogadores decidiram manter. Iniciando o jogo...")
			game_started = true
			rpc("hide_mulligan_buttons_rpc")
			if multiplayer.is_server():
				var bm_host = get_node_or_null("/root/Main/1/BattleManager")
				var bm_client = get_node_or_null("/root/Main/2/BattleManager")
				if is_instance_valid(bm_host) and is_instance_valid(bm_client):
					print("Servidor iniciando turnos.")
					bm_host.rpc_id(1, "start_turn", "Jogador")
					bm_client.rpc_id(opponent_peer_id, "start_turn", "Oponente")
				else:
					printerr("Erro CRÍTICO check_both_players_ready: BattleManagers não encontrados.")
	else:
		print(multiplayer.get_unique_id(), ": Aguardando ambos os jogadores manterem a mão...")
