extends Node
class_name TrafficManager

signal stats_updated(stats)

# TIMING MODIFICADO - rua oeste-leste (mão dupla) fica mais tempo verde que a rua norte
const CYCLE_TIMES = {
	"main_road_green": 20.0,  # Rua oeste-leste (dupla) - tempo verde MAIOR
	"cross_road_green": 10.0, # Rua norte (única) - tempo verde MENOR
	"yellow_time": 3.0,
	"safety_time": 1.0,
	"total_cycle": 40.0  # Novo ciclo total: 20s + 3s + 1s + 10s + 3s + 1s = 40s
}

var main_road_state = "green"  # Rua principal começa VERDE (West/East)
var cross_road_state = "red"   # Rua transversal começa VERMELHA (North) - forma fila
var cycle_start_time: float = 0.0

# SEMÁFOROS PARA PEDESTRES - com margem de segurança
var pedestrian_main_state = "red"    # Atravessar a rua principal (West-East)
var pedestrian_cross_state = "red"   # Atravessar a rua transversal (North-South)
const PEDESTRIAN_SAFETY_MARGIN = 2.0  # 2 segundos de margem antes e depois

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
	cycle_start_time = Time.get_unix_time_from_system()
	add_to_group("traffic_manager")
	# Initialization print removed for performance
	set_process(true)

# MÉTODOS PARA INTEGRAÇÃO COM EVENTOS DISCRETOS
func set_all_lights_state(main_green: bool):
	"""Define estado dos semáforos via eventos discretos"""
	if main_green:
		main_road_state = "green"
		cross_road_state = "red"
	else:
		main_road_state = "red" 
		cross_road_state = "green"
	
	# Aplicar mudanças visuais imediatamente
	apply_traffic_light_states()

func apply_traffic_light_states():
	"""Aplica estados aos semáforos visuais 3D"""
	for light in traffic_lights:
		if light.has_method("set_state"):
			# Semáforos 0 e 1: rua principal (West-East)
			if light.name in ["TrafficLight", "TrafficLight2"]:
				light.set_state(main_road_state)
			# Semáforo 2: rua transversal (South-North)
			elif light.name == "TrafficLight3":
				light.set_state(cross_road_state)

var discrete_event_control: bool = false  # Controle por eventos discretos

func _process(delta):
	if is_paused:
		return
		
	simulation_time += delta
	
	# HÍBRIDO: Se eventos discretos estão controlando, não atualizar timing automático
	if not discrete_event_control:
		update_traffic_lights()
	else:
		# Apenas aplicar estados visuais (controlados por eventos discretos)
		apply_traffic_light_states()
	
	update_performance_metrics(delta)
	update_analytics()
	emit_signal("stats_updated", get_current_stats())

func update_traffic_lights():
	# NOVO CICLO: Rua oeste-leste (dupla) fica mais tempo verde
	var current_time = Time.get_unix_time_from_system()
	var elapsed = fmod(current_time - cycle_start_time, CYCLE_TIMES.total_cycle)
	var phase = elapsed / CYCLE_TIMES.total_cycle  # Fase normalizada (0-1)
	
	# NOVO CICLO (40s total): 20s verde oeste-leste + 3s amarelo + 1s segurança + 10s verde norte + 3s amarelo + 1s segurança
	if phase < (20.0/40.0):  # 0-20s
		# Rua principal (oeste-leste) VERDE por 20s - MAIS TEMPO
		main_road_state = "green"
		cross_road_state = "red"
	elif phase < (23.0/40.0):  # 20-23s
		# Rua principal amarelo (3s)
		main_road_state = "yellow"
		cross_road_state = "red"
	elif phase < (24.0/40.0):  # 23-24s
		# TEMPO DE SEGURANÇA: ambos vermelhos (1s)
		main_road_state = "red"
		cross_road_state = "red"
	elif phase < (34.0/40.0):  # 24-34s
		# Rua norte VERDE por apenas 10s - MENOS TEMPO
		main_road_state = "red"
		cross_road_state = "green"
	elif phase < (37.0/40.0):  # 34-37s
		# Rua norte amarelo (3s)
		main_road_state = "red"
		cross_road_state = "yellow"
	else:  # 37-40s
		# TEMPO DE SEGURANÇA FINAL: ambos vermelhos (3s)
		main_road_state = "red"
		cross_road_state = "red"
	
	# 🚶 SEMÁFOROS DE PEDESTRES DISABLED - implementar depois
	# update_pedestrian_lights(phase)
	
	# Debug dos estados dos semáforos - PERFORMANCE: less frequent
	if fmod(simulation_time, 10.0) < 0.1:  # A cada 10 segundos (was 3s)
		pass  # Debug print removed for performance - only critical info in console
	
	# Atualizar apenas os 3 semáforos corretos
	update_traffic_light_visuals()

