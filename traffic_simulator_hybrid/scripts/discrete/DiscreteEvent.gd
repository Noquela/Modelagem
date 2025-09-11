# scripts/discrete/DiscreteEvent.gd
class_name DiscreteEvent
extends RefCounted

var id: int
var time: float
var type: DiscreteEventScheduler.EventType  
var entity_id: int
var data: Dictionary

func _init():
    id = -1
    time = 0.0
    type = DiscreteEventScheduler.EventType.CAR_SPAWN
    entity_id = -1
    data = {}

func _to_string() -> String:
    return "DiscreteEvent(id=%d, time=%.2f, type=%s, entity=%d)" % [
        id, time, DiscreteEventScheduler.EventType.keys()[type], entity_id
    ]