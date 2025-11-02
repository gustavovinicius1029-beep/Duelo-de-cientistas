extends Control

@onready var title_label = $PanelContainer/VBoxContainer/TitleLabel
@onready var description_label = $PanelContainer/VBoxContainer/DescriptionLabel

func _ready():
	hide() # Começa escondido
	# Garante que o popup não bloqueie o mouse de outros elementos
	mouse_filter = MOUSE_FILTER_IGNORE

func show_popup(keyword_name: String, description: String):
	title_label.text = keyword_name
	description_label.text = description
	show()

func hide_popup():
	hide()
