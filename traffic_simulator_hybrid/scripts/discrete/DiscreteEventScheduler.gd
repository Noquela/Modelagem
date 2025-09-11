# scripts/discrete/DiscreteEventScheduler.gd
class_name DiscreteEventScheduler
extends RefCounted

enum EventType {
    CAR_SPAWN,
    CAR_ARRIVE_INTERSECTION, 
    CAR_START_WAITING,
    CAR_START_CROSSING,
    CAR_EXIT_INTERSECTION,
    CAR_EXIT_MAP,
    LIGHT_CHANGE
}

var future_events: Array[DiscreteEvent] = []
var current_time: float = 0.0
var event_id_counter: int = 0

signal event_executed(event: DiscreteEvent)

func schedule_event(event_time: float, event_type: EventType, entity_id: int, data: Dictionary = {}):
    var event = DiscreteEvent.new()
    event.id = event_id_counter
    event.time = event_time  
    event.type = event_type
    event.entity_id = entity_id
    event.data = data
    
    # Inserir ordenado por tempo
    _insert_ordered(event)
    event_id_counter += 1
    
    print("📅 Event scheduled: %s at %.2fs" % [EventType.keys()[event_type], event_time])

func process_events_until(target_time: float):
    """Processa todos eventos até target_time"""
    while not future_events.is_empty() and future_events[0].time <= target_time:
        var event = future_events.pop_front()
        current_time = event.time
        
        print("⚡ Executing: %s at %.2fs" % [EventType.keys()[event.type], event.time])
        event_executed.emit(event)

func _insert_ordered(event: DiscreteEvent):
    # Binary search para inserção eficiente
    var left = 0
    var right = future_events.size()
    
    while left < right:
        var mid = (left + right) / 2
        if future_events[mid].time <= event.time:
            left = mid + 1
        else:
            right = mid
    
    future_events.insert(left, event)

func get_event_count() -> int:
    return future_events.size()

func clear_events():
    future_events.clear()

func get_next_event_time() -> float:
    if future_events.is_empty():
        return INF
    return future_events[0].time