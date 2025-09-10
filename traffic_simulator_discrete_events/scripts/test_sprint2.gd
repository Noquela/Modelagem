extends Node

# Teste simples para validar Sprint 2
func _ready():
	print("Testing Sprint 2 components...")
	
	# Teste 1: Criar componentes
	var clock = SimulationClock.new()
	var scheduler = DiscreteEventScheduler.new(clock)
	var vehicle_manager = VehicleEventManager.new(scheduler, clock)
	
	# Teste 2: Criar veículo
	var car = DiscreteCar.new(1, 0.0, DiscreteCar.Direction.LEFT_TO_RIGHT, DiscreteCar.DriverPersonality.NORMAL)
	var journey = VehicleJourney.new(1, car)
	
	print("✅ DiscreteCar created: %s" % car.get_debug_info())
	print("✅ VehicleJourney created: %s" % journey.get_debug_info())
	
	# Teste 3: Calcular tempo de viagem
	var travel_time = journey.calculate_total_journey_time()
	print("✅ Total journey time: %.2f seconds" % travel_time)
	
	# Teste 4: Verificar personalidades
	for personality in DiscreteCar.DriverPersonality.values():
		var test_car = DiscreteCar.new(personality, 0.0)
		print("✅ Personality %s: speed=%.1f, reaction=%.1f-%.1f" % [
			test_car.get_personality_string(),
			test_car.personality_config.base_speed,
			test_car.personality_config.reaction_time_min,
			test_car.personality_config.reaction_time_max
		])
	
	print("🎉 Sprint 2 syntax validation complete!")