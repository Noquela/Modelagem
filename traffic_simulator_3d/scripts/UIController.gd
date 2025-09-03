extends Control
class_name UIController

# UI Elements
@onready var simulation_time_label = $TopPanel/SimulationTime
@onready var cars_label = $StatsPanel/CarsLabel
@onready var throughput_label = $StatsPanel/ThroughputLabel
@onready var fps_label = $StatsPanel/FPSLabel
@onready var main_road_label = $StatsPanel/TrafficLightStatus/MainRoadLabel
@onready var cross_road_label = $StatsPanel/TrafficLightStatus/CrossRoadLabel
@onready var play_button = $ControlPanel/PlayButton
@onready var speed_label = $ControlPanel/SpeedLabel
@onready var speed_slider = $ControlPanel/SpeedSlider

# References
var traffic_manager: TrafficManager
var simulation_time: float = 0.0
var is_paused: bool = false

func _ready():
	# Connect signals
	play_button.pressed.connect(_on_play_button_pressed)
	speed_slider.value_changed.connect(_on_speed_changed)
	
	# Get traffic manager reference
	traffic_manager = get_node("../TrafficManager")
	
	# Update initial values
	update_speed_display()

func _process(delta):
	if not is_paused:
		simulation_time += delta
		update_simulation_time()
	
	# Update stats every frame
	update_stats()
	update_fps()

func update_simulation_time():
	var minutes = int(simulation_time / 60)
	var seconds = int(simulation_time) % 60
	simulation_time_label.text = "Time: %02d:%02d" % [minutes, seconds]

func update_stats():
	if not traffic_manager:
		return
		
	var stats = traffic_manager.get_current_stats()
	
	# Update car count
	cars_label.text = "🚗 Active Cars: %d" % stats.active_cars
	
	# Update throughput
	throughput_label.text = "📈 Throughput: %.1f/s" % stats.throughput
	
	# Update traffic light states with colored indicators
	var main_color = get_light_color(stats.main_road_state)
	var cross_color = get_light_color(stats.cross_road_state)
	
	main_road_label.text = "🚦 Main Road: %s" % stats.main_road_state.to_upper()
	main_road_label.modulate = main_color
	
	cross_road_label.text = "🚦 Cross Road: %s" % stats.cross_road_state.to_upper()
	cross_road_label.modulate = cross_color

func get_light_color(state: String) -> Color:
	match state:
		"green":
			return Color.GREEN
		"yellow":
			return Color.YELLOW
		"red":
			return Color.RED
		_:
			return Color.WHITE

func update_fps():
	fps_label.text = "⚡ FPS: %d" % Engine.get_frames_per_second()

func _on_play_button_pressed():
	is_paused = !is_paused
	
	if is_paused:
		play_button.text = "▶️"
		Engine.time_scale = 0.0
	else:
		play_button.text = "⏸️"
		Engine.time_scale = speed_slider.value
	
	# Also pause the traffic manager
	if traffic_manager:
		traffic_manager.pause_simulation()

func _on_speed_changed(value: float):
	if not is_paused:
		Engine.time_scale = value
	update_speed_display()

func update_speed_display():
	speed_label.text = "Speed: %.1fx" % speed_slider.value

# Public method to update from external systems
func update_display(stats: Dictionary):
	# This can be called by other systems to update the UI
	if stats.has("simulation_time"):
		simulation_time = stats.simulation_time