func update_pedestrian_lights(phase: float):
	# 🚶 LÓGICA DOS SEMÁFOROS DE PEDESTRES COM MARGEM DE SEGURANÇA
	# Pedestres podem atravessar apenas quando carros estão com VERMELHO completo
	# Margem de 2s antes e depois dos carros mudarem para verde
	
	var margin_normalized = PEDESTRIAN_SAFETY_MARGIN / CYCLE_TIMES.total_cycle  # 2s/40s = 0.05
	
	# ATRAVESSAR RUA PRINCIPAL (West-East): quando cross_road está verde
	# Carros da rua transversal (North-South) estão verdes: 24-34s (phase 0.6-0.85)
	# Pedestres podem atravessar: 26-32s (com margem de 2s cada lado)
	var cross_green_start = 24.0/40.0  # 0.6
	var cross_green_end = 34.0/40.0    # 0.85
	
	if phase > (cross_green_start + margin_normalized) and phase < (cross_green_end - margin_normalized):
		pedestrian_main_state = "walk"  # Pode atravessar a rua principal
	else:
		pedestrian_main_state = "dont_walk"
	
	# ATRAVESSAR RUA TRANSVERSAL (North-South): quando main_road está verde  
	# Carros da rua principal (West-East) estão verdes: 0-20s (phase 0.0-0.5)
	# Pedestres podem atravessar: 2-18s (com margem de 2s cada lado)
	var main_green_start = 0.0/40.0   # 0.0
	var main_green_end = 20.0/40.0    # 0.5
	
	if phase > (main_green_start + margin_normalized) and phase < (main_green_end - margin_normalized):
		pedestrian_cross_state = "walk"  # Pode atravessar a rua transversal
	else:
		pedestrian_cross_state = "dont_walk"

func update_traffic_light_visuals():
	# APENAS 3 SEMÁFOROS como no HTML original
	for light in traffic_lights:
		if not light or not light.has_method("set_light_state"):
			continue
			
		var light_name = light.name
		var state = "red"
		
		# LÓGICA EXATA DO HTML:
		# main_road_state controla LEFT_TO_RIGHT e RIGHT_TO_LEFT (semáforos 1 e 2)
		# cross_road_state controla TOP_TO_BOTTOM (semáforo 3)
		if "main_road" in light_name:
			state = main_road_state
		elif "cross_road" in light_name:
			state = cross_road_state
		
		# Definir o estado no semáforo
		light.set_light_state(state)

func get_light_state_for_direction(direction: String) -> String:
	# FUNÇÃO CRÍTICA - LÓGICA EXATA DO HTML
	match direction:
		"West":  # LEFT_TO_RIGHT
			return main_road_state
		"East":  # RIGHT_TO_LEFT  
			return main_road_state
		"North": # TOP_TO_BOTTOM 
			return cross_road_state
		"South": # BOTTOM_TO_TOP
			return cross_road_state
		_:
			return "red"  # Direção desconhecida

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
		"total_cars_spawned": analytics_data.total_cars_spawned,
		"cars_passed_through": analytics_data.cars_passed_through,
		"throughput": analytics_data.throughput_per_second,
		"congestion": analytics_data.congestion_level,
		"average_wait_time": analytics_data.average_wait_time,
		"average_speed": calculate_average_speed(),
		"max_queue_length": calculate_max_queue_length(),
		"personality_stats": calculate_personality_stats(),
		"main_road_state": main_road_state,
		"cross_road_state": cross_road_state,
		# "pedestrian_main_state": pedestrian_main_state,   # DISABLED
		# "pedestrian_cross_state": pedestrian_cross_state, # DISABLED
		"cycle_time": fmod(Time.get_unix_time_from_system() - cycle_start_time, CYCLE_TIMES.total_cycle)
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

# 🚶 FUNÇÕES PARA ACESSAR ESTADOS DOS SEMÁFOROS DE PEDESTRES
func get_pedestrian_main_state() -> String:
	# Estado para atravessar a rua principal (West-East)
	return pedestrian_main_state

func get_pedestrian_cross_state() -> String:
	# Estado para atravessar a rua transversal (North-South)  
	return pedestrian_cross_state

func can_pedestrian_cross_main_road() -> bool:
	# Verifica se pedestre pode atravessar rua principal
	return pedestrian_main_state == "walk"

func can_pedestrian_cross_cross_road() -> bool:
	# Verifica se pedestre pode atravessar rua transversal
	return pedestrian_cross_state == "walk"

# FUNÇÃO HELPER para debug
func calculate_average_speed() -> float:
	# Calcular velocidade média dos carros ativos
	if cars.is_empty():
		return 0.0
	
	var total_speed = 0.0
	for car in cars:
		if car and car.has_method("get_current_speed"):
			total_speed += car.get_current_speed()
	
	return total_speed / cars.size()

func calculate_max_queue_length() -> int:
	# Simular comprimento da fila baseado no congestionamento
	var stopped_cars = 0
	for car in cars:
		if car and car.has_method("get_current_speed"):
			if car.get_current_speed() < 1.0:  # Carro quase parado
				stopped_cars += 1
	
	return stopped_cars

func calculate_personality_stats() -> Dictionary:
	# Contar personalidades dos carros ativos
	var personality_counts = {
		"Aggressive": 0,
		"Conservative": 0,
		"Normal": 0,
		"Elderly": 0
	}
	
	for car in cars:
		if car and car.has_method("get_personality_string"):
			var personality = car.get_personality_string()
			if personality in personality_counts:
				personality_counts[personality] += 1
	
	return personality_counts


func get_debug_info() -> String:
	var elapsed = fmod(Time.get_unix_time_from_system() - cycle_start_time, CYCLE_TIMES.total_cycle)
	return "Modified Logic | Cycle: %.1fs/40s | Main(W+E): %s | Cross(N): %s | Cars: %d" % [elapsed, main_road_state, cross_road_state, cars.size()]
