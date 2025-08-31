extends Control

@onready var fps_label = $VBoxContainer/StatsPanel/FPSLabel
@onready var cars_label = $VBoxContainer/StatsPanel/CarsLabel
@onready var throughput_label = $VBoxContainer/StatsPanel/ThroughputLabel
@onready var congestion_label = $VBoxContainer/StatsPanel/CongestionLabel
@onready var time_label = $VBoxContainer/StatsPanel/TimeLabel

# Chart data
var throughput_history: Array[float] = []
var congestion_history: Array[float] = []
var max_history_size: int = 300  # 5 minutes at 60 FPS

# UI Elements
var stats_panel: Panel
var throughput_chart: Control
var personality_breakdown: Control

func _ready():
	create_ui_elements()
	set_process(true)

func create_ui_elements():
	# Main container
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Traffic Simulator 3D - Analytics"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	# Stats panel
	stats_panel = Panel.new()
	stats_panel.name = "StatsPanel"
	stats_panel.custom_minimum_size = Vector2(300, 200)
	vbox.add_child(stats_panel)
	
	var stats_vbox = VBoxContainer.new()
	stats_panel.add_child(stats_vbox)
	
	# Create labels
	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.text = "FPS: 60.0"
	stats_vbox.add_child(fps_label)
	
	cars_label = Label.new()
	cars_label.name = "CarsLabel"
	cars_label.text = "Active Cars: 0"
	stats_vbox.add_child(cars_label)
	
	throughput_label = Label.new()
	throughput_label.name = "ThroughputLabel"
	throughput_label.text = "Throughput: 0.0 cars/sec"
	stats_vbox.add_child(throughput_label)
	
	congestion_label = Label.new()
	congestion_label.name = "CongestionLabel" 
	congestion_label.text = "Congestion: 0%"
	stats_vbox.add_child(congestion_label)
	
	time_label = Label.new()
	time_label.name = "TimeLabel"
	time_label.text = "Simulation Time: 00:00"
	stats_vbox.add_child(time_label)
	
	# Controls panel
	create_control_panel(vbox)
	
	# Chart area
	create_charts_panel(vbox)
	
	# Personality breakdown
	create_personality_panel(vbox)

func create_control_panel(parent: VBoxContainer):
	var control_panel = Panel.new()
	control_panel.name = "ControlPanel"
	control_panel.custom_minimum_size = Vector2(300, 80)
	parent.add_child(control_panel)
	
	var hbox = HBoxContainer.new()
	control_panel.add_child(hbox)
	
	# Pause button
	var pause_button = Button.new()
	pause_button.text = "Pause/Resume"
	pause_button.pressed.connect(_on_pause_pressed)
	hbox.add_child(pause_button)
	
	# Camera mode button
	var camera_button = Button.new()
	camera_button.text = "Camera Mode"
	camera_button.pressed.connect(_on_camera_mode_pressed)
	hbox.add_child(camera_button)
	
	# Spawn rate slider
	var spawn_label = Label.new()
	spawn_label.text = "Spawn Rate:"
	hbox.add_child(spawn_label)
	
	var spawn_slider = HSlider.new()
	spawn_slider.min_value = 0.1
	spawn_slider.max_value = 3.0
	spawn_slider.value = 1.0
	spawn_slider.step = 0.1
	spawn_slider.value_changed.connect(_on_spawn_rate_changed)
	hbox.add_child(spawn_slider)

func create_charts_panel(parent: VBoxContainer):
	var charts_panel = Panel.new()
	charts_panel.name = "ChartsPanel"
	charts_panel.custom_minimum_size = Vector2(400, 200)
	parent.add_child(charts_panel)
	
	throughput_chart = Control.new()
	throughput_chart.name = "ThroughputChart"
	throughput_chart.custom_minimum_size = Vector2(380, 180)
	charts_panel.add_child(throughput_chart)

func create_personality_panel(parent: VBoxContainer):
	personality_breakdown = Panel.new()
	personality_breakdown.name = "PersonalityPanel"
	personality_breakdown.custom_minimum_size = Vector2(300, 150)
	parent.add_child(personality_breakdown)
	
	var personality_label = Label.new()
	personality_label.text = "Driver Personalities Distribution"
	personality_label.position = Vector2(10, 10)
	personality_breakdown.add_child(personality_label)

