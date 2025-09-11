# scripts/discrete/DiscreteTrafficManager.gd
class_name DiscreteTrafficManager
extends RefCounted

# TIMING EXATO do traffic_simulator_3d
const LIGHT_CYCLE = {
    "total": 40.0,
    "main_green": 20.0,    # 0-20s
    "main_yellow": 3.0,    # 20-23s  
    "safety1": 1.0,        # 23-24s
    "cross_green": 10.0,   # 24-34s
    "cross_yellow": 3.0,   # 34-37s
    "safety2": 3.0         # 37-40s
}

var scheduler: DiscreteEventScheduler
var cycle_start_time: float = 0.0

func _init(event_scheduler: DiscreteEventScheduler):
    scheduler = event_scheduler
    schedule_light_cycle()

func schedule_light_cycle():
    """Agenda todo o ciclo de semáforos"""
    var base_time = scheduler.current_time
    
    # Agendar mudanças exatas
    scheduler.schedule_event(base_time + 20.0, DiscreteEventScheduler.EventType.LIGHT_CHANGE, -1, 
        {"main": "yellow", "cross": "red"})
    scheduler.schedule_event(base_time + 23.0, DiscreteEventScheduler.EventType.LIGHT_CHANGE, -1, 
        {"main": "red", "cross": "red"})
    scheduler.schedule_event(base_time + 24.0, DiscreteEventScheduler.EventType.LIGHT_CHANGE, -1, 
        {"main": "red", "cross": "green"})
    scheduler.schedule_event(base_time + 34.0, DiscreteEventScheduler.EventType.LIGHT_CHANGE, -1, 
        {"main": "red", "cross": "yellow"})
    scheduler.schedule_event(base_time + 37.0, DiscreteEventScheduler.EventType.LIGHT_CHANGE, -1, 
        {"main": "red", "cross": "red"})
    scheduler.schedule_event(base_time + 40.0, DiscreteEventScheduler.EventType.LIGHT_CHANGE, -1, 
        {"main": "green", "cross": "red"})
    
    # Agendar próximo ciclo
    scheduler.schedule_event(base_time + 40.0, DiscreteEventScheduler.EventType.LIGHT_CHANGE, -1, 
        {"action": "schedule_next_cycle"})

func get_light_state_at_time(time: float, direction: String) -> String:
    """Prediz estado do semáforo em qualquer tempo futuro - CONSIDERANDO TEMPOS DE SEGURANÇA"""
    var cycle_time = fmod(time, LIGHT_CYCLE.total)
    
    match direction:
        "west_east", "east_west":  # Rua principal
            if cycle_time < 20.0: return "green"
            elif cycle_time < 23.0: return "yellow"
            elif cycle_time < 24.0: return "red"  # TEMPO DE SEGURANÇA
            elif cycle_time < 34.0: return "red"  # Cross green
            elif cycle_time < 37.0: return "red"  # Cross yellow
            else: return "red"  # TEMPO DE SEGURANÇA FINAL
        "south_north":  # Rua transversal
            if cycle_time < 20.0: return "red"   # Main green
            elif cycle_time < 23.0: return "red" # Main yellow
            elif cycle_time < 24.0: return "red" # TEMPO DE SEGURANÇA
            elif cycle_time < 34.0: return "green"
            elif cycle_time < 37.0: return "yellow"
            else: return "red"  # TEMPO DE SEGURANÇA FINAL
    return "red"

func calculate_wait_time(arrival_time: float, direction: String) -> float:
    """Calcula quanto tempo carro deve esperar"""
    var light_state = get_light_state_at_time(arrival_time, direction)
    
    if light_state == "green":
        return 0.0  # Pode passar
    
    # Calcular tempo até próximo verde
    return get_time_until_green(arrival_time, direction)

func get_time_until_green(time: float, direction: String) -> float:
    """Tempo até próximo verde"""
    var cycle_time = fmod(time, LIGHT_CYCLE.total)
    
    match direction:
        "west_east", "east_west":
            if cycle_time > 20.0:  # Perdeu o verde atual
                return LIGHT_CYCLE.total - cycle_time  # Próximo ciclo
            return 0.0
        "south_north":
            if cycle_time < 24.0:  # Antes do verde
                return 24.0 - cycle_time
            elif cycle_time > 34.0:  # Depois do verde
                return (LIGHT_CYCLE.total - cycle_time) + 24.0  # Próximo ciclo
            return 0.0
    return 0.0

func handle_light_change_event(event_data: Dictionary):
    """Processa eventos de mudança de semáforo"""
    if event_data.has("action") and event_data.action == "schedule_next_cycle":
        # Agendar próximo ciclo completo
        schedule_light_cycle()
        return
    
    # Processar mudança de estado
    var main_state = event_data.get("main", "")
    var cross_state = event_data.get("cross", "")
    
    print("🚦 Light change: Main=%s, Cross=%s" % [main_state, cross_state])