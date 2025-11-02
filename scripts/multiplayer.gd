extends Node2D

# Referências para a UI do Lobby
@onready var ip_address_line_edit = $IPAddressLineEdit
@onready var host_button = $HostButton
@onready var join_button = $JoinButton
@onready var host_ip_label = $HostIPLabel
@onready var keep_hand_button = $KeepHandButton 
@onready var mulligan_button = $MulliganButton 

# As cenas que representam os "lados" do campo de batalha
var player_field_scene = preload("res://scenes/player_field.tscn")
var opponent_field_scene = preload("res://scenes/opponent_field.tscn")

var local_player_mulligan_decision_made = false
var opponent_mulligan_decision_made = false
var local_player_kept_hand = false
var opponent_kept_hand = false
var game_started: bool = false

const DEFAULT_PORT = 9999
var opponent_peer_id = 0


var deck_1_list: Array[String] = [
	
	
	"Rato da Peste","Membro da Royal Society","Guardião da Casa da Moeda",
	"Disco de Newton", "Canhão de Newton","Rato da Peste",
	"Membro da Royal Society","Guardião da Casa da Moeda","Disco de Newton", 
	"Canhão de Newton",
	"Trinity College","Trinity College","Trinity College","Trinity College","Trinity College",
	"Trinity College","Woolsthorpe Manor","Woolsthorpe Manor","Woolsthorpe Manor","Woolsthorpe Manor","Woolsthorpe Manor","Woolsthorpe Manor","Início da Peste","Início da Peste","Início da Peste","Início da Peste","Início da Peste","Início da Peste","Surto da Peste","Surto da Peste","Surto da Peste","Surto da Peste","A Peste","A Peste","A Peste","A Peste",
]

var deck_2_list: Array[String] = [

	"Canhão de Newton","Canhão de Newton","Canhão de Newton","Canhão de Newton","Canhão de Newton","Canhão de Newton","Canhão de Newton","Canhão de Newton",
]


func _ready():
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	keep_hand_button.pressed.connect(_on_keep_hand_button_pressed)
	mulligan_button.pressed.connect(_on_mulligan_button_pressed)
	
	
	# --- NOVO: Conectar Sinais de Rede ---
	# Estes sinais nos dirão o estado real da conexão.
	
	# LINHA CORRIGIDA: O sinal chama-se 'connected_to_server'
	multiplayer.connected_to_server.connect(_on_connected_to_server) 
	
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	# --- FIM DA NOVA SEÇÃO ---

# Chamado quando o jogador clica em "Host"

func _display_host_ip():
	var local_addresses = IP.get_local_addresses()
	var host_ip = "IP não encontrado."
	
	# Passa por todos os IPs que a máquina possui
	for ip in local_addresses:
		# Nós queremos um endereço IPv4 (sem ":")
		# e que não seja o "localhost" (127.0.0.1)
		if ip != "127.0.0.1" and not ":" in ip:
			host_ip = ip
			break # Pega o primeiro IP de rede local válido que encontrar
			
	if is_instance_valid(host_ip_label):
		host_ip_label.text = "Seu IP de Host: " + host_ip
	else:
		print("AVISO: Nó 'HostIPLabel' não encontrado em main.tscn. Não é possível exibir o IP.")

func _on_host_button_pressed():
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

# Chamado quando o jogador clica em "Join"
func _on_join_button_pressed():
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

# --- INÍCIO DE NOVAS FUNÇÕES DE SINAL ---

# Chamado no HOST quando um Cliente se conecta
func _on_peer_connected(peer_id):
	print("Peer (Cliente) conectado! ID: ", peer_id)
	# O Host só inicia o jogo quando o primeiro cliente (peer_id != 1) se conecta.
	# Verificamos se o nó "1" já existe para não chamar start_game duas vezes
	opponent_peer_id = peer_id
	if multiplayer.is_server() and not get_node_or_null("1"):
		print("Host: Iniciando o jogo (Jogador 1).")
		start_game(1, opponent_peer_id)

# Chamado no CLIENTE quando a conexão é bem sucedida
# NOME DA FUNÇÃO CORRIGIDO:
func _on_connected_to_server():
	print("Cliente: Conexão bem sucedida!")
	
	# --- ALTERAÇÃO AQUI ---
	if not multiplayer.is_server() and not get_node_or_null("2"):
		print("Cliente: Iniciando o jogo (Jogador 2).")
		opponent_peer_id = 1 # O oponente do Cliente é o Host (ID 1)
		start_game(2, opponent_peer_id) # Passa o ID do oponente (Host)
	# --- FIM DA ALTERAÇÃO ---

# Chamado no CLIENTE quando a conexão falha
func _on_connection_failed():
	print("Cliente: Falha ao conectar.")
	multiplayer.multiplayer_peer = null # Limpa o peer
	
	# Mostra a UI do Lobby novamente
	show_lobby_ui()

