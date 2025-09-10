extends Node

## TrafficManager básico para compatibilidade com sistema híbrido
## Usado quando não há TrafficManager específico disponível

var main_road_state: String = "green"
var cross_road_state: String = "red"

func _ready():
	print("🚦 BasicTrafficManager initialized")

func force_set_light_states(main_state: String, cross_state: String):
	"""Força estados dos semáforos (compatibilidade híbrida)"""
	main_road_state = main_state
	cross_road_state = cross_state
	print("🚦 BasicTrafficManager: Lights set to Main=%s, Cross=%s" % [main_state, cross_state])

func register_car(car_3d: Node3D):
	"""Registra carro (placeholder)"""
	if car_3d:
		print("📝 BasicTrafficManager: Car registered")

func unregister_car(car_3d: Node3D):
	"""Desregistra carro (placeholder)"""
	if car_3d:
		print("📝 BasicTrafficManager: Car unregistered")