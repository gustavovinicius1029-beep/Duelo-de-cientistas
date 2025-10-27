# scripts/vfx/CombatLineDrawer.gd
extends Node2D

# Estrutura esperada: {attacker_node: [blocker_node1, blocker_node2]}
var declared_blockers: Dictionary = {}
var draw_lines: bool = false

# --- Constantes para Estilo e Curva ---
const LINE_COLOR: Color = Color(0.597, 0.04, 0.046, 0.9) # Vermelho um pouco mais vibrante
const ARROW_COLOR: Color = Color(0.597, 0.04, 0.046, 0.9)
const SHADOW_COLOR: Color = Color(0.1, 0.1, 0.1, 0.5) # Sombra escura semitransparente
const LINE_WIDTH: float = 10.0 # Mais grosso para estilo pixelado
const SHADOW_OFFSET: Vector2 = Vector2(2, 2) # Deslocamento da sombra para profundidade
const ARROWHEAD_LENGTH: float = 18.0 # Comprimento da ponta da seta
const ARROWHEAD_WIDTH: float = 14.0 # Largura da base da ponta da seta
const CURVE_POINTS: int = 15 # Número de segmentos para desenhar a curva (mais = mais suave)
const CURVE_HEIGHT_FACTOR: float = 0.50 # Quão "alta" a curva será (proporcional à distância)

func _draw():
	if not draw_lines or declared_blockers.is_empty():
		return

	# Itera sobre cada ATACANTE que tem bloqueadores
	for attacker in declared_blockers:
		var blockers_list = declared_blockers[attacker]
		# Itera sobre cada BLOQUEADOR daquele atacante
		for blocker in blockers_list:
			# Verifica se ambos ainda são válidos antes de desenhar
			if is_instance_valid(blocker) and is_instance_valid(attacker):
				var start_point = to_local(blocker.global_position)
				var end_point = to_local(attacker.global_position)

				# --- Cálculo da Curva (Bézier Quadrática) ---
				# Ponto médio entre início e fim
				var mid_point = start_point.lerp(end_point, 0.5)
				# Vetor da direção e seu perpendicular
				var direction = (end_point - start_point)
				var perpendicular = direction.orthogonal().normalized()
				# Altura da curva baseada na distância e no fator
				var curve_height = direction.length() * CURVE_HEIGHT_FACTOR
				# Ponto de controle que define a curvatura
				var control_point = mid_point + perpendicular * curve_height

				# --- Gerar Pontos da Curva ---
				var points = PackedVector2Array()
				for i in range(CURVE_POINTS + 1):
					var t = float(i) / CURVE_POINTS # Interpolação de 0.0 a 1.0
					points.append(quadratic_bezier(start_point, control_point, end_point, t))

				# --- Desenhar Sombra da Curva ---
				var shadow_points = PackedVector2Array()
				for p in points:
					shadow_points.append(p + SHADOW_OFFSET)
				draw_polyline(shadow_points, SHADOW_COLOR, LINE_WIDTH, false) # false = sem anti-aliasing

				# --- Desenhar Curva Principal ---
				draw_polyline(points, LINE_COLOR, LINE_WIDTH, false) # false = sem anti-aliasing

				# --- Desenhar Ponta da Seta ---
				if points.size() >= 2:
					# Direção no final da curva
					var end_dir = (points[-1] - points[-2]).normalized()
					# Pontos da base da seta (triângulo)
					var arrow_base1 = points[-1] - end_dir * ARROWHEAD_LENGTH + end_dir.orthogonal() * ARROWHEAD_WIDTH / 2.0
					var arrow_base2 = points[-1] - end_dir * ARROWHEAD_LENGTH - end_dir.orthogonal() * ARROWHEAD_WIDTH / 2.0
					var arrow_points = PackedVector2Array([arrow_base1, points[-1], arrow_base2])

					# Desenhar sombra da ponta da seta
					var shadow_arrow_points = PackedVector2Array()
					for p in arrow_points:
						shadow_arrow_points.append(p + SHADOW_OFFSET)
					draw_polyline(shadow_arrow_points, SHADOW_COLOR, LINE_WIDTH, false)

					# Desenhar ponta da seta principal
					draw_polyline(arrow_points, ARROW_COLOR, LINE_WIDTH, false)


# --- Função Auxiliar: Interpolação de Bézier Quadrática ---
func quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	# p0 = start, p1 = control, p2 = end, t = 0.0 a 1.0
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	return q0.lerp(q1, t)


# --- Funções de controle (mantidas da correção anterior) ---
func update_drawing(blockers_dict: Dictionary, should_draw: bool):
	declared_blockers = blockers_dict.duplicate() # Usa cópia
	var old_draw_lines = draw_lines
	draw_lines = should_draw
	# Força redesenho se deve desenhar e há o que desenhar, OU se não deve mais desenhar (limpar)
	if (draw_lines and not declared_blockers.is_empty()) or (old_draw_lines and not draw_lines):
		queue_redraw()
	# Limpa também se estava desenhando e ficou vazio
	elif old_draw_lines and declared_blockers.is_empty():
		queue_redraw()

func clear_drawing(): #
	if not declared_blockers.is_empty() or draw_lines:
		declared_blockers.clear() # Limpa o dicionário correto
		draw_lines = false
		queue_redraw()
