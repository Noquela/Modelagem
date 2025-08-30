"""
Sistema de câmera orbital para o simulador de tráfego 3D
Permite controle mouse para rotação e zoom ao redor da intersecção
"""
import numpy as np
import pygame
import math
from typing import Tuple, Optional
from ..utils.config import CAMERA_CONFIG
from ..utils.math_helpers import create_look_at_matrix, clamp, normalize


class OrbitalCamera:
    def __init__(self, target: np.ndarray = None, position: np.ndarray = None):
        """
        Inicializa câmera orbital.
        
        Args:
            target: Ponto para onde a câmera olha (centro da intersecção)
            position: Posição inicial da câmera
        """
        self.target = target if target is not None else np.array(CAMERA_CONFIG['default_target'], dtype=np.float32)
        
        if position is not None:
            self.position = position.astype(np.float32)
        else:
            self.position = np.array(CAMERA_CONFIG['default_position'], dtype=np.float32)
        
        # Parâmetros orbitais (em coordenadas esféricas)
        self.distance = np.linalg.norm(self.position - self.target)
        self.azimuth = math.atan2(self.position[2] - self.target[2], self.position[0] - self.target[0])
        self.elevation = math.asin((self.position[1] - self.target[1]) / self.distance)
        
        # Controles
        self.mouse_sensitivity = CAMERA_CONFIG['rotation_speed']
        self.zoom_sensitivity = CAMERA_CONFIG['zoom_speed']
        self.movement_speed = CAMERA_CONFIG['movement_speed']
        
        # Estado dos controles
        self.is_dragging = False
        self.last_mouse_pos = (0, 0)
        self.keys_pressed = set()
        
        # Limites
        self.min_distance = CAMERA_CONFIG['min_distance']
        self.max_distance = CAMERA_CONFIG['max_distance']
        self.min_elevation = CAMERA_CONFIG['min_elevation']
        self.max_elevation = CAMERA_CONFIG['max_elevation']
        
        # Up vector
        self.up = np.array([0, 1, 0], dtype=np.float32)
        
        # Matriz view
        self.view_matrix = np.eye(4, dtype=np.float32)
        self._update_view_matrix()
    
    def handle_mouse_button(self, event: pygame.event.Event):
        """Processa eventos de mouse button."""
        if event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:  # Botão esquerdo
                self.is_dragging = True
                self.last_mouse_pos = pygame.mouse.get_pos()
        
        elif event.type == pygame.MOUSEBUTTONUP:
            if event.button == 1:  # Botão esquerdo
                self.is_dragging = False
    
    def handle_mouse_motion(self, event: pygame.event.Event):
        """Processa movimento do mouse."""
        if not self.is_dragging:
            return
        
        current_pos = pygame.mouse.get_pos()
        delta_x = current_pos[0] - self.last_mouse_pos[0]
        delta_y = current_pos[1] - self.last_mouse_pos[1]
        
        # Rotacionar câmera
        self.azimuth -= delta_x * self.mouse_sensitivity
        self.elevation += delta_y * self.mouse_sensitivity
        
        # Limitar elevação
        self.elevation = clamp(self.elevation, self.min_elevation, self.max_elevation)
        
        # Normalizar azimuth
        self.azimuth = self.azimuth % (2 * math.pi)
        
        self.last_mouse_pos = current_pos
        self._update_position()
    
    def handle_mouse_wheel(self, event: pygame.event.Event):
        """Processa scroll do mouse para zoom."""
        if event.type == pygame.MOUSEWHEEL:
            zoom_delta = -event.y * self.zoom_sensitivity
            self.distance = clamp(
                self.distance + zoom_delta,
                self.min_distance,
                self.max_distance
            )
            self._update_position()
    
    def handle_keyboard(self, event: pygame.event.Event):
        """Processa eventos de teclado."""
        if event.type == pygame.KEYDOWN:
            self.keys_pressed.add(event.key)
        elif event.type == pygame.KEYUP:
            self.keys_pressed.discard(event.key)
    
    def update(self, dt: float):
        """Atualiza câmera (chamado a cada frame)."""
        # Movimento do target com teclas WASD
        movement_delta = np.array([0.0, 0.0, 0.0], dtype=np.float32)
        speed = self.movement_speed * dt * 60  # Ajustar por FPS
        
        if pygame.K_w in self.keys_pressed:
            movement_delta[2] -= speed
        if pygame.K_s in self.keys_pressed:
            movement_delta[2] += speed
        if pygame.K_a in self.keys_pressed:
            movement_delta[0] -= speed
        if pygame.K_d in self.keys_pressed:
            movement_delta[0] += speed
        if pygame.K_q in self.keys_pressed:
            movement_delta[1] += speed
        if pygame.K_e in self.keys_pressed:
            movement_delta[1] -= speed
        
        # Aplicar movimento
        if np.any(movement_delta):
            self.target += movement_delta
            self._update_position()
    
    def _update_position(self):
        """Atualiza posição da câmera baseada nos parâmetros orbitais."""
        x = self.target[0] + self.distance * math.cos(self.elevation) * math.cos(self.azimuth)
        y = self.target[1] + self.distance * math.sin(self.elevation)
        z = self.target[2] + self.distance * math.cos(self.elevation) * math.sin(self.azimuth)
        
        self.position = np.array([x, y, z], dtype=np.float32)
        self._update_view_matrix()
    
    def _update_view_matrix(self):
        """Atualiza matriz view baseada na posição e target atuais."""
        self.view_matrix = create_look_at_matrix(self.position, self.target, self.up)
    
    def reset(self):
        """Reseta câmera para posição padrão."""
        self.target = np.array(CAMERA_CONFIG['default_target'], dtype=np.float32)
        self.position = np.array(CAMERA_CONFIG['default_position'], dtype=np.float32)
        
        self.distance = np.linalg.norm(self.position - self.target)
        self.azimuth = math.atan2(self.position[2] - self.target[2], self.position[0] - self.target[0])
        self.elevation = math.asin((self.position[1] - self.target[1]) / self.distance)
        
        self._update_view_matrix()
    
    def focus_on(self, target: np.ndarray, distance: Optional[float] = None):
        """Foca câmera em um ponto específico."""
        self.target = target.astype(np.float32)
        
        if distance is not None:
            self.distance = clamp(distance, self.min_distance, self.max_distance)
        
        self._update_position()
    
    def set_orbital_params(self, azimuth: float, elevation: float, distance: float):
        """Define parâmetros orbitais diretamente."""
        self.azimuth = azimuth % (2 * math.pi)
        self.elevation = clamp(elevation, self.min_elevation, self.max_elevation)
        self.distance = clamp(distance, self.min_distance, self.max_distance)
        self._update_position()
    
    def get_view_matrix(self) -> np.ndarray:
        """Retorna matriz view atual."""
        return self.view_matrix
    
    def get_position(self) -> np.ndarray:
        """Retorna posição atual da câmera."""
        return self.position.copy()
    
    def get_target(self) -> np.ndarray:
        """Retorna target atual da câmera."""
        return self.target.copy()
    
    def get_forward_vector(self) -> np.ndarray:
        """Retorna vetor para frente da câmera."""
        return normalize(self.target - self.position)
    
    def get_right_vector(self) -> np.ndarray:
        """Retorna vetor para direita da câmera."""
        forward = self.get_forward_vector()
        return normalize(np.cross(forward, self.up))
    
    def get_up_vector(self) -> np.ndarray:
        """Retorna vetor para cima da câmera."""
        forward = self.get_forward_vector()
        right = self.get_right_vector()
        return normalize(np.cross(right, forward))
    
    def screen_to_world_ray(self, screen_x: int, screen_y: int, 
                           screen_width: int, screen_height: int) -> Tuple[np.ndarray, np.ndarray]:
        """
        Converte coordenadas de tela para raio no mundo 3D.
        
        Returns:
            Tuple[origem_do_raio, direção_do_raio]
        """
        # Normalizar coordenadas de tela para [-1, 1]
        x = (2.0 * screen_x) / screen_width - 1.0
        y = 1.0 - (2.0 * screen_y) / screen_height
        
        # Criar raio em espaço de clip
        ray_clip = np.array([x, y, -1.0, 1.0], dtype=np.float32)
        
        # Transformar para espaço de view
        # (Precisaríamos da matriz de projeção inversa aqui)
        # Para simplificar, usar aproximação baseada na câmera
        
        forward = self.get_forward_vector()
        right = self.get_right_vector()
        up = self.get_up_vector()
        
        # Aproximação da direção do raio
        ray_dir = forward + right * x * 0.5 + up * y * 0.5
        ray_dir = normalize(ray_dir)
        
        return self.position.copy(), ray_dir
    
    def is_point_visible(self, point: np.ndarray, margin: float = 1.0) -> bool:
        """
        Verifica se um ponto está visível pela câmera.
        
        Args:
            point: Ponto 3D para verificar
            margin: Margem extra para consideração
            
        Returns:
            True se o ponto estiver visível
        """
        # Calcular distância do ponto à câmera
        distance_to_point = np.linalg.norm(point - self.position)
        
        # Verificar se está dentro do range visível
        if distance_to_point > self.max_distance + margin:
            return False
        
        # Verificar se está à frente da câmera
        to_point = normalize(point - self.position)
        forward = self.get_forward_vector()
        
        dot_product = np.dot(to_point, forward)
        
        # Se o dot product for positivo, o ponto está à frente
        return dot_product > 0.1  # Pequena margem para evitar edge cases
    
    def get_info(self) -> dict:
        """Retorna informações da câmera para debug/UI."""
        return {
            'position': tuple(self.position),
            'target': tuple(self.target),
            'distance': self.distance,
            'azimuth_deg': math.degrees(self.azimuth),
            'elevation_deg': math.degrees(self.elevation),
            'is_dragging': self.is_dragging,
        }