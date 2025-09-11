extends Node

# SISTEMA AVANÇADO DE ANÁLISE DE TRÁFEGO
# Coleta dados detalhados da simulação para análise estatística

signal analytics_updated(data: Dictionary)

var event_bus: Node
var simulation_clock: Node

# Dados coletados
var traffic_data = {
	"session_start_time": 0.0,
	"total_simulation_time": 0.0,
	"cars_data": {},  # ID -> {spawn_time, despawn_time, total_stops, average_speed, path_taken}
	"traffic_light_data": {
		"total_changes": 0,
		"red_time": 0.0,
		"yellow_time": 0.0,
		"green_time": 0.0,
		"last_change_time": 0.0,
		"current_state": 0
	},
	"flow_rates": {
		"west_east": {"cars_per_minute": 0.0, "last_count": 0, "last_time": 0.0},
		"east_west": {"cars_per_minute": 0.0, "last_count": 0, "last_time": 0.0},
		"south_north": {"cars_per_minute": 0.0, "last_count": 0, "last_time": 0.0}
	},
	"performance_metrics": {
		"average_travel_time": 0.0,
		"average_stops_per_car": 0.0,
		"average_speed": 0.0,
		"throughput": 0.0,  # carros/minuto total
		"efficiency_score": 0.0  # 0-100%
	},
	"congestion_analysis": {
		"peak_queue_length": 0,
		"average_queue_length": 0.0,
		"congestion_events": 0,
		"longest_stop_duration": 0.0
	}
}

# Buffers para cálculos em tempo real
var recent_cars = []  # Últimos carros despawnados para cálculos de média
var max_recent_cars = 50

var queue_length_samples = []
var max_queue_samples = 100

func _ready():
	print("📊 TrafficAnalytics inicializado")
	
	# System references
	event_bus = get_node("/root/EventBus")
	simulation_clock = get_node("/root/SimulationClock")
	
	# Initialize session
	traffic_data.session_start_time = simulation_clock.get_simulation_time() if simulation_clock else 0.0
	
	# Subscribe to events
	setup_event_subscriptions()
	
	# Update timer
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 1.0  # Análise a cada segundo
	timer.timeout.connect(_update_analytics)
	timer.start()

func setup_event_subscriptions():
	event_bus.subscribe("car_spawned", _on_car_spawned)
	event_bus.subscribe("car_despawned", _on_car_despawned)
	event_bus.subscribe("car_stopped", _on_car_stopped)
	event_bus.subscribe("car_started", _on_car_started)
	event_bus.subscribe("traffic_light_changed", _on_traffic_light_changed)

func _on_car_spawned(car_data):
	var car_id = car_data.id
	traffic_data.cars_data[car_id] = {
		"spawn_time": simulation_clock.get_simulation_time(),
		"despawn_time": -1,
		"total_stops": 0,
		"speeds": [],
		"direction": car_data.direction_enum,
		"last_stop_start": -1,
		"total_stop_duration": 0.0
	}
	
	# Atualizar flow rate
	update_flow_rate(car_data.direction_enum)

func _on_car_despawned(car_data):
	var car_id = car_data.id
	if traffic_data.cars_data.has(car_id):
		var car_info = traffic_data.cars_data[car_id]
		car_info.despawn_time = simulation_clock.get_simulation_time()
		
		# Adicionar aos carros recentes para análise
		recent_cars.append(car_info)
		if recent_cars.size() > max_recent_cars:
			recent_cars.pop_front()

func _on_car_stopped(car_data):
	var car_id = car_data.id
	if traffic_data.cars_data.has(car_id):
		var car_info = traffic_data.cars_data[car_id]
		car_info.total_stops += 1
		car_info.last_stop_start = simulation_clock.get_simulation_time()

func _on_car_started(car_data):
	var car_id = car_data.id
	if traffic_data.cars_data.has(car_id):
		var car_info = traffic_data.cars_data[car_id]
		if car_info.last_stop_start > 0:
			var stop_duration = simulation_clock.get_simulation_time() - car_info.last_stop_start
			car_info.total_stop_duration += stop_duration
			
			# Atualizar longest stop
			if stop_duration > traffic_data.congestion_analysis.longest_stop_duration:
				traffic_data.congestion_analysis.longest_stop_duration = stop_duration
			
			car_info.last_stop_start = -1

func _on_traffic_light_changed(data):
	var current_time = simulation_clock.get_simulation_time()
	var old_state = traffic_data.traffic_light_data.current_state
	var time_in_state = current_time - traffic_data.traffic_light_data.last_change_time
	
	# Contabilizar tempo no estado anterior
	match old_state:
		0: traffic_data.traffic_light_data.red_time += time_in_state
		1: traffic_data.traffic_light_data.yellow_time += time_in_state
		2: traffic_data.traffic_light_data.green_time += time_in_state
	
	traffic_data.traffic_light_data.total_changes += 1
	traffic_data.traffic_light_data.current_state = data.state
	traffic_data.traffic_light_data.last_change_time = current_time

