"""
Utilitários matemáticos para o simulador de tráfego 3D
"""
import numpy as np
import math
from typing import Tuple, Optional


def create_rotation_matrix(angle_x: float = 0, angle_y: float = 0, angle_z: float = 0) -> np.ndarray:
    """Cria matriz de rotação 4x4 para os ângulos dados."""
    cos_x, sin_x = math.cos(angle_x), math.sin(angle_x)
    cos_y, sin_y = math.cos(angle_y), math.sin(angle_y) 
    cos_z, sin_z = math.cos(angle_z), math.sin(angle_z)
    
    # Rotação em X
    rx = np.array([
        [1, 0, 0, 0],
        [0, cos_x, -sin_x, 0],
        [0, sin_x, cos_x, 0],
        [0, 0, 0, 1]
    ], dtype=np.float32)
    
    # Rotação em Y
    ry = np.array([
        [cos_y, 0, sin_y, 0],
        [0, 1, 0, 0],
        [-sin_y, 0, cos_y, 0],
        [0, 0, 0, 1]
    ], dtype=np.float32)
    
    # Rotação em Z
    rz = np.array([
        [cos_z, -sin_z, 0, 0],
        [sin_z, cos_z, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1]
    ], dtype=np.float32)
    
    return rz @ ry @ rx


def create_translation_matrix(x: float, y: float, z: float) -> np.ndarray:
    """Cria matriz de translação 4x4."""
    return np.array([
        [1, 0, 0, x],
        [0, 1, 0, y],
        [0, 0, 1, z],
        [0, 0, 0, 1]
    ], dtype=np.float32)


def create_scale_matrix(sx: float, sy: float, sz: float) -> np.ndarray:
    """Cria matriz de escala 4x4."""
    return np.array([
        [sx, 0, 0, 0],
        [0, sy, 0, 0],
        [0, 0, sz, 0],
        [0, 0, 0, 1]
    ], dtype=np.float32)


def create_perspective_matrix(fov: float, aspect: float, near: float, far: float) -> np.ndarray:
    """Cria matriz de projeção perspectiva."""
    f = 1.0 / math.tan(math.radians(fov) / 2.0)
    return np.array([
        [f/aspect, 0, 0, 0],
        [0, f, 0, 0],
        [0, 0, (far+near)/(near-far), (2*far*near)/(near-far)],
        [0, 0, -1, 0]
    ], dtype=np.float32)


def create_look_at_matrix(eye: np.ndarray, target: np.ndarray, up: np.ndarray) -> np.ndarray:
    """Cria matriz look-at para posicionamento de câmera."""
    f = normalize(target - eye)  # forward
    s = normalize(np.cross(f, up))  # side
    u = np.cross(s, f)  # up
    
    return np.array([
        [s[0], s[1], s[2], -np.dot(s, eye)],
        [u[0], u[1], u[2], -np.dot(u, eye)],
        [-f[0], -f[1], -f[2], np.dot(f, eye)],
        [0, 0, 0, 1]
    ], dtype=np.float32)


def normalize(v: np.ndarray) -> np.ndarray:
    """Normaliza um vetor."""
    norm = np.linalg.norm(v)
    return v / norm if norm > 0 else v


def distance_2d(p1: Tuple[float, float], p2: Tuple[float, float]) -> float:
    """Calcula distância 2D entre dois pontos."""
    return math.sqrt((p2[0] - p1[0])**2 + (p2[1] - p1[1])**2)


def distance_3d(p1: Tuple[float, float, float], p2: Tuple[float, float, float]) -> float:
    """Calcula distância 3D entre dois pontos."""
    return math.sqrt((p2[0] - p1[0])**2 + (p2[1] - p1[1])**2 + (p2[2] - p1[2])**2)


def interpolate(a: float, b: float, t: float) -> float:
    """Interpolação linear entre dois valores."""
    return a + (b - a) * t


def clamp(value: float, min_val: float, max_val: float) -> float:
    """Limita um valor entre min e max."""
    return max(min_val, min(max_val, value))


