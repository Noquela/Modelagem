extends CharacterBody3D
class_name Car

# ADAPTADO PARA EVENTOS DISCRETOS - SEM PERSONALIDADES
enum Direction { LEFT_TO_RIGHT, RIGHT_TO_LEFT, TOP_TO_BOTTOM, BOTTOM_TO_TOP }

# CORES PARA IDENTIFICAR DIREÇÃO (eventos discretos visuais)
const DIRECTION_COLORS = {
	Direction.LEFT_TO_RIGHT: Color.BLUE,      # West → East
	Direction.RIGHT_TO_LEFT: Color.RED,       # East → West  
	Direction.BOTTOM_TO_TOP: Color.GREEN,     # South → North
	Direction.TOP_TO_BOTTOM: Color.YELLOW     # North → South (não usado)
}

# Propriedades do carro EVENTOS DISCRETOS
var direction: Direction
var lane: int = 0
var car_id: int

# EVENTOS DISCRETOS - SEM MOVIMENTO CONTÍNUO
var estado_evento: String = "spawning"  # spawning, waiting, crossing, exiting
var tempo_spawn: float = 0.0
var posicao_target: Vector3 = Vector3.ZERO

# Visual
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D

func _ready():
	print("🚗 Carro %d criado para EVENTOS DISCRETOS" % car_id)
	
	# EVENTOS DISCRETOS: SEM personalidades, física complexa ou comportamento
	create_car_geometry_simple()
	definir_cor_por_direcao()
	add_to_group("cars")
	
	# Registrar no traffic manager se existir
	var traffic_manager = get_tree().get_first_node_in_group("traffic_manager")
	if traffic_manager and traffic_manager.has_method("register_car"):
		traffic_manager.register_car(self)

# ========== FUNÇÕES PARA EVENTOS DISCRETOS ==========

func create_car_geometry_simple():
	"""Cria geometria simples do carro para eventos discretos"""
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	# Carro como caixa simples
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(2.0, 1.0, 1.2)  # Tamanho realista de carro
	mesh_instance.mesh = box_mesh
	
	# Material básico
	material = StandardMaterial3D.new()
	mesh_instance.material_override = material
	
	print("🎨 Geometria do carro %d criada" % car_id)

func definir_cor_por_direcao():
	"""Define cor baseada na direção (eventos discretos visuais)"""
	if material and direction in DIRECTION_COLORS:
		material.albedo_color = DIRECTION_COLORS[direction]
		print("🎨 Carro %d - Cor: %s (Direção: %d)" % [car_id, DIRECTION_COLORS[direction], direction])

func mudar_estado_evento(novo_estado: String):
	"""Muda estado do carro (eventos discretos)"""
	estado_evento = novo_estado
	print("🔄 Carro %d mudou estado: %s" % [car_id, novo_estado])
	
	# Mudar cor baseado no estado
	if material:
		match novo_estado:
			"spawning":
				material.albedo_color = Color.CYAN
			"waiting":
				material.albedo_color = Color.RED
			"crossing":
				material.albedo_color = Color.GREEN
			"exiting":
				material.albedo_color = Color.YELLOW

func teleportar_para_posicao(nova_posicao: Vector3):
	"""Teleporta carro para nova posição (eventos discretos)"""
	global_position = nova_posicao
	print("⚡ Carro %d teleportou para: %s" % [car_id, nova_posicao])

func destruir_carro():
	"""Remove carro do sistema (eventos discretos)"""
	print("💥 Carro %d removido do sistema" % car_id)
	queue_free()

# EVENTOS DISCRETOS: SEM _process() - movimento por teleporte apenas
# Toda lógica de movimento é baseada em eventos, não em tempo contínuo