# Chamado em AMBOS quando alguém se desconecta
func _on_peer_disconnected(peer_id):
	print("Peer desconectado: ", peer_id)
	# (Aqui você pode adicionar lógica para encerrar o jogo, voltar ao menu, etc.)
	
# --- FIM DE NOVAS FUNÇÕES DE SINAL ---

# --- NOVAS Funções de UI ---
func hide_lobby_ui():
	ip_address_line_edit.visible = false
	host_button.visible = false
	join_button.visible = false

func show_lobby_ui():
	ip_address_line_edit.visible = true
	host_button.visible = true
	join_button.visible = true
# --- FIM DA NOVA SEÇÃO ---

func start_game(player_id, opponent_id_arg):
	host_ip_label.visible = false
	var player_field = player_field_scene.instantiate() #
	var opponent_field = opponent_field_scene.instantiate() #
	game_started = false
	local_player_mulligan_decision_made = false
	opponent_mulligan_decision_made = false
	local_player_kept_hand = false
	opponent_kept_hand = false
	# Define nomes e autoridade (sem alterações)
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

	# Resetar estado do Mulligan
	local_player_mulligan_decision_made = false
	opponent_mulligan_decision_made = false
	local_player_kept_hand = false
	opponent_kept_hand = false

	if multiplayer.is_server(): #
		print("Host: Sincronizando decks...") #
		deck_1_list.shuffle() #
		deck_2_list.shuffle() #

		if opponent_peer_id == 0: #
			print("ERRO: ID do oponente desconhecido!") #
			return #

		var bm_host = get_node("/root/Main/1/BattleManager") #
		var bm_client = get_node("/root/Main/2/BattleManager") #

		if not is_instance_valid(bm_host) or not is_instance_valid(bm_client): #
			print("ERRO CRÍTICO: BattleManagers não encontrados! Abortando.") #
			return #

		# Sincroniza decks (sem alterações)
		bm_host.rpc_id(1, "rpc_set_my_deck", deck_1_list) #
		bm_host.rpc_id(1, "rpc_set_opponent_deck_size", deck_2_list.size()) #
		bm_client.rpc_id(opponent_peer_id, "rpc_set_my_deck", deck_2_list) #
		bm_client.rpc_id(opponent_peer_id, "rpc_set_opponent_deck_size", deck_1_list.size()) #

		await get_tree().create_timer(0.5).timeout #

		print("Host: Enviando RPCs para comprar mãos iniciais...") #

		# Compra mãos iniciais
		for i in range(Constants.STARTING_HAND_SIZE): #
			bm_host.call_deferred("rpc_id", 1, "rpc_draw_my_card") #
			bm_host.call_deferred("rpc_id", 1, "rpc_draw_opponent_card") #
			bm_client.call_deferred("rpc_id", opponent_peer_id, "rpc_draw_my_card") #
			bm_client.call_deferred("rpc_id", opponent_peer_id, "rpc_draw_opponent_card") #
			await get_tree().create_timer(0.1).timeout #

		# Mostra botões de Mulligan para ambos os jogadores via RPC
		rpc("show_mulligan_buttons_rpc") # Chamando o RPC renomeado

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
	local_player_mulligan_decision_made = false # Permite nova decisão (Manter)
	mulligan_button.disabled = true
	print(local_id, ": Enviando notificação de Mulligan para o oponente ", opponent_peer_id)
	rpc_id(opponent_peer_id, "rpc_receive_opponent_mulligan_decision", false)
	check_both_players_ready()

@rpc("any_peer")
func rpc_receive_opponent_mulligan_decision(kept_hand: bool): # Renomeado
	var sender_id = multiplayer.get_remote_sender_id()
	print(multiplayer.get_unique_id(), ": Recebido do oponente ", sender_id, ". Manteve: ", kept_hand)
	opponent_mulligan_decision_made = true # Marca que oponente decidiu algo
	opponent_kept_hand = kept_hand # Registra o quê
	if not kept_hand: # Se o oponente fez Mulligan
		print(multiplayer.get_unique_id(), ": Oponente fez Mulligan. Resetando opponent_mulligan_decision_made para false.")
		opponent_mulligan_decision_made = false # Reseta para esperar a decisão dele sobre a nova mão
	check_both_players_ready()

func check_both_players_ready():
	print(multiplayer.get_unique_id(), ": Checando prontidão - Local: ", local_player_mulligan_decision_made, "(Manteve:", local_player_kept_hand, ") Oponente: ", opponent_mulligan_decision_made, "(Manteve:", opponent_kept_hand, ")")
	if local_player_mulligan_decision_made and opponent_mulligan_decision_made and \
	   local_player_kept_hand and opponent_kept_hand:
		if not game_started: # Evita iniciar múltiplas vezes
			print("Ambos jogadores decidiram manter. Iniciando o jogo...")
			game_started = true # Habilita o jogo!
			rpc("hide_mulligan_buttons_rpc") # Esconde botões para todos
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
