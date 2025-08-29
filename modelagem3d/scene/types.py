"""
Tipos de dados básicos para a cena 3D
====================================

Estruturas de dados reutilizáveis para posição, rotação,
bounding boxes, cores, etc.
"""

from dataclasses import dataclass
from typing import Tuple, List, Optional
import math

@dataclass
class Pos3:
    """Posição 3D"""
    x: float = 0.0
    y: float = 0.0
    z: float = 0.0
    
    def __add__(self, other):
        return Pos3(self.x + other.x, self.y + other.y, self.z + other.z)
    
    def __sub__(self, other):
        return Pos3(self.x - other.x, self.y - other.y, self.z - other.z)
    
    def __mul__(self, scalar):
        return Pos3(self.x * scalar, self.y * scalar, self.z * scalar)
    
    def distance_to(self, other):
        """Calcula distância euclidiana até outro ponto"""
        dx = self.x - other.x
        dy = self.y - other.y
        dz = self.z - other.z
        return math.sqrt(dx*dx + dy*dy + dz*dz)
    
    def normalized(self):
        """Retorna vetor normalizado"""
        length = math.sqrt(self.x*self.x + self.y*self.y + self.z*self.z)
        if length > 0:
            return Pos3(self.x/length, self.y/length, self.z/length)
        return Pos3()
    
    def as_tuple(self):
        return (self.x, self.y, self.z)

@dataclass
class Rot3:
    """Rotação 3D em graus (Euler angles)"""
    x: float = 0.0  # pitch
    y: float = 0.0  # yaw
    z: float = 0.0  # roll
    
    def as_tuple(self):
        return (self.x, self.y, self.z)

@dataclass
class Scale3:
    """Escala 3D"""
    x: float = 1.0
    y: float = 1.0
    z: float = 1.0
    
    def uniform(scale: float):
        return Scale3(scale, scale, scale)
    
    def as_tuple(self):
        return (self.x, self.y, self.z)

@dataclass
class Transform3D:
    """Transformação 3D completa"""
    position: Pos3 = None
    rotation: Rot3 = None
    scale: Scale3 = None
    
    def __post_init__(self):
        if self.position is None:
            self.position = Pos3()
        if self.rotation is None:
            self.rotation = Rot3()
        if self.scale is None:
            self.scale = Scale3()

@dataclass
class AABB:
    """Axis-Aligned Bounding Box"""
    min_point: Pos3
    max_point: Pos3
    
    @classmethod
    def from_center_size(cls, center: Pos3, size: Pos3):
        """Cria AABB a partir do centro e tamanho"""
        half_size = size * 0.5
        return cls(center - half_size, center + half_size)
    
    def contains_point(self, point: Pos3) -> bool:
        """Verifica se contém um ponto"""
        return (self.min_point.x <= point.x <= self.max_point.x and
                self.min_point.y <= point.y <= self.max_point.y and
                self.min_point.z <= point.z <= self.max_point.z)
    
    def intersects(self, other: 'AABB') -> bool:
        """Verifica interseção com outro AABB"""
        return not (self.max_point.x < other.min_point.x or
                   self.min_point.x > other.max_point.x or
                   self.max_point.y < other.min_point.y or
                   self.min_point.y > other.max_point.y or
                   self.max_point.z < other.min_point.z or
                   self.min_point.z > other.max_point.z)
    
    def center(self) -> Pos3:
        """Retorna o centro do AABB"""
        return Pos3(
            (self.min_point.x + self.max_point.x) * 0.5,
            (self.min_point.y + self.max_point.y) * 0.5,
            (self.min_point.z + self.max_point.z) * 0.5
        )
    
    def size(self) -> Pos3:
        """Retorna o tamanho do AABB"""
        return self.max_point - self.min_point

