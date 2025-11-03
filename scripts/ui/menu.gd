extends Control

func _ready():
	# Conecta os sinais dos botões
	$Menu/VBoxContainer/StartButton.pressed.connect(_on_start_button_pressed)
	$Menu/VBoxContainer/QuitButton.pressed.connect(_on_quit_button_pressed)

func _on_start_button_pressed():
	GameManager.start_game()

func _on_quit_button_pressed():
	get_tree().quit()
