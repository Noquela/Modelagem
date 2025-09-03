extends Node
class_name TextureGenerator

# Gerador de texturas procedurais para calçadas
static func create_concrete_texture(size: int = 512) -> ImageTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGB8)
	
	# Base concrete color
	var base_color = Color(0.55, 0.55, 0.6)
	var noise_strength = 0.15
	
	# Generate noise pattern for concrete
	for y in range(size):
		for x in range(size):
			# Simple noise using sine waves
			var noise_x = sin(x * 0.05) * sin(y * 0.03)
			var noise_y = cos(x * 0.07) * cos(y * 0.05)
			var noise = (noise_x + noise_y) * 0.5
			
			# Add some random speckles
			if randi() % 100 < 3:  # 3% chance
				noise += randf_range(-0.3, 0.3)
			
			# Apply noise to base color
			var final_color = base_color + Color(noise, noise, noise) * noise_strength
			final_color = final_color.clamp(Color.BLACK, Color.WHITE)
			
			image.set_pixel(x, y, final_color)
	
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	return texture

static func create_concrete_normal_map(size: int = 512) -> ImageTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGB8)
	
	# Generate normal map for concrete roughness
	for y in range(size):
		for x in range(size):
			# Create subtle bumps
			var height = sin(x * 0.1) * cos(y * 0.08) * 0.1
			height += sin(x * 0.3) * sin(y * 0.25) * 0.05
			
			# Convert height to normal (simplified)
			var normal = Vector3(0, 0, 1)  # Up direction
			if x > 0 and x < size - 1:
				var dx = sin((x+1) * 0.1) - sin((x-1) * 0.1)
				normal.x = -dx * 0.5
			if y > 0 and y < size - 1:
				var dy = cos((y+1) * 0.08) - cos((y-1) * 0.08)
				normal.z = -dy * 0.5
			
			normal = normal.normalized()
			
			# Convert to 0-1 range for RGB
			var color = Color(
				(normal.x + 1.0) * 0.5,
				(normal.y + 1.0) * 0.5,
				(normal.z + 1.0) * 0.5
			)
			
			image.set_pixel(x, y, color)
	
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	return texture

static func create_concrete_roughness_map(size: int = 512) -> ImageTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGB8)
	
	# Generate roughness variation
	for y in range(size):
		for x in range(size):
			# Base roughness
			var roughness = 0.8
			
			# Add variation
			var variation = sin(x * 0.02) * cos(y * 0.03) * 0.1
			roughness += variation
			
			# Random spots
			if randi() % 200 < 1:  # 0.5% chance
				roughness += randf_range(-0.2, 0.2)
			
			roughness = clamp(roughness, 0.0, 1.0)
			var color = Color(roughness, roughness, roughness)
			
			image.set_pixel(x, y, color)
	
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	return texture