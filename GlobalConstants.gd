# GlobalConstants.gd
# Este script NÃO estende Node. É um container para constantes globais.

# --- Constantes de Layout e Animação ---
const DEFAULT_CARD_MOVE_SPEED: float = 0.1
const CARD_DRAW_SPEED: float = 0.2
const CARD_WIDTH: int = 120
const HAND_Y_POSITION_PLAYER: int = 930
const HAND_Y_POSITION_OPPONENT: int = 30
const DEFAULT_CARD_SCALE: Vector2 = Vector2(0.6, 0.6)
const CARD_BIGGER_SCALE: Vector2 = Vector2(0.75, 0.75)
const CARD_SMALLER_SCALE: Vector2 = Vector2(0.6, 0.6)
const BATTLE_POS_OFFSET_Y: int = 25

# --- Constantes de Camadas de Colisão (Máscaras de Bits) ---
# Usadas pelo InputManager e potencialmente outros sistemas
const COLLISION_LAYER_CARD: int = 1           # Layer 1 (Bit 0)
const COLLISION_LAYER_SLOT: int = 2           # Layer 2 (Bit 1)
const COLLISION_LAYER_DECK: int = 4           # Layer 3 (Bit 2)
const COLLISION_LAYER_OPPONENT_CARD: int = 8  # Layer 4 (Bit 3)

const MASK_INPUT_CLICK: int = COLLISION_LAYER_CARD | COLLISION_LAYER_SLOT | COLLISION_LAYER_DECK | COLLISION_LAYER_OPPONENT_CARD

const STARTING_HAND_SIZE: int = 7 # Ajuste se necessário (vi 5 e 7 nos scripts)
const INITIAL_PLAYER_HEALTH: int = 20
const OPPONENT_STARTING_HAND_SIZE: int = 5 # Definido no battle_manager

# const ATTACK_ANIMATION_WAIT: float = 0.5
# const CARD_MOVE_WAIT: float = 0.15
# const DESTROY_WAIT: float = 0.5
# const SUMMON_WAIT: float = 0.3
# const SPELL_EFFECT_WAIT: float = 0.5