def smooth_step(edge0: float, edge1: float, x: float) -> float:
    """Interpolação suave usando função cúbica."""
    t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def calculate_directional_distance(pos1: np.ndarray, pos2: np.ndarray, direction: int) -> float:
    """
    Calcula distância na direção do movimento.
    Usado para determinar se um carro está à frente de outro.
    """
    from .config import CAR_DIRECTIONS
    
    if direction == CAR_DIRECTIONS['LEFT_TO_RIGHT']:
        return pos2[0] - pos1[0]  # positivo se pos2 está à frente
    elif direction == CAR_DIRECTIONS['RIGHT_TO_LEFT']:
        return pos1[0] - pos2[0]  # positivo se pos2 está à frente
    elif direction == CAR_DIRECTIONS['TOP_TO_BOTTOM']:
        return pos1[2] - pos2[2]  # positivo se pos2 está à frente
    
    return 0.0


def get_spawn_position(direction: int, lane: int) -> np.ndarray:
    """Retorna posição de spawn para direção e faixa especificadas."""
    from .config import CAR_DIRECTIONS, SCENE_CONFIG
    
    lane_width = SCENE_CONFIG['lane_width']
    world_edge = SCENE_CONFIG['world_size'] / 2
    
    if direction == CAR_DIRECTIONS['LEFT_TO_RIGHT']:
        x = -world_edge
        z = -3 + (lane * lane_width)
        return np.array([x, 0, z], dtype=np.float32)
    
    elif direction == CAR_DIRECTIONS['RIGHT_TO_LEFT']:
        x = world_edge
        z = 3 - (lane * lane_width)
        return np.array([x, 0, z], dtype=np.float32)
    
    elif direction == CAR_DIRECTIONS['TOP_TO_BOTTOM']:
        x = 0  # centralizado na rua de mão única
        z = world_edge
        return np.array([x, 0, z], dtype=np.float32)
    
    return np.array([0, 0, 0], dtype=np.float32)


def get_target_position(direction: int, lane: int) -> np.ndarray:
    """Retorna posição alvo para direção e faixa especificadas."""
    from .config import CAR_DIRECTIONS, SCENE_CONFIG
    
    lane_width = SCENE_CONFIG['lane_width']
    world_edge = SCENE_CONFIG['world_size'] / 2
    
    if direction == CAR_DIRECTIONS['LEFT_TO_RIGHT']:
        x = world_edge
        z = -3 + (lane * lane_width)
        return np.array([x, 0, z], dtype=np.float32)
    
    elif direction == CAR_DIRECTIONS['RIGHT_TO_LEFT']:
        x = -world_edge
        z = 3 - (lane * lane_width)
        return np.array([x, 0, z], dtype=np.float32)
    
    elif direction == CAR_DIRECTIONS['TOP_TO_BOTTOM']:
        x = 0
        z = -world_edge
        return np.array([x, 0, z], dtype=np.float32)
    
    return np.array([0, 0, 0], dtype=np.float32)


def point_in_rectangle(point: Tuple[float, float], rect_center: Tuple[float, float], 
                      width: float, height: float, rotation: float = 0) -> bool:
    """Verifica se um ponto está dentro de um retângulo rotacionado."""
    # Translada o ponto para origem
    px = point[0] - rect_center[0]
    py = point[1] - rect_center[1]
    
    # Rotaciona o ponto pelo ângulo inverso
    cos_r = math.cos(-rotation)
    sin_r = math.sin(-rotation)
    
    rx = px * cos_r - py * sin_r
    ry = px * sin_r + py * cos_r
    
    # Verifica se está dentro do retângulo
    return abs(rx) <= width/2 and abs(ry) <= height/2


def ray_box_intersection(ray_origin: np.ndarray, ray_dir: np.ndarray,
                        box_min: np.ndarray, box_max: np.ndarray) -> Optional[float]:
    """
    Testa interseção entre raio e caixa (AABB).
    Retorna distância até interseção ou None se não houver.
    """
    inv_dir = np.divide(1.0, ray_dir, out=np.zeros_like(ray_dir), where=ray_dir!=0)
    
    t1 = (box_min - ray_origin) * inv_dir
    t2 = (box_max - ray_origin) * inv_dir
    
    t_min = np.maximum(np.minimum(t1, t2), 0)
    t_max = np.minimum(np.maximum(t1, t2), np.inf)
    
    t_min_max = np.max(t_min)
    t_max_min = np.min(t_max)
    
    if t_min_max <= t_max_min:
        return t_min_max
    return None


