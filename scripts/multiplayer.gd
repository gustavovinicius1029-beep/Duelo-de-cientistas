extends Node2D

# Referências para a UI do Lobby
@onready var ip_address_line_edit = $IPAddressLineEdit
@onready var host_button = $HostButton
@onready var join_button = $JoinButton
@onready var host_ip_label = $HostIPLabel

# As cenas que representam os "lados" do campo de batalha
var player_field_scene = preload("res://scenes/player_field.tscn")
var opponent_field_scene = preload("res://scenes/opponent_field.tscn")

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
		"Rato da Peste","Membro da Royal Society","Guardião da Casa da Moeda",
	"Disco de Newton", "Canhão de Newton","Rato da Peste",
	"Membro da Royal Society","Guardião da Casa da Moeda","Disco de Newton", 
	"Canhão de Newton",
	"Trinity College","Trinity College","Trinity College","Trinity College","Trinity College",
	"Trinity College","Woolsthorpe Manor","Woolsthorpe Manor","Woolsthorpe Manor","Woolsthorpe Manor","Woolsthorpe Manor","Woolsthorpe Manor","Início da Peste","Início da Peste","Início da Peste","Início da Peste","Início da Peste","Início da Peste","Surto da Peste","Surto da Peste","Surto da Peste","Surto da Peste","A Peste","A Peste","A Peste","A Peste",
	
]


func _ready():
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	
	
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

# Esta função (start_game) não mudou, mas é chamada em um momento diferente
func start_game(player_id, opponent_id_arg):
	
	host_ip_label.visible = false
	# Instancia as cenas
	var player_field = player_field_scene.instantiate()
	var opponent_field = opponent_field_scene.instantiate()
	
	if player_id == 1:
		player_field.name = "1"
		opponent_field.name = "2"
	else:
		player_field.name = "2"
		opponent_field.name = "1"
	
	add_child(player_field)
	add_child(opponent_field)
	
	# Define a autoridade
	player_field.set_multiplayer_authority(multiplayer.get_unique_id())
	opponent_field.set_multiplayer_authority(opponent_id_arg)

	await get_tree().process_frame
	await get_tree().process_frame 
	
	if multiplayer.is_server():
		print("Host: Sincronizando decks...")
		
		# 1. Embaralha os decks (APENAS NO HOST)
		deck_1_list.shuffle()
		deck_2_list.shuffle()

		if opponent_peer_id == 0:
			print("ERRO: ID do oponente desconhecido!")
			return

		# --- INÍCIO DA CORREÇÃO DE RPC ---
		
		# 3. Pegamos a referência para os BattleManagers de cada jogador
		# (O script multiplayer.gd está em /root/Main, então podemos usar get_node)
		var bm_host = get_node("/root/Main/1/BattleManager")
		var bm_client = get_node("/root/Main/2/BattleManager")
		
		if not is_instance_valid(bm_host) or not is_instance_valid(bm_client):
			print("ERRO CRÍTICO: BattleManagers não encontrados! Abortando.")
			return

		# Sintaxe correta:
		# get_node(caminho).rpc_id(ID_DO_PEER, "nome_da_funcao", argumentos...)
		
		# HOST (peer 1): Executa as funções no nó bm_host
		bm_host.rpc_id(1, "rpc_set_my_deck", deck_1_list)
		bm_host.rpc_id(1, "rpc_set_opponent_deck_size", deck_2_list.size())
		
		# CLIENTE (opponent_peer_id): Executa as funções no nó bm_client
		bm_client.rpc_id(opponent_peer_id, "rpc_set_my_deck", deck_2_list)
		bm_client.rpc_id(opponent_peer_id, "rpc_set_opponent_deck_size", deck_1_list.size())

		# 4. Espera a sincronização
		await get_tree().create_timer(0.5).timeout 
		
		print("Host: Enviando RPCs para comprar mãos iniciais...")

		# 5. Manda comprar as cartas (usando as mesmas referências)
		for i in range(Constants.STARTING_HAND_SIZE): 
			# Chamadas para o HOST (peer 1)
			bm_host.rpc_id(1, "rpc_draw_my_card")
			bm_host.rpc_id(1, "rpc_draw_opponent_card")
			
			# Chamadas para o CLIENTE (opponent_peer_id)
			bm_client.rpc_id(opponent_peer_id, "rpc_draw_my_card")
			bm_client.rpc_id(opponent_peer_id, "rpc_draw_opponent_card")
			
			await get_tree().create_timer(0.1).timeout
		
		print("Host: Iniciando o primeiro turno.")
		
		bm_host.rpc_id(1, "start_turn", "Jogador")
		bm_client.rpc_id(opponent_peer_id, "start_turn", "Oponente")
