extends RefCounted
class_name DiscreteTrafficManager

var scheduler: DiscreteEventScheduler
var simulation_clock: SimulationClock
var traffic_queues: Dictionary = {}

# Estados dos semáforos - EXATOS do simulador original
var main_road_state: String = "green"  # West/East
var cross_road_state: String = "red"   # North/South

# Timing exato do simulador original (40s total)
const TRAFFIC_LIGHT_CYCLE = {
	"main_road_green": 20.0,   # West-East verde por 20s
	"cross_road_green": 10.0,  # North-South verde por 10s  
	"yellow_time": 3.0,
	"safety_time": 1.0,
	"total_cycle": 40.0
}

var cycle_start_time: float = 0.0
var next_light_change_id: int = 1

func _init(event_scheduler: DiscreteEventScheduler, clock: SimulationClock):
	scheduler = event_scheduler
	simulation_clock = clock
	cycle_start_time = clock.get_time()
	
	# Criar filas para cada direção
	traffic_queues[DiscreteCar.Direction.LEFT_TO_RIGHT] = TrafficQueue.new("West")
	traffic_queues[DiscreteCar.Direction.RIGHT_TO_LEFT] = TrafficQueue.new("East")
	traffic_queues[DiscreteCar.Direction.BOTTOM_TO_TOP] = TrafficQueue.new("South")
	
	# Agendar todos os eventos de mudança de semáforo do ciclo
	_schedule_complete_light_cycle()

func _schedule_complete_light_cycle():
	var current_time = simulation_clock.get_time()
	var cycle_base = current_time
	
	# Agendar ciclo completo de 40s baseado na lógica original
	var events = [
		{"time": cycle_base + 20.0, "main_state": "yellow", "cross_state": "red"},      # 20s
		{"time": cycle_base + 23.0, "main_state": "red", "cross_state": "red"},        # 23s - safety  
		{"time": cycle_base + 24.0, "main_state": "red", "cross_state": "green"},      # 24s
		{"time": cycle_base + 34.0, "main_state": "red", "cross_state": "yellow"},     # 34s
		{"time": cycle_base + 37.0, "main_state": "red", "cross_state": "red"},        # 37s - safety
		{"time": cycle_base + 40.0, "main_state": "green", "cross_state": "red"}       # 40s - reset
	]
	
	for event_data in events:
		var light_event = DiscreteEvent.new(
			event_data.time,
			DiscreteEvent.EventType.LIGHT_CHANGE,
			next_light_change_id,
			{
				"change_id": next_light_change_id,
				"main_road_state": event_data.main_state,
				"cross_road_state": event_data.cross_state,
				"cycle_time": event_data.time - cycle_base
			}
		)
		
		scheduler.schedule_event(light_event)
		next_light_change_id += 1
	
	print("🚦 Scheduled complete 40s light cycle starting at %.2fs" % current_time)

func handle_light_change_event(event_data: Dictionary):
	var change_id = event_data.change_id
	var new_main_state = event_data.main_road_state
	var new_cross_state = event_data.cross_road_state
	var cycle_time = event_data.cycle_time
	
	# Atualizar estados
	var old_main = main_road_state
	var old_cross = cross_road_state
	
	main_road_state = new_main_state
	cross_road_state = new_cross_state
	
	print("🚦 LIGHT_CHANGE #%d at %.2fs (cycle %.1fs): Main %s→%s | Cross %s→%s" % [
		change_id, 
		simulation_clock.get_time(),
		cycle_time,
		old_main, new_main_state,
		old_cross, new_cross_state
	])
	
	# Processar filas quando semáforo fica verde
	_process_queues_on_green_light(old_main, new_main_state, old_cross, new_cross_state)
	
	# Agendar próximo ciclo quando completar 40s
	if cycle_time >= 40.0:
		cycle_start_time = simulation_clock.get_time()
		_schedule_complete_light_cycle()

func _process_queues_on_green_light(old_main: String, new_main: String, old_cross: String, new_cross: String):
	# Main road ficou verde (West/East)
	if old_main != "green" and new_main == "green":
		_schedule_queue_processing(DiscreteCar.Direction.LEFT_TO_RIGHT)
		_schedule_queue_processing(DiscreteCar.Direction.RIGHT_TO_LEFT)
	
	# Cross road ficou verde (North/South)
	if old_cross != "green" and new_cross == "green":
		_schedule_queue_processing(DiscreteCar.Direction.BOTTOM_TO_TOP)