func update_flow_rate(direction: int):
	var direction_name = ""
	match direction:
		0: direction_name = "west_east"
		1: direction_name = "east_west"
		3: direction_name = "south_north"
		_: return
	
	var flow_data = traffic_data.flow_rates[direction_name]
	var current_time = simulation_clock.get_simulation_time()
	
	flow_data.last_count += 1
	
	# Calcular taxa por minuto
	var time_diff = current_time - flow_data.last_time
	if time_diff >= 60.0:  # A cada minuto
		flow_data.cars_per_minute = flow_data.last_count / (time_diff / 60.0)
		flow_data.last_count = 0
		flow_data.last_time = current_time

func _update_analytics():
	update_performance_metrics()
	update_congestion_analysis()
	
	traffic_data.total_simulation_time = simulation_clock.get_simulation_time() - traffic_data.session_start_time
	
	analytics_updated.emit(traffic_data)

func update_performance_metrics():
	if recent_cars.size() == 0:
		return
	
	var total_travel_time = 0.0
	var total_stops = 0
	var total_speed = 0.0
	var completed_cars = 0
	
	for car in recent_cars:
		if car.despawn_time > 0:  # Carro completou a jornada
			var travel_time = car.despawn_time - car.spawn_time
			total_travel_time += travel_time
			total_stops += car.total_stops
			completed_cars += 1
			
			# Velocidade média (simplificada)
			if car.speeds.size() > 0:
				var avg_speed = 0.0
				for speed in car.speeds:
					avg_speed += speed
				avg_speed /= car.speeds.size()
				total_speed += avg_speed
	
	if completed_cars > 0:
		traffic_data.performance_metrics.average_travel_time = total_travel_time / completed_cars
		traffic_data.performance_metrics.average_stops_per_car = float(total_stops) / completed_cars
		traffic_data.performance_metrics.average_speed = total_speed / completed_cars
		
		# Calcular throughput (carros por minuto)
		var time_window = 300.0  # 5 minutos
		var current_time = simulation_clock.get_simulation_time()
		var cars_in_window = 0
		
		for car in recent_cars:
			if car.despawn_time > 0 and current_time - car.despawn_time <= time_window:
				cars_in_window += 1
		
		traffic_data.performance_metrics.throughput = cars_in_window / (time_window / 60.0)
		
		# Efficiency score (0-100%) baseado em paradas e tempo de viagem
		var ideal_travel_time = 30.0  # Tempo ideal em segundos
		var ideal_stops = 0.5  # Paradas ideais por carro
		
		var time_efficiency = clamp(ideal_travel_time / traffic_data.performance_metrics.average_travel_time, 0.0, 1.0)
		var stop_efficiency = clamp(ideal_stops / max(traffic_data.performance_metrics.average_stops_per_car, 0.1), 0.0, 1.0)
		
		traffic_data.performance_metrics.efficiency_score = (time_efficiency + stop_efficiency) * 50.0

func update_congestion_analysis():
	# Obter dados de filas da simulação discreta
	var discrete_sim = get_node("/root/DiscreteSimulation")
	if discrete_sim and discrete_sim.has_method("get_active_cars"):
		var active_cars = discrete_sim.get("active_cars")
		if active_cars:
			var current_queue_length = count_queued_cars(active_cars)
			
			# Atualizar queue samples
			queue_length_samples.append(current_queue_length)
			if queue_length_samples.size() > max_queue_samples:
				queue_length_samples.pop_front()
			
			# Atualizar pico
			if current_queue_length > traffic_data.congestion_analysis.peak_queue_length:
				traffic_data.congestion_analysis.peak_queue_length = current_queue_length
			
			# Calcular média de fila
			if queue_length_samples.size() > 0:
				var total = 0
				for sample in queue_length_samples:
					total += sample
				traffic_data.congestion_analysis.average_queue_length = float(total) / queue_length_samples.size()

func count_queued_cars(active_cars: Dictionary) -> int:
	var queued_count = 0
	
	for car_id in active_cars.keys():
		var car = active_cars[car_id]
		if car.has("is_stopped") and car.is_stopped:
			queued_count += 1
	
	return queued_count

func get_analytics_summary() -> Dictionary:
	return {
		"session_duration": format_time(traffic_data.total_simulation_time),
		"total_cars_processed": recent_cars.size(),
		"average_travel_time": "%.1fs" % traffic_data.performance_metrics.average_travel_time,
		"average_stops": "%.1f" % traffic_data.performance_metrics.average_stops_per_car,
		"throughput": "%.1f cars/min" % traffic_data.performance_metrics.throughput,
		"efficiency": "%.1f%%" % traffic_data.performance_metrics.efficiency_score,
		"peak_queue": traffic_data.congestion_analysis.peak_queue_length,
		"avg_queue": "%.1f" % traffic_data.congestion_analysis.average_queue_length
	}

func format_time(seconds: float) -> String:
	var minutes = int(seconds / 60)
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

func reset_analytics():
	traffic_data.cars_data.clear()
	recent_cars.clear()
	queue_length_samples.clear()
	traffic_data.session_start_time = simulation_clock.get_simulation_time()
	traffic_data.congestion_analysis.peak_queue_length = 0
	print("📊 Analytics resetados")