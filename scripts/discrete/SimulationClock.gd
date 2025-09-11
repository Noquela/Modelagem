extends Node

var simulation_time: float = 0.0
var time_scale: float = 1.0
var is_paused: bool = false

signal tick_second
signal tick_minute  
signal tick_fast  # Tick mais frequente para fluidez

var _last_second: int = 0
var _last_minute: int = 0
var _fast_tick_timer: float = 0.0
var _fast_tick_interval: float = 0.3  # Tick a cada 0.3 segundos

func _ready():
	print("⏰ SimulationClock inicializado")

func _process(delta):
	if not is_paused:
		simulation_time += delta * time_scale
		
		# Fast tick para movimento mais fluido
		_fast_tick_timer += delta
		if _fast_tick_timer >= _fast_tick_interval:
			tick_fast.emit()
			_fast_tick_timer = 0.0
		
		var current_second = int(simulation_time)
		var current_minute = int(simulation_time / 60)
		
		if current_second != _last_second:
			tick_second.emit()
			_last_second = current_second
			
		if current_minute != _last_minute:
			tick_minute.emit()
			_last_minute = current_minute

func pause():
	is_paused = true
	
func resume():
	is_paused = false
	
func reset():
	simulation_time = 0.0
	_last_second = 0
	_last_minute = 0
	
func set_time_scale(scale: float):
	time_scale = clamp(scale, 0.1, 5.0)

func get_simulation_time() -> float:
	return simulation_time