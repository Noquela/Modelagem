# scripts/discrete/DiscreteCar.gd
class_name DiscreteCar
extends RefCounted

# VELOCIDADES MAIS REALISTAS URBANAS (m/s) - Reduzidas para movimento suave
const PERSONALITIES = {
    "aggressive": {"speed": 8.0, "reaction": [0.5, 0.8], "yellow_prob": 0.8},  # ~29 km/h
    "conservative": {"speed": 5.0, "reaction": [1.2, 1.5], "yellow_prob": 0.2},  # ~18 km/h
    "elderly": {"speed": 4.0, "reaction": [1.5, 2.0], "yellow_prob": 0.1},       # ~14 km/h
    "normal": {"speed": 6.5, "reaction": [0.8, 1.2], "yellow_prob": 0.5}        # ~23 km/h
}

const SPAWN_POSITIONS = {
    "west_east": Vector3(-35, 0.5, -1.25),   # LEFT_TO_RIGHT - ALTURA CORRIGIDA
    "east_west": Vector3(35, 0.5, 1.25),     # RIGHT_TO_LEFT - ALTURA CORRIGIDA
    "south_north": Vector3(0, 0.5, 35)       # BOTTOM_TO_TOP - ALTURA CORRIGIDA
}

var id: int
var direction: String
var lane: int = 0
var personality: String
var spawn_time: float
var position: Vector3
var current_state: String = "spawned"

# Dados da personalidade
var base_speed: float
var reaction_time: float
var yellow_probability: float

func _init():
    id = -1
    direction = ""
    lane = 0
    personality = "normal"
    spawn_time = 0.0
    position = Vector3.ZERO

func set_personality(p: String):
    personality = p
    var data = PERSONALITIES[p]
    
    base_speed = data.speed
    reaction_time = randf_range(data.reaction[0], data.reaction[1])
    yellow_probability = data.yellow_prob

func get_spawn_position() -> Vector3:
    return SPAWN_POSITIONS.get(direction, Vector3.ZERO)

func calculate_travel_time(distance: float) -> float:
    """Calcula tempo de viagem para uma distância"""
    return distance / base_speed

func should_stop_at_yellow(distance_to_intersection: float) -> bool:
    """Mesma lógica de decisão do Car.gd original"""
    var braking_distance = calculate_braking_distance()
    
    if distance_to_intersection < braking_distance:
        return false  # Muito perto, continua
    elif distance_to_intersection > braking_distance * 2.0:
        return true   # Longe, para
    else:
        # Zona de decisão - usar personalidade
        return randf() > yellow_probability

func calculate_braking_distance() -> float:
    """Distância de frenagem baseada na velocidade"""
    var deceleration = 8.0  # m/s² (padrão)
    return (base_speed * base_speed) / (2.0 * deceleration)

func _to_string() -> String:
    return "DiscreteCar(id=%d, dir=%s, lane=%d, personality=%s)" % [id, direction, lane, personality]