def create_box_vertices(center: np.ndarray, size: np.ndarray) -> np.ndarray:
    """Cria vértices de uma caixa centrada em 'center' com dimensões 'size'."""
    half_size = size / 2
    vertices = np.array([
        # Face frontal
        [-half_size[0], -half_size[1],  half_size[2]],
        [ half_size[0], -half_size[1],  half_size[2]],
        [ half_size[0],  half_size[1],  half_size[2]],
        [-half_size[0],  half_size[1],  half_size[2]],
        
        # Face traseira
        [-half_size[0], -half_size[1], -half_size[2]],
        [ half_size[0], -half_size[1], -half_size[2]],
        [ half_size[0],  half_size[1], -half_size[2]],
        [-half_size[0],  half_size[1], -half_size[2]]
    ], dtype=np.float32)
    
    return vertices + center


def create_car_vertices() -> Tuple[np.ndarray, np.ndarray]:
    """Cria geometria de um carro simples."""
    # Vértices do corpo do carro
    vertices = np.array([
        # Corpo principal (caixa)
        [-0.9, 0.0, -0.45], [0.9, 0.0, -0.45], [0.9, 0.6, -0.45], [-0.9, 0.6, -0.45],  # face frontal
        [-0.9, 0.0,  0.45], [0.9, 0.0,  0.45], [0.9, 0.6,  0.45], [-0.9, 0.6,  0.45],  # face traseira
        
        # Janelas (caixa menor no topo)
        [-0.7, 0.6, -0.35], [0.7, 0.6, -0.35], [0.7, 1.0, -0.35], [-0.7, 1.0, -0.35],  # face frontal
        [-0.7, 0.6,  0.35], [0.7, 0.6,  0.35], [0.7, 1.0,  0.35], [-0.7, 1.0,  0.35],  # face traseira
    ], dtype=np.float32)
    
    # Índices para formar triângulos
    indices = np.array([
        # Corpo - faces externas
        0, 1, 2, 0, 2, 3,  # frente
        5, 4, 7, 5, 7, 6,  # trás
        4, 0, 3, 4, 3, 7,  # esquerda
        1, 5, 6, 1, 6, 2,  # direita
        3, 2, 6, 3, 6, 7,  # topo
        4, 5, 1, 4, 1, 0,  # base
        
        # Janelas - faces externas
        8, 9, 10, 8, 10, 11,    # frente
        13, 12, 15, 13, 15, 14,  # trás
        12, 8, 11, 12, 11, 15,   # esquerda
        9, 13, 14, 9, 14, 10,    # direita
        11, 10, 14, 11, 14, 15,  # topo
    ], dtype=np.uint32)
    
    return vertices, indices


def create_road_lines(road_length: float, road_width: float, line_width: float = 0.2, 
                     line_spacing: float = 4.0) -> Tuple[np.ndarray, np.ndarray]:
    """Cria geometria para linhas da estrada."""
    vertices = []
    indices = []
    
    half_width = line_width / 2
    half_length = road_length / 2
    
    # Criar linhas centrais pontilhadas
    line_count = int(road_length / line_spacing)
    vertex_offset = 0
    
    for i in range(line_count):
        x_start = -half_length + i * line_spacing
        x_end = x_start + line_spacing * 0.6  # 60% do espaço é linha, 40% é gap
        
        # Vértices de uma linha
        line_vertices = np.array([
            [x_start, 0.01, -half_width],
            [x_end,   0.01, -half_width],
            [x_end,   0.01,  half_width],
            [x_start, 0.01,  half_width],
        ], dtype=np.float32)
        
        vertices.append(line_vertices)
        
        # Índices para formar retângulo
        line_indices = np.array([
            0, 1, 2, 0, 2, 3
        ], dtype=np.uint32) + vertex_offset
        
        indices.append(line_indices)
        vertex_offset += 4
    
    return np.vstack(vertices), np.concatenate(indices)