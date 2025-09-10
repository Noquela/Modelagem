class_name DiscreteEvent
extends RefCounted

## Classe base para todos os eventos discretos do simulador
## Cada evento representa uma mudança de estado que acontece em um momento específico

enum EventType {
	CAR_SPAWN,
	CAR_ARRIVAL,
	CAR_DEPARTURE,
	LIGHT_CHANGE,
	QUEUE_PROCESS
}

# Propriedades do evento
var event_time: float
var event_type: EventType
var entity_id: int
var data: Dictionary = {}

# Para ordenação na fila de eventos
var priority: int = 0

func _init(time: float, type: EventType, id: int = -1, event_data: Dictionary = {}):
	event_time = time
	event_type = type
	entity_id = id
	data = event_data

## Executa o evento no simulador
func execute(simulator) -> void:
	match event_type:
		EventType.CAR_SPAWN:
			_execute_car_spawn(simulator)
		EventType.CAR_ARRIVAL:
			_execute_car_arrival(simulator)
		EventType.CAR_DEPARTURE:
			_execute_car_departure(simulator)
		EventType.LIGHT_CHANGE:
			_execute_light_change(simulator)
		EventType.QUEUE_PROCESS:
			_execute_queue_process(simulator)

## Implementações específicas por tipo de evento

func _execute_car_spawn(simulator) -> void:
	print("Executing CAR_SPAWN at time %.2f for entity %d" % [event_time, entity_id])
	# Será implementado no Sprint 2

func _execute_car_arrival(simulator) -> void:
	print("Executing CAR_ARRIVAL at time %.2f for entity %d" % [event_time, entity_id])
	# Será implementado no Sprint 2

func _execute_car_departure(simulator) -> void:
	print("Executing CAR_DEPARTURE at time %.2f for entity %d" % [event_time, entity_id])
	# Será implementado no Sprint 2

func _execute_light_change(simulator) -> void:
	print("Executing LIGHT_CHANGE at time %.2f" % [event_time])
	# Será implementado no Sprint 3

func _execute_queue_process(simulator) -> void:
	print("Executing QUEUE_PROCESS at time %.2f" % [event_time])
	# Será implementado no Sprint 3

## Comparação para ordenação (eventos mais cedo primeiro)
func compare_time(other_event: DiscreteEvent) -> bool:
	if event_time == other_event.event_time:
		return priority > other_event.priority  # Maior prioridade primeiro
	return event_time < other_event.event_time

## Debug info
func get_debug_string() -> String:
	var type_name = EventType.keys()[event_type]
	return "[%s] T:%.2f ID:%d Priority:%d" % [type_name, event_time, entity_id, priority]