extends RefCounted
class_name VehicleEventManager

var scheduler: DiscreteEventScheduler
var simulation_clock: SimulationClock
var active_cars: Dictionary = {}
var car_journeys: Dictionary = {}
var next_car_id: int = 1
var total_cars_spawned: int = 0

func _init(event_scheduler: DiscreteEventScheduler, clock: SimulationClock):
	scheduler = event_scheduler
	simulation_clock = clock

func schedule_vehicle_spawn(spawn_time: float, direction: DiscreteCar.Direction, personality: DiscreteCar.DriverPersonality):
	var spawn_event = DiscreteEvent.new(
		spawn_time,
		DiscreteEvent.EventType.CAR_SPAWN,
		next_car_id,
		{
			"car_id": next_car_id,
			"direction": direction,
			"personality": personality
		}
	)
	
	scheduler.schedule_event(spawn_event)
	next_car_id += 1

func handle_car_spawn_event(event_data: Dictionary):
	var car_id = event_data.car_id
	var direction = event_data.direction as DiscreteCar.Direction
	var personality = event_data.personality as DiscreteCar.DriverPersonality
	var spawn_time = simulation_clock.get_simulation_time()
	
	var car = DiscreteCar.new(car_id, spawn_time, direction, personality)
	var journey = VehicleJourney.new(car_id, car)
	
	active_cars[car_id] = car
	car_journeys[car_id] = journey
	total_cars_spawned += 1
	
	print("Car %d spawned: %s %s at %.2fs" % [car_id, car.get_personality_string(), car.get_direction_string(), spawn_time])
	
	_schedule_car_arrival_at_intersection(car, journey)

func _schedule_car_arrival_at_intersection(car: DiscreteCar, journey: VehicleJourney):
	var travel_time = journey.calculate_travel_time_for_segment(0)
	var arrival_time = simulation_clock.get_simulation_time() + travel_time
	
	var arrival_event = DiscreteEvent.new(
		arrival_time,
		DiscreteEvent.EventType.CAR_ARRIVAL,
		car.car_id,
		{
			"car_id": car.car_id,
			"arrival_position": "intersection"
		}
	)
	
	scheduler.schedule_event(arrival_event)

func handle_car_arrival_event(event_data: Dictionary):
	var car_id = event_data.car_id
	var car = active_cars.get(car_id)
	var journey = car_journeys.get(car_id)
	
	if not car or not journey:
		print("ERROR: Car %d not found for arrival event" % car_id)
		return
	
	var arrival_time = simulation_clock.get_simulation_time()
	var light_state = journey.get_light_state_at_time(arrival_time)
	
	print("Car %d arrived at intersection - Light: %s" % [car_id, light_state])
	
	if car.should_stop_at_yellow(light_state):
		_handle_car_waiting_at_intersection(car, journey, arrival_time)
	else:
		_handle_car_proceeding_through_intersection(car, journey, arrival_time)

func _handle_car_waiting_at_intersection(car: DiscreteCar, journey: VehicleJourney, current_time: float):
	car.start_waiting(current_time)
	
	var wait_time = journey.calculate_wait_time_if_needed(current_time)
	var proceed_time = current_time + wait_time
	
	var proceed_event = DiscreteEvent.new(
		proceed_time,
		DiscreteEvent.EventType.CAR_ARRIVAL,
		car.car_id,
		{
			"car_id": car.car_id,
			"arrival_position": "proceeding"
		}
	)
	
	scheduler.schedule_event(proceed_event)
	print("Car %d waiting - will proceed at %.2fs (wait: %.2fs)" % [car.car_id, proceed_time, wait_time])

func _handle_car_proceeding_through_intersection(car: DiscreteCar, journey: VehicleJourney, current_time: float):
	car.start_proceeding(current_time)
	journey.advance_to_next_segment()
	
	var crossing_time = journey.calculate_travel_time_for_segment(1)
	var exit_intersection_time = current_time + crossing_time
	
	var crossing_event = DiscreteEvent.new(
		exit_intersection_time,
		DiscreteEvent.EventType.CAR_ARRIVAL,
		car.car_id,
		{
			"car_id": car.car_id,
			"arrival_position": "exit_intersection"
		}
	)
	
	car.start_crossing(current_time)
	scheduler.schedule_event(crossing_event)
	print("Car %d crossing intersection - will exit at %.2fs" % [car.car_id, exit_intersection_time])

