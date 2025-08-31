extends Node
class_name TrafficManager

signal stats_updated(stats)

# TIMING EXATO DO HTML - 37 segundos total
const CYCLE_TIMES = {
	"green_time": 15.0,
	"yellow_time": 3.0,
	"safety_time": 1.0,
	"total_cycle": 37.0
}

var main_road_state = "red"  # North-South (principal)
var cross_road_state = "red"  # East-West (transversal)
var cycle_start_time: float = 0.0

var cars: Array = []
var traffic_lights: Array[Node3D] = []
var spawn_points: Array[Node3D] = []

var is_paused: bool = false
var simulation_time: float = 0.0
var target_fps: int = 60

# Performance tracking
var frame_time_samples: Array[float] = []
var max_samples: int = 60

# Analytics data - COPIAR do HTML
var analytics_data = {
	"total_cars_spawned": 0,
	"cars_passed_through": 0,
	"average_wait_time": 0.0,
	"throughput_per_second": 0.0,
	"congestion_level": 0.0
}

func _ready():
	cycle_start_time = Time.get_time_dict_from_system()["second"]
	add_to_group("traffic_manager")
	print("Traffic Manager initialized - Timing: 37s cycle (15s green, 3s yellow, 1s safety)")
	set_process(true)

func _process(delta):
	if is_paused:
		return
		
	simulation_time += delta
	update_traffic_lights()
	update_performance_metrics(delta)
	update_analytics()
	emit_signal("stats_updated", get_current_stats())

func update_traffic_lights():
	# LÓGICA EXATA DO HTML - baseada no tempo atual
	var current_time = Time.get_time_dict_from_system()["second"]
	var elapsed = fmod(current_time - cycle_start_time, CYCLE_TIMES.total_cycle)
	
	# ESTADOS EXATOS DO HTML:
	if elapsed < 15.0:
		# Fase 1: Rua principal VERDE, transversal VERMELHO
		main_road_state = "green"
		cross_road_state = "red"
	elif elapsed < 18.0:
		# Fase 2: Rua principal AMARELO, transversal VERMELHO
		main_road_state = "yellow"
		cross_road_state = "red"
	elif elapsed < 19.0:
		# Fase 3: TEMPO DE SEGURANÇA - ambos VERMELHO
		main_road_state = "red"
		cross_road_state = "red"
	elif elapsed < 34.0:
		# Fase 4: Rua principal VERMELHO, transversal VERDE
		main_road_state = "red"
		cross_road_state = "green"
	else:
		# Fase 5: Rua principal VERMELHO, transversal AMARELO
		main_road_state = "red"
		cross_road_state = "yellow"
	
	# Atualizar semáforos visuais
	update_traffic_light_visuals()

func update_traffic_light_visuals():
	for light in traffic_lights:
		if not light or not light.has_method("set_direction"):
			continue
			
		var direction = light.name.replace("TrafficLight_", "")
		var state = "red"
		
		# Main road = North/South, Cross road = East/West
		if direction in ["North", "South"]:
			state = main_road_state
		elif direction in ["East", "West"]:
			state = cross_road_state
		
		# Definir o estado no semáforo
		if light.has_method("set_light_state"):
			light.set_light_state(state)

func get_light_state_for_direction(direction: String) -> String:
	# FUNÇÃO CRÍTICA - compatível com a lógica do HTML
	match direction:
		"North", "South":
			return main_road_state
		"East", "West":
			return cross_road_state
		_:
			return "red"

func is_safe_to_proceed(direction: String) -> bool:
	# LÓGICA DE SEGURANÇA DO HTML
	var state = get_light_state_for_direction(direction)
	return state == "green"

func can_proceed_on_yellow(direction: String, distance_to_intersection: float, current_speed: float) -> bool:
	# LÓGICA DO AMARELO - baseada no HTML
	var state = get_light_state_for_direction(direction)
	if state != "yellow":
		return false
		
	# Calcular se pode parar com segurança
	var stopping_distance = (current_speed * current_speed) / (2.0 * 8.0)  # desaceleração padrão
	return distance_to_intersection < stopping_distance + 3.0  # margem de segurança

func update_performance_metrics(delta: float):
	frame_time_samples.append(delta)
	if frame_time_samples.size() > max_samples:
		frame_time_samples.pop_front()

func get_average_fps() -> float:
	if frame_time_samples.is_empty():
		return target_fps
	
	var sum = 0.0
	for sample in frame_time_samples:
		sum += sample
	
	return 1.0 / (sum / frame_time_samples.size())

func get_current_stats() -> Dictionary:
	return {
		"simulation_time": simulation_time,
		"active_cars": cars.size(),
		"fps": get_average_fps(),
		"total_spawned": analytics_data.total_cars_spawned,
		"throughput": analytics_data.throughput_per_second,
		"congestion": analytics_data.congestion_level,
		"main_road_state": main_road_state,
		"cross_road_state": cross_road_state,
		"cycle_time": fmod(Time.get_time_dict_from_system()["second"] - cycle_start_time, CYCLE_TIMES.total_cycle)
	}

func pause_simulation():
	is_paused = !is_paused
	get_tree().paused = is_paused
	print("Simulation ", "paused" if is_paused else "resumed")

func register_car(car):
	cars.append(car)
	analytics_data.total_cars_spawned += 1

func unregister_car(car):
	cars.erase(car)
	analytics_data.cars_passed_through += 1

func register_traffic_light(light: Node3D):
	traffic_lights.append(light)

func register_spawn_point(spawn: Node3D):
	spawn_points.append(spawn)

func update_analytics():
	# COPIAR lógica de analytics do HTML/2D
	if simulation_time > 0:
		analytics_data.throughput_per_second = analytics_data.cars_passed_through / simulation_time
	
	# Calcular congestionamento (0-1)
	var total_capacity = spawn_points.size() * 20  # Estimativa
	analytics_data.congestion_level = min(cars.size() / float(total_capacity), 1.0)

func get_analytics_data() -> Dictionary:
	return analytics_data

# FUNÇÃO HELPER para debug
func get_debug_info() -> String:
	var elapsed = fmod(Time.get_time_dict_from_system()["second"] - cycle_start_time, CYCLE_TIMES.total_cycle)
	return "Cycle: %.1fs | Main: %s | Cross: %s | Cars: %d" % [elapsed, main_road_state, cross_road_state, cars.size()]