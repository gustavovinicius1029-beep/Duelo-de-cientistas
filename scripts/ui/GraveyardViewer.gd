extends Control

@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var card_grid = $Panel/VBoxContainer/ScrollContainer/CardGrid
@onready var close_button = $Panel/VBoxContainer/CloseButton
@onready var close_area = $CloseArea

const CARD_SCENE = preload("res://scenes/card.tscn")
var card_database_ref = preload("res://scripts/card_database.gd")
var current_open_popup: Node2D = null
var current_popup_original_parent: Node = null

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	close_area.pressed.connect(_on_close_pressed)
	hide()

func _on_close_pressed():
	for cell in card_grid.get_children():
		if cell is Label: continue # Pula o label "(Vazio)"
		if cell.get_child_count() > 0:
			var card = cell.get_child(0)
			if is_instance_valid(card) and card.has_node("CardDetailsPopup"):
				card.details_popup.hide_popup()
	_hide_current_popup()
	hide()

func populate_and_show(card_names_array: Array, title_text: String):
	# --- DEBUG (Pode manter ou remover) ---
	print("---------------------------------")
	print("GraveyardViewer: populate_and_show() foi chamado.")
	print("GraveyardViewer: Tentando mostrar " + title_text)
	print("GraveyardViewer: Recebida lista de cartas: ", card_names_array)
	# --- FIM DEBUG ---

	# 1. Limpar cartas antigas
	for child in card_grid.get_children():
		child.queue_free()

	# 2. Definir o título
	title_label.text = title_text

	# 3. Verificar se está vazio
	if card_names_array.is_empty():
		print("GraveyardViewer: A lista está vazia. Mostrando '(Vazio)'.") # DEBUG
		var empty_label = Label.new()
		empty_label.text = "(Vazio)"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		card_grid.add_child(empty_label)
		show()
		return

	# --- DEFINIÇÕES DAS CÉLULAS ---
	# Define o tamanho de cada "célula" na grade.
	# A carta (em escala 0.6) será colocada dentro disso.
	# Você pode ajustar estes valores para mudar o espaçamento.
	const CELL_WIDTH = 90
	const CELL_HEIGHT = 130
	const CARD_SCALE_VEC = Vector2(0.6, 0.6)
	# --- FIM DAS DEFINIÇÕES ---
	
	print("GraveyardViewer: Começando a popular a grade...") # DEBUG
	for card_name in card_names_array:
		
		if not card_database_ref.CARDS.has(card_name):
			print("!!!! ERRO: '", card_name, "' NÃO foi encontrada no card_database. Pulando.")
			continue 
		
		print("GraveyardViewer: '", card_name, "' encontrada! Instanciando...") # DEBUG

		# --- MUDANÇA PRINCIPAL AQUI ---
		
		# 1. Crie a "célula" de UI (o wrapper Control)
		var card_cell = Control.new()
		# 2. Dê um tamanho mínimo à célula. ISSO É OBRIGATÓRIO.
		card_cell.custom_minimum_size = Vector2(CELL_WIDTH, CELL_HEIGHT)
		
		# 3. Adicione a CÉLULA (Control) à grade (GridContainer)
		card_cell.mouse_filter = Control.MOUSE_FILTER_PASS
		card_grid.add_child(card_cell)
		
		
		# 4. Agora, instancie a CARTA (Node2D)
		var new_card = CARD_SCENE.instantiate()
		new_card.is_in_viewer_mode = true
		# 5. Adicione a CARTA como filha da CÉLULA
		card_cell.add_child(new_card)
		new_card.show_behind_parent = false
		# --- FIM DA MUDANÇA ---
		
		card_cell.gui_input.connect(_on_card_cell_gui_input.bind(new_card))

		# Preenche os dados (como antes)
		var card_data = card_database_ref.CARDS[card_name]
		new_card.card_name = card_name
		new_card.attack = card_data.get("ataque", 0)
		new_card.base_health = card_data.get("vida", 0)
		new_card.current_health = card_data.get("vida", 0)
		new_card.description = card_data.get("desc", "")
		new_card.card_type = card_data.get("tipo", "")
		new_card.energy_cost = card_data.get("custo_energy", 0)
		new_card.energy_generation = card_data.get("gera_energy", 0)
		
		var ability_script_path = card_data.get("habilidade_path", null)
		if ability_script_path != null:
			new_card.ability_script = load(ability_script_path).new()
		
		var card_image_path = card_data.get("art_path", null)
		if card_image_path != null:
			new_card.set_card_image_texture(card_image_path)
		
		new_card.card_data_ref = {
			"name": card_name,
			"attack": new_card.attack,
			"base_health": new_card.base_health,
			"current_health": new_card.current_health,
			"description": new_card.description,
			"type": new_card.card_type,
			"cost": new_card.energy_cost,
			"energy_gen": new_card.energy_generation
		}
		
		# Configura a exibição e a escala
		new_card.setup_card_display()
		new_card.scale = CARD_SCALE_VEC
		
		# 6. Centraliza a CARTA (Node2D) dentro da CÉLULA (Control)
		# (Isso assume que o ponto (0,0) da sua carta é o centro dela)
		new_card.position = Vector2(CELL_WIDTH / 2, CELL_HEIGHT / 2)
		new_card.animation_player.play("card_flip")

	# 5. Mostrar o pop-up
	print("GraveyardViewer: População da grade terminada. Mostrando pop-up.") # DEBUG
	show()

func _on_card_cell_gui_input(event: InputEvent, card: Node2D):
	# 1. Verificamos se é o clique que queremos
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()):
		return

	# 2. Verificamos a carta clicada
	if not is_instance_valid(card):
		return
		
	# --- LÓGICA DE TOGGLE CORRIGIDA ---
	
	# CASO 1: Já existe um popup aberto E a carta que clicamos é a "dona" desse popup?
	if is_instance_valid(current_open_popup) and current_popup_original_parent == card:
		# Sim. O usuário está clicando na carta que já está aberta.
		# Então, apenas feche.
		_hide_current_popup()
		
	# CASO 2: O usuário clicou em uma carta diferente OU nenhum popup estava aberto.
	else:
		# Primeiro, feche qualquer popup que possa estar aberto.
		_hide_current_popup()
		
		# Agora, verifique se esta nova carta tem um popup para mostrar
		# (Esta verificação é segura, pois o popup dela ainda não foi movido)
		if card.has_node("CardDetailsPopup"):
			# Abra o popup da carta clicada.
			_show_popup(card, card.details_popup)
			
func _hide_current_popup():
	if not is_instance_valid(current_open_popup):
		return
		
	current_open_popup.hide_popup()
	
	# Remove o popup do 'GraveyardViewer'
	if current_open_popup.get_parent() == self:
		remove_child(current_open_popup)
		
	# Devolve o popup ao seu "dono" original
	if is_instance_valid(current_popup_original_parent):
		current_popup_original_parent.add_child(current_open_popup)
		
	current_open_popup = null
	current_popup_original_parent = null

# Função para pegar, mover e mostrar o popup
func _show_popup(card: Node2D, popup: Node2D):
	current_popup_original_parent = card
	card.remove_child(popup)
	add_child(popup)
	current_open_popup = popup
	popup.show_popup(card.card_data_ref)
	popup.global_position = Vector2(225.0,450)
	popup.scale = Vector2(0.6,0.6)
