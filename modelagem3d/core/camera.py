"""
Sistema de câmera 3D com controles orbitantes
============================================

Câmera otimizada para visualização de cruzamento com:
- Orbit controls (mouse drag)
- Zoom suave (W/S)
- Rotação livre (A/D, Q/E)
- Limites seguros para evitar clipping
"""

import math
from OpenGL.GL import *
from OpenGL.GLU import *

class Camera3D:
    """Câmera 3D com sistema de coordenadas esféricas"""
    
    def __init__(self):
        # Posição esférica (distância, azimute, elevação)
        self.distance = 45.0
        self.azimuth = 45.0    # Rotação horizontal (graus)
        self.elevation = -25.0  # Rotação vertical (graus)
        
        # Ponto de foco (centro do cruzamento)
        self.target_x = 0.0
        self.target_y = 0.0
        self.target_z = 0.0
        
        # Limites seguros
        self.min_distance = 8.0
        self.max_distance = 150.0
        self.min_elevation = -75.0
        self.max_elevation = 15.0
        
        # Suavização de movimento
        self.smoothing = 0.85
        self.zoom_sensitivity = 0.1
        self.rotation_sensitivity = 0.3
        
        # Estado de movimento
        self.target_distance = self.distance
        self.target_azimuth = self.azimuth
        self.target_elevation = self.elevation
        
        # Cache de posição para otimização
        self._position_cache = None
        self._view_matrix_dirty = True
    
    def apply_transform(self):
        """Aplica a transformação da câmera ao OpenGL"""
        if self._view_matrix_dirty:
            self._update_view_matrix()
            self._view_matrix_dirty = False
    
    def _update_view_matrix(self):
        """Calcula e aplica a matriz de visualização"""
        # Interpolar para movimento suave
        self.distance += (self.target_distance - self.distance) * (1.0 - self.smoothing)
        self.azimuth += self._angle_diff(self.target_azimuth, self.azimuth) * (1.0 - self.smoothing)
        self.elevation += (self.target_elevation - self.elevation) * (1.0 - self.smoothing)
        
        # Converter coordenadas esféricas para cartesianas
        pos = self._spherical_to_cartesian()
        
        # Configurar matriz de visualização
        glLoadIdentity()
        gluLookAt(
            pos[0], pos[1], pos[2],           # Posição da câmera
            self.target_x, self.target_y, self.target_z,  # Ponto alvo
            0.0, 0.0, 1.0                     # Vetor up (Z up)
        )
        
        self._position_cache = pos
    
    def _spherical_to_cartesian(self):
        """Converte coordenadas esféricas para cartesianas"""
        # Converter graus para radianos
        azimuth_rad = math.radians(self.azimuth)
        elevation_rad = math.radians(self.elevation)
        
        # Calcular posição cartesiana
        cos_elevation = math.cos(elevation_rad)
        
        x = self.target_x + self.distance * cos_elevation * math.sin(azimuth_rad)
        y = self.target_y + self.distance * cos_elevation * math.cos(azimuth_rad)
        z = self.target_z + self.distance * math.sin(elevation_rad)
        
        return (x, y, z)
    
    def _angle_diff(self, target, current):
        """Calcula a menor diferença angular (com wrap-around)"""
        diff = target - current
        
        # Normalizar para [-180, 180]
        while diff > 180:
            diff -= 360
        while diff < -180:
            diff += 360
        
        return diff
    
    def zoom(self, delta):
        """Ajusta o zoom da câmera"""
        zoom_amount = delta * self.zoom_sensitivity * self.distance
        self.target_distance = max(self.min_distance, 
                                  min(self.max_distance, 
                                      self.target_distance + zoom_amount))
        self._view_matrix_dirty = True
    
    def rotate(self, delta_azimuth, delta_elevation):
        """Rotaciona a câmera"""
        self.target_azimuth += delta_azimuth * self.rotation_sensitivity
        self.target_elevation += delta_elevation * self.rotation_sensitivity
        
        # Aplicar limites de elevação
        self.target_elevation = max(self.min_elevation,
                                   min(self.max_elevation,
                                       self.target_elevation))
        
        # Normalizar azimute
        self.target_azimuth = self.target_azimuth % 360.0
        
        self._view_matrix_dirty = True
    
    def rotate_by_mouse(self, delta_x, delta_y):
        """Rotaciona baseado no movimento do mouse"""
        # Sensibilidade baseada na distância (mais longe = menos sensível)
        distance_factor = math.sqrt(self.distance / 45.0)
        
        azimuth_delta = -delta_x * 0.5 * distance_factor
        elevation_delta = delta_y * 0.3 * distance_factor
        
        self.rotate(azimuth_delta, elevation_delta)
    
    def pan(self, delta_x, delta_y):
        """Move o ponto de foco (pan)"""
        # Calcular vetores de movimento baseados na orientação atual
        azimuth_rad = math.radians(self.azimuth)
        
        # Vetor direita (perpendicular à direção de visão)
        right_x = math.cos(azimuth_rad)
        right_y = -math.sin(azimuth_rad)
        
        # Vetor para cima (no plano horizontal)
        up_x = math.sin(azimuth_rad)
        up_y = math.cos(azimuth_rad)
        
        # Aplicar movimento
        pan_speed = self.distance * 0.002
        
        self.target_x += (right_x * delta_x + up_x * delta_y) * pan_speed
        self.target_y += (right_y * delta_x + up_y * delta_y) * pan_speed
        
        self._view_matrix_dirty = True
    
    def focus_on_point(self, x, y, z):
        """Foca a câmera em um ponto específico"""
        self.target_x = x
        self.target_y = y
        self.target_z = z
        self._view_matrix_dirty = True
    
    def set_distance(self, distance):
        """Define a distância da câmera"""
        self.target_distance = max(self.min_distance,
                                  min(self.max_distance, distance))
        self._view_matrix_dirty = True
    
    def set_angles(self, azimuth, elevation):
        """Define os ângulos da câmera"""
        self.target_azimuth = azimuth % 360.0
        self.target_elevation = max(self.min_elevation,
                                   min(self.max_elevation, elevation))
        self._view_matrix_dirty = True
    
    def get_position(self):
        """Retorna a posição atual da câmera"""
        if self._position_cache is None:
            return self._spherical_to_cartesian()
        return self._position_cache
    
    def get_direction(self):
        """Retorna o vetor de direção da câmera"""
        pos = self.get_position()
        dx = self.target_x - pos[0]
        dy = self.target_y - pos[1]
        dz = self.target_z - pos[2]
        
        length = math.sqrt(dx*dx + dy*dy + dz*dz)
        if length > 0:
            return (dx/length, dy/length, dz/length)
        return (0, 0, -1)
    
    def is_point_in_view(self, x, y, z, radius=0):
        """Verifica se um ponto está no campo de visão (frustum culling simples)"""
        # Calcular distância do ponto à câmera
        pos = self.get_position()
        dx = x - pos[0]
        dy = y - pos[1]
        dz = z - pos[2]
        distance = math.sqrt(dx*dx + dy*dy + dz*dz)
        
        # Verificar se está dentro da distância de renderização
        if distance + radius < 0.5 or distance - radius > 800.0:
            return False
        
        # Teste simples de ângulo (aproximado)
        direction = self.get_direction()
        if distance > 0:
            dot = (dx * direction[0] + dy * direction[1] + dz * direction[2]) / distance
            # Campo de visão aproximado de 60 graus = cos(30°) ≈ 0.866
            return dot > 0.5  # Mais conservador para incluir objetos nas bordas
        
        return True
    
    def get_info(self):
        """Retorna informações da câmera para debug"""
        pos = self.get_position()
        return {
            'position': pos,
            'target': (self.target_x, self.target_y, self.target_z),
            'distance': self.distance,
            'azimuth': self.azimuth,
            'elevation': self.elevation,
            'target_distance': self.target_distance,
            'target_azimuth': self.target_azimuth,
            'target_elevation': self.target_elevation
        }