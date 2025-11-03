extends Node

# Guarda o resultado da última partida
var player_won: bool = false

# Função para ir ao menu principal
func goto_main_menu():
	# Garante que estamos desconectados antes de ir ao menu
	if multiplayer.get_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.set_multiplayer_peer(null)
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

# Função para iniciar o jogo (carrega a cena do lobby/multiplayer)
func start_game():
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# Função para mostrar a tela final
func show_end_screen(won: bool):
	player_won = won
	get_tree().change_scene_to_file("res://scenes/end_screen.tscn")
