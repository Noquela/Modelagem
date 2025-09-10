class_name SimulationClock
extends RefCounted

## Relógio da simulação discreta
## Controla o tempo simulado de forma independente do tempo real

# Tempo atual da simulação
var current_time: float = 0.0

# Velocidade da simulação (1.0 = tempo real, 2.0 = 2x mais rápido)
var simulation_speed: float = 1.0

# Tempo real do último update
var last_real_time: float = 0.0

# Flag para pausar
var is_paused: bool = false

# Statistics
var total_events_processed: int = 0
var start_time: float = 0.0

func _init(start_time_value: float = 0.0):
	current_time = start_time_value
	start_time = start_time_value
	last_real_time = Time.get_unix_time_from_system()

## Atualiza o tempo da simulação baseado no tempo real
func update(delta_real: float) -> void:
	if is_paused:
		return
	
	# Avança tempo simulado baseado na velocidade
	var delta_sim = delta_real * simulation_speed
	current_time += delta_sim

## Avança tempo para um valor específico (usado pelo event scheduler)
func advance_to(target_time: float) -> void:
	if target_time > current_time:
		current_time = target_time

## Getters
func get_time() -> float:
	return current_time

func get_simulation_speed() -> float:
	return simulation_speed

func get_elapsed_time() -> float:
	return current_time - start_time

## Controles
func pause() -> void:
	is_paused = true
	print("Simulation paused at time %.2f" % current_time)

func resume() -> void:
	is_paused = false
	last_real_time = Time.get_unix_time_from_system()
	print("Simulation resumed at time %.2f" % current_time)

func set_speed(speed: float) -> void:
	simulation_speed = clamp(speed, 0.1, 10.0)
	print("Simulation speed set to %.1fx" % simulation_speed)

func reset(new_start_time: float = 0.0) -> void:
	current_time = new_start_time
	start_time = new_start_time
	is_paused = false
	total_events_processed = 0
	last_real_time = Time.get_unix_time_from_system()
	print("Simulation clock reset to time %.2f" % new_start_time)

## Statistics
func increment_event_count() -> void:
	total_events_processed += 1

func get_events_per_second() -> float:
	var elapsed = get_elapsed_time()
	if elapsed > 0:
		return total_events_processed / elapsed
	return 0.0

## Formatação de tempo para display
func format_time(time_value: float = -1) -> String:
	var t = time_value if time_value >= 0 else current_time
	var hours = int(t / 3600)
	var minutes = int((t % 3600) / 60)
	var seconds = int(t % 60)
	var milliseconds = int((t - floor(t)) * 1000)
	
	if hours > 0:
		return "%02d:%02d:%02d.%03d" % [hours, minutes, seconds, milliseconds]
	else:
		return "%02d:%02d.%03d" % [minutes, seconds, milliseconds]

## Debug info
func get_status() -> Dictionary:
	return {
		"current_time": current_time,
		"formatted_time": format_time(),
		"simulation_speed": simulation_speed,
		"is_paused": is_paused,
		"events_processed": total_events_processed,
		"events_per_second": get_events_per_second(),
		"elapsed_time": get_elapsed_time()
	}