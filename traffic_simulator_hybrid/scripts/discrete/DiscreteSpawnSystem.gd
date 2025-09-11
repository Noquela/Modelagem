# scripts/discrete/DiscreteSpawnSystem.gd
class_name DiscreteSpawnSystem
extends RefCounted

# TAXAS MUITO MAIORES para trânsito intenso realista + SUPORTE A MÚLTIPLAS PISTAS
const SPAWN_RATES = {
    "west_east_lane0": 0.4,      # ~2.5s entre carros - pista sul
    "west_east_lane1": 0.35,     # ~2.9s entre carros - pista norte  
    "east_west_lane0": 0.4,      # ~2.5s entre carros - pista norte
    "east_west_lane1": 0.35,     # ~2.9s entre carros - pista sul
    "south_north": 0.3           # ~3.3s entre carros - pista única
}

# DEFINIÇÕES DE PISTAS COMO NO SISTEMA 3D - CORRIGIDAS COM ALTURA
const LANE_POSITIONS = {
    "west_east": {
        0: Vector3(-35, 0.5, -1.25),  # Pista sul (faixa inferior) - ALTURA CORRIGIDA
        1: Vector3(-35, 0.5, 1.25)    # Pista norte (faixa superior) - ALTURA CORRIGIDA
    },
    "east_west": {
        0: Vector3(35, 0.5, 1.25),    # Pista norte (faixa superior) - ALTURA CORRIGIDA  
        1: Vector3(35, 0.5, -1.25)    # Pista sul (faixa inferior) - ALTURA CORRIGIDA
    },
    "south_north": {
        0: Vector3(0, 0.5, 35)        # Pista única - ALTURA CORRIGIDA
    }
}

var scheduler: DiscreteEventScheduler
var traffic_manager: DiscreteTrafficManager
var next_car_id: int = 1
var total_spawned: int = 0
var active_cars: Dictionary = {}  # car_id -> DiscreteCar

func _init(event_scheduler: DiscreteEventScheduler, traffic_mgr: DiscreteTrafficManager):
    scheduler = event_scheduler
    traffic_manager = traffic_mgr
    schedule_initial_spawns()

func schedule_initial_spawns():
    """Agenda primeiros spawns para cada direção e pista"""
    for spawn_key in SPAWN_RATES.keys():
        var first_spawn_time = calculate_next_spawn_time(spawn_key)
        schedule_spawn_event(spawn_key, first_spawn_time)

func calculate_next_spawn_time(spawn_key: String) -> float:
    """Calcula próximo spawn baseado na taxa"""
    var rate = SPAWN_RATES[spawn_key]
    var base_interval = 1.0 / rate  # ~2.5s para main roads, ~3.3s para cross
    
    # Aleatoriedade MENOR para trânsito mais consistente
    var randomness = randf_range(0.8, 1.4)  # ±20% (menor variação)
    var interval = base_interval * randomness
    
    return scheduler.current_time + interval

func schedule_spawn_event(spawn_key: String, spawn_time: float):
    """Agenda evento de spawn"""
    var direction_lane = parse_spawn_key(spawn_key)
    
    scheduler.schedule_event(
        spawn_time,
        DiscreteEventScheduler.EventType.CAR_SPAWN,
        next_car_id,
        {
            "car_id": next_car_id,
            "direction": direction_lane.direction,
            "lane": direction_lane.lane,
            "spawn_key": spawn_key,
            "spawn_time": spawn_time
        }
    )
    
    next_car_id += 1

func parse_spawn_key(spawn_key: String) -> Dictionary:
    """Converte spawn_key em direção e pista"""
    if spawn_key.contains("_lane"):
        var parts = spawn_key.split("_lane")
        return {"direction": parts[0], "lane": int(parts[1])}
    else:
        return {"direction": spawn_key, "lane": 0}

func handle_spawn_event(event_data: Dictionary):
    """Processa evento de spawn"""
    var car_id = event_data.car_id
    var direction = event_data.direction
    var lane = event_data.get("lane", 0)
    var spawn_key = event_data.get("spawn_key", direction)
    
    print("🚗 Spawning car %d (%s lane %d)" % [car_id, direction, lane])
    
    # Criar carro discreto com pista específica
    var car = create_discrete_car(car_id, direction, lane)
    active_cars[car_id] = car
    
    # Planejar jornada completa com pequeno delay para garantir spawn visual
    var journey = DiscreteCarJourney.new(car, scheduler, traffic_manager, self)
    journey.plan_complete_journey()
    
    total_spawned += 1
    
    # Agendar próximo spawn nesta direção e pista
    var next_spawn_time = calculate_next_spawn_time(spawn_key)
    schedule_spawn_event(spawn_key, next_spawn_time)

func create_discrete_car(car_id: int, direction: String, lane: int = 0) -> DiscreteCar:
    """Cria carro discreto com personalidade aleatória e pista específica"""
    var personalities = ["aggressive", "conservative", "elderly", "normal"]
    var personality = personalities[randi() % personalities.size()]
    
    var car = DiscreteCar.new()
    car.id = car_id
    car.direction = direction
    car.lane = lane
    car.set_personality(personality)
    car.spawn_time = scheduler.current_time
    car.position = get_spawn_position_for_lane(direction, lane)
    
    return car

func get_spawn_position_for_lane(direction: String, lane: int) -> Vector3:
    """Obtém posição de spawn para direção e pista específica"""
    if direction in LANE_POSITIONS and lane in LANE_POSITIONS[direction]:
        var position = LANE_POSITIONS[direction][lane]
        print("✅ Spawn position for %s lane %d: %s" % [direction, lane, position])
        return position
    
    # Fallback com altura corrigida  
    print("⚠️ Using fallback position for %s lane %d" % [direction, lane])
    match direction:
        "west_east": return Vector3(-35, 0.5, -1.25)
        "east_west": return Vector3(35, 0.5, 1.25)
        "south_north": return Vector3(0, 0.5, 35)
    
    return Vector3(0, 0.5, 0)

func get_car_by_id(car_id: int) -> DiscreteCar:
    return active_cars.get(car_id, null)

func remove_car(car_id: int):
    active_cars.erase(car_id)

func get_active_cars() -> Dictionary:
    """Expõe carros ativos para IDM discreto"""
    return active_cars

func get_total_cars_spawned() -> int:
    return total_spawned