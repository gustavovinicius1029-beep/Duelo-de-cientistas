extends Control

@onready var result_label = $ResultLabel
@onready var menu_button = $Menu/VBoxContainer/MenuButton
@onready var quit_button = $Menu/VBoxContainer/QuitButton

func _ready():
	menu_button.pressed.connect(_on_menu_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

	# Desconecta do multiplayer ao carregar esta cena
	if multiplayer.get_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.set_multiplayer_peer(null)

	# Lê o resultado salvo no GameManager
	if GameManager.player_won:
		result_label.text = "Vitória!"
	else:
		result_label.text = "Derrota!"

func _on_menu_button_pressed():
	GameManager.goto_main_menu()

func _on_quit_button_pressed():
	get_tree().quit()