func _schedule_queue_processing(direction: DiscreteCar.Direction):
	var queue = traffic_queues.get(direction)
	if not queue or queue.is_empty():
		return
	
	# Agendar processamento da fila com pequeno delay
	var process_time = simulation_clock.get_time() + 0.1
	
	var queue_event = DiscreteEvent.new(
		process_time,
		DiscreteEvent.EventType.QUEUE_PROCESS,
		-1,
		{
			"direction": direction,
			"queue_size": queue.get_size()
		}
	)
	
	scheduler.schedule_event(queue_event)

func handle_queue_processing_event(event_data: Dictionary):
	var direction = event_data.direction as DiscreteCar.Direction
	var queue_size = event_data.queue_size
	
	var queue = traffic_queues.get(direction)
	if not queue:
		return
	
	var direction_name = _get_direction_name(direction)
	print("🚦 QUEUE_PROCESS: Processing %d cars in %s queue" % [queue_size, direction_name])
	
	# Processar todos os carros na fila
	var cars_processed = queue.process_all_cars()
	
	if cars_processed > 0:
		print("✅ Released %d cars from %s queue" % [cars_processed, direction_name])

func get_light_state_for_direction(direction: DiscreteCar.Direction) -> String:
	match direction:
		DiscreteCar.Direction.LEFT_TO_RIGHT, DiscreteCar.Direction.RIGHT_TO_LEFT:
			return main_road_state
		DiscreteCar.Direction.BOTTOM_TO_TOP:
			return cross_road_state
		_:
			return "red"

func is_safe_to_proceed(direction: DiscreteCar.Direction) -> bool:
	return get_light_state_for_direction(direction) == "green"

func can_proceed_on_yellow(direction: DiscreteCar.Direction, distance_to_intersection: float, current_speed: float) -> bool:
	var state = get_light_state_for_direction(direction)
	if state != "yellow":
		return false
	
	# Lógica do semáforo amarelo - baseada no simulador original
	var stopping_distance = (current_speed * current_speed) / (2.0 * 8.0)
	return distance_to_intersection < stopping_distance + 3.0

func add_car_to_queue(car: DiscreteCar):
	var queue = traffic_queues.get(car.direction)
	if queue:
		queue.add_car(car)
		var direction_name = _get_direction_name(car.direction)
		print("🚗 Car %d added to %s queue (size: %d)" % [car.car_id, direction_name, queue.get_size()])

func remove_car_from_queue(car: DiscreteCar):
	var queue = traffic_queues.get(car.direction)
	if queue:
		queue.remove_car(car)

func get_current_cycle_phase() -> float:
	var current_time = simulation_clock.get_time()
	var elapsed = current_time - cycle_start_time
	return fmod(elapsed, TRAFFIC_LIGHT_CYCLE.total_cycle)

func predict_light_state_at_time(direction: DiscreteCar.Direction, target_time: float) -> String:
	var time_in_cycle = fmod(target_time - cycle_start_time, TRAFFIC_LIGHT_CYCLE.total_cycle)
	
	match direction:
		DiscreteCar.Direction.LEFT_TO_RIGHT, DiscreteCar.Direction.RIGHT_TO_LEFT:
			if time_in_cycle < 20.0:
				return "green"
			elif time_in_cycle < 23.0:
				return "yellow"
			else:
				return "red"
		DiscreteCar.Direction.BOTTOM_TO_TOP:
			if time_in_cycle < 24.0:
				return "red"
			elif time_in_cycle < 34.0:
				return "green"
			elif time_in_cycle < 37.0:
				return "yellow"
			else:
				return "red"
		_:
			return "red"

func _get_direction_name(direction: DiscreteCar.Direction) -> String:
	match direction:
		DiscreteCar.Direction.LEFT_TO_RIGHT: return "West"
		DiscreteCar.Direction.RIGHT_TO_LEFT: return "East"  
		DiscreteCar.Direction.BOTTOM_TO_TOP: return "South"
		_: return "Unknown"

func get_queue_sizes() -> Dictionary:
	var sizes = {}
	for direction in traffic_queues.keys():
		var queue = traffic_queues[direction]
		sizes[_get_direction_name(direction)] = queue.get_size()
	return sizes

func get_total_queued_cars() -> int:
	var total = 0
	for queue in traffic_queues.values():
		total += queue.get_size()
	return total

func get_debug_info() -> String:
	var phase = get_current_cycle_phase()
	var queue_info = get_queue_sizes()
	
	return "TrafficManager: Cycle %.1fs/40s | Main:%s Cross:%s | Queues: W:%d E:%d S:%d" % [
		phase, main_road_state, cross_road_state,
		queue_info.get("West", 0),
		queue_info.get("East", 0), 
		queue_info.get("South", 0)
	]