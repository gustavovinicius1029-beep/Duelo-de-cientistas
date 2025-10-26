# scripts/CombatLineDrawer.gd
extends Node2D

# AGORA USA declared_blockers: {attacker: [blocker1, blocker2]}
var declared_blockers: Dictionary = {}
var draw_lines: bool = false

const LINE_COLOR: Color = Color.RED
const LINE_WIDTH: float = 3.0

func _draw():
	if not draw_lines or declared_blockers.is_empty():
		return

	# Itera sobre cada ATACANTE que tem bloqueadores
	for attacker in declared_blockers:
		var blockers_list = declared_blockers[attacker]
		# Itera sobre cada BLOQUEADOR daquele atacante
		for blocker in blockers_list:
			# Verifica se ambos ainda são válidos
			if is_instance_valid(blocker) and is_instance_valid(attacker):
				var start_point = to_local(blocker.global_position)
				var end_point = to_local(attacker.global_position)
				draw_line(start_point, end_point, LINE_COLOR, LINE_WIDTH)

# Função atualizada para aceitar declared_blockers
func update_drawing(blockers_dict: Dictionary, should_draw: bool):
	var needs_redraw = (draw_lines != should_draw) or (blockers_dict != declared_blockers)
	declared_blockers = blockers_dict # Atualiza com o novo dicionário
	draw_lines = should_draw
	if needs_redraw:
		queue_redraw()

# Função para limpar
func clear_drawing():
	declared_blockers.clear() # Limpa o dicionário correto
	if draw_lines:
		draw_lines = false
		queue_redraw()