func update_display(stats: Dictionary):
	# Update basic stats
	if fps_label:
		fps_label.text = "FPS: %.1f" % stats.get("fps", 60.0)
	
	if cars_label:
		cars_label.text = "Active Cars: %d" % stats.get("active_cars", 0)
	
	if throughput_label:
		throughput_label.text = "Throughput: %.2f cars/sec" % stats.get("throughput", 0.0)
	
	if congestion_label:
		var congestion_percent = stats.get("congestion", 0.0) * 100
		congestion_label.text = "Congestion: %.0f%%" % congestion_percent
	
	if time_label:
		var sim_time = stats.get("simulation_time", 0.0)
		var minutes = int(sim_time / 60)
		var seconds = int(sim_time) % 60
		time_label.text = "Simulation Time: %02d:%02d" % [minutes, seconds]
	
	# Update chart data
	update_chart_data(stats)

func update_chart_data(stats: Dictionary):
	# Add to history arrays
	throughput_history.append(stats.get("throughput", 0.0))
	congestion_history.append(stats.get("congestion", 0.0))
	
	# Limit history size
	if throughput_history.size() > max_history_size:
		throughput_history.pop_front()
		congestion_history.pop_front()
	
	# Redraw charts
	if throughput_chart:
		throughput_chart.queue_redraw()

func _draw():
	if not throughput_chart or throughput_history.is_empty():
		return
	
	draw_throughput_chart()

func draw_throughput_chart():
	var chart_rect = throughput_chart.get_rect()
	var canvas_item = throughput_chart.get_canvas_item()
	
	# Clear background
	RenderingServer.canvas_item_add_rect(canvas_item, chart_rect, Color(0.1, 0.1, 0.1, 0.8))
	
	# Draw grid
	var grid_color = Color(0.3, 0.3, 0.3, 0.5)
	for i in range(5):
		var y = chart_rect.position.y + (chart_rect.size.y / 4) * i
		RenderingServer.canvas_item_add_line(canvas_item, 
			Vector2(chart_rect.position.x, y),
			Vector2(chart_rect.position.x + chart_rect.size.x, y),
			grid_color, 1.0)
	
	# Draw throughput line
	if throughput_history.size() > 1:
		var max_throughput = throughput_history.max()
		if max_throughput > 0:
			var points = PackedVector2Array()
			for i in range(throughput_history.size()):
				var x = chart_rect.position.x + (chart_rect.size.x / throughput_history.size()) * i
				var normalized_value = throughput_history[i] / max_throughput
				var y = chart_rect.position.y + chart_rect.size.y - (normalized_value * chart_rect.size.y)
				points.append(Vector2(x, y))
			
			# Draw line segments
			for i in range(points.size() - 1):
				RenderingServer.canvas_item_add_line(canvas_item, points[i], points[i + 1], Color.GREEN, 2.0)

func _on_pause_pressed():
	var traffic_manager = get_tree().get_first_node_in_group("traffic_manager")
	if traffic_manager and traffic_manager.has_method("pause_simulation"):
		traffic_manager.pause_simulation()

func _on_camera_mode_pressed():
	var camera_controller = get_tree().get_first_node_in_group("camera_controller")
	if camera_controller and camera_controller.has_method("cycle_camera_mode"):
		camera_controller.cycle_camera_mode()

func _on_spawn_rate_changed(value: float):
	var spawn_system = get_tree().get_first_node_in_group("spawn_system")
	if spawn_system and spawn_system.has_method("adjust_spawn_rate"):
		spawn_system.adjust_spawn_rate(value)

func get_personality_stats() -> Dictionary:
	var cars = get_tree().get_nodes_in_group("cars")
	var personality_counts = {
		"Aggressive": 0,
		"Conservative": 0,
		"Normal": 0,
		"Elderly": 0
	}
	
	for car in cars:
		if car.has_method("get_personality_string"):
			var personality = car.get_personality_string()
			if personality in personality_counts:
				personality_counts[personality] += 1
	
	return personality_counts

func update_personality_display():
	var stats = get_personality_stats()
	var total_cars = 0
	for count in stats.values():
		total_cars += count
	
	# Update personality breakdown display
	if personality_breakdown:
		# Clear existing children (except label)
		var children = personality_breakdown.get_children()
		for i in range(1, children.size()):
			children[i].queue_free()
		
		# Add new personality stats
		var y_offset = 40
		for personality in stats.keys():
			var count = stats[personality]
			var percentage = 0.0
			if total_cars > 0:
				percentage = (count / float(total_cars)) * 100
			
			var stat_label = Label.new()
			stat_label.text = "%s: %d (%.1f%%)" % [personality, count, percentage]
			stat_label.position = Vector2(10, y_offset)
			personality_breakdown.add_child(stat_label)
			y_offset += 25

func _process(delta):
	# Update personality display periodically
	if Engine.get_process_frames() % 60 == 0:  # Every second
		update_personality_display()