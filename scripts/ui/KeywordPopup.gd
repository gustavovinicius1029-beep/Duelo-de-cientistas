extends Control

@onready var title_label = $TitleLabel
@onready var description_label = $DescriptionLabel

func _ready():
	hide() # Começa escondido
	# Garante que o popup não bloqueie o mouse de outros elementos
	mouse_filter = MOUSE_FILTER_IGNORE

func show_popup(keyword_name: String, description: String):
	title_label.text = "[b]" + keyword_name + "[b]"
	description_label.text = "[b]" + description + "[b]"
	show()

func hide_popup():
	hide()