@dataclass
class Color:
    """Cor RGBA"""
    r: float = 1.0
    g: float = 1.0
    b: float = 1.0
    a: float = 1.0
    
    @classmethod
    def from_rgb(cls, r: float, g: float, b: float):
        return cls(r, g, b, 1.0)
    
    @classmethod
    def from_hex(cls, hex_color: str):
        """Cria cor a partir de string hexadecimal (#RRGGBB ou #RRGGBBAA)"""
        hex_color = hex_color.lstrip('#')
        
        if len(hex_color) == 6:
            return cls(
                int(hex_color[0:2], 16) / 255.0,
                int(hex_color[2:4], 16) / 255.0,
                int(hex_color[4:6], 16) / 255.0,
                1.0
            )
        elif len(hex_color) == 8:
            return cls(
                int(hex_color[0:2], 16) / 255.0,
                int(hex_color[2:4], 16) / 255.0,
                int(hex_color[4:6], 16) / 255.0,
                int(hex_color[6:8], 16) / 255.0
            )
        else:
            raise ValueError(f"Formato de cor inválido: #{hex_color}")
    
    def as_tuple(self):
        return (self.r, self.g, self.b)
    
    def as_tuple_alpha(self):
        return (self.r, self.g, self.b, self.a)

# Cores predefinidas
class Colors:
    WHITE = Color.from_rgb(1.0, 1.0, 1.0)
    BLACK = Color.from_rgb(0.0, 0.0, 0.0)
    RED = Color.from_rgb(1.0, 0.0, 0.0)
    GREEN = Color.from_rgb(0.0, 1.0, 0.0)
    BLUE = Color.from_rgb(0.0, 0.0, 1.0)
    YELLOW = Color.from_rgb(1.0, 1.0, 0.0)
    CYAN = Color.from_rgb(0.0, 1.0, 1.0)
    MAGENTA = Color.from_rgb(1.0, 0.0, 1.0)
    
    # Cores de material
    ASPHALT = Color.from_rgb(0.3, 0.3, 0.3)
    CONCRETE = Color.from_rgb(0.7, 0.7, 0.7)
    GRASS = Color.from_rgb(0.2, 0.6, 0.2)
    METAL = Color.from_rgb(0.6, 0.6, 0.7)
    
    # Cores de veículos
    CAR_COLORS = [
        Color.from_rgb(0.8, 0.0, 0.0),  # Vermelho
        Color.from_rgb(0.0, 0.6, 0.8),  # Azul
        Color.from_rgb(0.0, 0.7, 0.0),  # Verde
        Color.from_rgb(1.0, 0.8, 0.0),  # Amarelo
        Color.from_rgb(0.6, 0.0, 0.8),  # Roxo
        Color.from_rgb(1.0, 0.4, 0.0),  # Laranja
        Color.from_rgb(0.4, 0.4, 0.4),  # Cinza
        Color.from_rgb(0.0, 0.0, 0.0),  # Preto
    ]

@dataclass 
class Material:
    """Material de renderização"""
    albedo: Color = None
    ambient: Color = None
    metallic: float = 0.0
    roughness: float = 0.5
    
    def __post_init__(self):
        if self.albedo is None:
            self.albedo = Colors.WHITE
        if self.ambient is None:
            self.ambient = Color.from_rgb(0.1, 0.1, 0.1)

# Direções cardinais
class Direction:
    NORTH = Pos3(0, 1, 0)
    SOUTH = Pos3(0, -1, 0)
    EAST = Pos3(1, 0, 0)
    WEST = Pos3(-1, 0, 0)
    UP = Pos3(0, 0, 1)
    DOWN = Pos3(0, 0, -1)

@dataclass
class RenderObject:
    """Objeto renderizável básico"""
    transform: Transform3D
    material: Material
    mesh_name: str
    visible: bool = True
    cast_shadow: bool = True
    receive_shadow: bool = True
    
    def __post_init__(self):
        if self.transform is None:
            self.transform = Transform3D()
        if self.material is None:
            self.material = Material()
    
    def get_aabb(self) -> AABB:
        """Retorna bounding box do objeto (implementar em subclasses)"""
        # AABB padrão unitário centrado na posição
        pos = self.transform.position
        size = Pos3(1.0, 1.0, 1.0)
        return AABB.from_center_size(pos, size)