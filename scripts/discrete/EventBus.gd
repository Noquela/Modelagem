extends Node

var _events_queue = []
var _subscribers = {}

func _ready():
	print("🔌 EventBus inicializado")

func subscribe(event_name: String, callable: Callable):
	if not _subscribers.has(event_name):
		_subscribers[event_name] = []
	_subscribers[event_name].append(callable)

func emit_event(event_name: String, data = null):
	if _subscribers.has(event_name):
		for callable in _subscribers[event_name]:
			callable.call(data)

func queue_event(event_name: String, data = null, delay: float = 0.0):
	_events_queue.append({
		"event": event_name,
		"data": data,
		"time": Time.get_ticks_msec() / 1000.0 + delay
	})

func _process(_delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	for i in range(_events_queue.size() - 1, -1, -1):
		var event_data = _events_queue[i]
		if current_time >= event_data.time:
			emit_event(event_data.event, event_data.data)
			_events_queue.remove_at(i)