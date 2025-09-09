extends RefCounted
class_name DiscreteEvent

# Classe simples para representar um evento discreto
# EXATAMENTE como especificado no MASTER_PLAN.md

var time: float                    # Quando o evento acontece
var type: EventTypes.Type         # Tipo do evento
var data: Dictionary              # Dados extras (opcional)

func _init(event_time: float, event_type: EventTypes.Type, event_data: Dictionary = {}):
	time = event_time
	type = event_type
	data = event_data

# Para debug e logs
func get_display_string() -> String:
	return "t=%.2fs - %s" % [time, EventTypes.get_event_name(type)]

# Para ordenação na fila (eventos ordenados por tempo)
func is_before(other: DiscreteEvent) -> bool:
	return time < other.time