func handle_car_exit_intersection_event(event_data: Dictionary):
	var car_id = event_data.car_id
	var car = active_cars.get(car_id)
	var journey = car_journeys.get(car_id)
	
	if not car or not journey:
		return
	
	var current_time = simulation_clock.get_simulation_time()
	car.start_clearing(current_time)
	journey.advance_to_next_segment()
	
	var exit_time = journey.calculate_travel_time_for_segment(2)
	var departure_time = current_time + exit_time
	
	var departure_event = DiscreteEvent.new(
		departure_time,
		DiscreteEvent.EventType.CAR_DEPARTURE,
		car.car_id,
		{
			"car_id": car.car_id
		}
	)
	
	scheduler.schedule_event(departure_event)
	print("Car %d exiting intersection - will depart at %.2fs" % [car.car_id, departure_time])

func handle_car_departure_event(event_data: Dictionary):
	var car_id = event_data.car_id
	var car = active_cars.get(car_id)
	
	if car:
		var wait_time = car.get_wait_time(simulation_clock.get_simulation_time())
		print("Car %d departed - Total wait time: %.2fs" % [car_id, wait_time])
	
	active_cars.erase(car_id)
	car_journeys.erase(car_id)

func schedule_periodic_spawns(spawn_duration: float = 300.0):
	var current_time = simulation_clock.get_simulation_time()
	var end_time = current_time + spawn_duration
	
	var spawn_time = current_time + 1.0
	
	while spawn_time < end_time:
		var hour = int(fmod(spawn_time / 3600.0, 24.0))
		
		_schedule_spawn_for_direction(spawn_time, DiscreteCar.Direction.LEFT_TO_RIGHT, hour)
		spawn_time += _get_spawn_interval(DiscreteCar.Direction.LEFT_TO_RIGHT, hour)
		
		if spawn_time < end_time:
			_schedule_spawn_for_direction(spawn_time, DiscreteCar.Direction.RIGHT_TO_LEFT, hour)
			spawn_time += _get_spawn_interval(DiscreteCar.Direction.RIGHT_TO_LEFT, hour)
		
		if spawn_time < end_time:
			_schedule_spawn_for_direction(spawn_time, DiscreteCar.Direction.BOTTOM_TO_TOP, hour)
			spawn_time += _get_spawn_interval(DiscreteCar.Direction.BOTTOM_TO_TOP, hour)

func _schedule_spawn_for_direction(spawn_time: float, direction: DiscreteCar.Direction, hour: int):
	var journey = VehicleJourney.new(0, DiscreteCar.new(0, spawn_time, direction))
	var spawn_rate = journey.get_spawn_rate_for_direction(direction, hour)
	
	if randf() < spawn_rate:
		var personality = _get_random_personality()
		schedule_vehicle_spawn(spawn_time, direction, personality)

func _get_spawn_interval(direction: DiscreteCar.Direction, hour: int) -> float:
	var journey = VehicleJourney.new(0, DiscreteCar.new(0, 0.0, direction))
	var spawn_rate = journey.get_spawn_rate_for_direction(direction, hour)
	var base_interval = 1.0 / max(spawn_rate, 0.001)
	return base_interval + randf_range(-0.5, 0.5)

func _get_random_personality() -> DiscreteCar.DriverPersonality:
	var rand_val = randf()
	
	if rand_val < 0.25:
		return DiscreteCar.DriverPersonality.AGGRESSIVE
	elif rand_val < 0.50:
		return DiscreteCar.DriverPersonality.CONSERVATIVE
	elif rand_val < 0.75:
		return DiscreteCar.DriverPersonality.NORMAL
	else:
		return DiscreteCar.DriverPersonality.ELDERLY

func get_active_car_count() -> int:
	return active_cars.size()

func get_total_cars_spawned() -> int:
	return total_cars_spawned

func get_cars_waiting_count() -> int:
	var waiting_count = 0
	for car in active_cars.values():
		if car.intersection_state == DiscreteCar.IntersectionState.WAITING:
			waiting_count += 1
	return waiting_count

func get_average_wait_time() -> float:
	if active_cars.is_empty():
		return 0.0
	
	var total_wait_time = 0.0
	var cars_with_wait = 0
	var current_time = simulation_clock.get_simulation_time()
	
	for car in active_cars.values():
		var wait_time = car.get_wait_time(current_time)
		if wait_time > 0.0:
			total_wait_time += wait_time
			cars_with_wait += 1
	
	if cars_with_wait == 0:
		return 0.0
	
	return total_wait_time / float(cars_with_wait)

func predict_car_position_at_time(car_id: int, target_time: float) -> Vector3:
	var car = active_cars.get(car_id)
	var journey = car_journeys.get(car_id)
	
	if not car or not journey:
		return Vector3.ZERO
	
	return car.update_position_for_time(target_time)

func get_debug_info() -> String:
	return "VehicleManager: %d active cars, %d total spawned, %.1fs avg wait" % [
		get_active_car_count(),
		get_total_cars_spawned(),
		get_average_wait_time()
	]