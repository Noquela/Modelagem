"""
Sistema de semáforos sincronizados para o simulador de tráfego 3D
Implementa lógica baseada no protótipo HTML com tempos de segurança
"""
import numpy as np
import time
from enum import Enum
from typing import List, Dict, Any, Tuple
from ..utils.config import LIGHT_TIMING, LIGHT_STATE, SCENE_CONFIG
from ..utils.math_helpers import (
    create_translation_matrix, 
    create_rotation_matrix, 
    create_scale_matrix
)


class LightState(Enum):
    RED = LIGHT_STATE['RED']
    YELLOW = LIGHT_STATE['YELLOW']
    GREEN = LIGHT_STATE['GREEN']


class TrafficLightType(Enum):
    MAIN_ROAD = "main_road"
    ONE_WAY_ROAD = "one_way_road"


class TrafficLight:
    """
    Classe individual de semáforo.
    Representa um poste físico com suas luzes.
    """
    
    def __init__(self, position: np.ndarray, rotation_y: float, 
                 light_type: TrafficLightType, light_id: str):
        """
        Inicializa um semáforo.
        
        Args:
            position: Posição 3D do semáforo
            rotation_y: Rotação em Y (direção que aponta)
            light_type: Tipo do semáforo (rua principal ou mão única)
            light_id: Identificador único
        """
        self.position = position.astype(np.float32)
        self.rotation_y = rotation_y
        self.type = light_type
        self.id = light_id
        
        # Estado atual
        self.current_state = LightState.RED
        
        # Geometria do semáforo
        self._create_geometry()
        
        # Matriz de modelo
        self.model_matrix = np.eye(4, dtype=np.float32)
        self._update_model_matrix()
    
    def _create_geometry(self):
        """Cria geometria 3D do semáforo (poste, haste, caixa, luzes)."""
        vertices_list = []
        indices_list = []
        vertex_offset = 0
        
        # === POSTE PRINCIPAL ===
        pole_height = 4.0
        pole_radius = 0.1
        pole_segments = 8
        
        # Criar cilindro para o poste
        pole_vertices, pole_indices = self._create_cylinder(
            radius=pole_radius, 
            height=pole_height, 
            segments=pole_segments,
            center=np.array([0, pole_height/2, 0]),
            color=(0.4, 0.4, 0.4)  # Cinza escuro
        )
        
        vertices_list.append(pole_vertices)
        indices_list.append(pole_indices + vertex_offset)
        vertex_offset += len(pole_vertices)
        
        # === HASTE HORIZONTAL ===
        arm_length = 3.0
        arm_radius = 0.05
        arm_height = pole_height - 0.2
        
        arm_vertices, arm_indices = self._create_cylinder(
            radius=arm_radius,
            height=arm_length,
            segments=6,
            center=np.array([arm_length/2, arm_height, 0]),
            color=(0.4, 0.4, 0.4),
            horizontal=True  # Cilindro horizontal
        )
        
        vertices_list.append(arm_vertices)
        indices_list.append(arm_indices + vertex_offset)
        vertex_offset += len(arm_vertices)
        
        # === CAIXA DO SEMÁFORO ===
        box_size = np.array([0.6, 1.8, 0.3])
        box_pos = np.array([arm_length - 0.3, arm_height, 0])
        
        box_vertices, box_indices = self._create_box(
            size=box_size,
            center=box_pos,
            color=(0.2, 0.2, 0.2)  # Preto
        )
        
        vertices_list.append(box_vertices)
        indices_list.append(box_indices + vertex_offset)
        vertex_offset += len(box_vertices)
        
        # === LUZES ===
        light_radius = 0.15
        light_positions = [
            box_pos + np.array([0.2, 0.5, 0]),   # Vermelho (topo)
            box_pos + np.array([0.2, 0.0, 0]),   # Amarelo (meio)
            box_pos + np.array([0.2, -0.5, 0]),  # Verde (base)
        ]
        
        light_colors = [
            (1.0, 0.0, 0.0),  # Vermelho
            (1.0, 1.0, 0.0),  # Amarelo
            (0.0, 1.0, 0.0),  # Verde
        ]
        
        self.light_positions = light_positions  # Salvar para animação
        
        for i, (pos, color) in enumerate(zip(light_positions, light_colors)):
            light_vertices, light_indices = self._create_sphere(
                radius=light_radius,
                center=pos,
                color=color,
                segments=8
            )
            
            vertices_list.append(light_vertices)
            indices_list.append(light_indices + vertex_offset)
            vertex_offset += len(light_vertices)
        
        # Combinar toda geometria
        self.vertices = np.vstack(vertices_list)
        self.indices = np.concatenate(indices_list)
    
    def _create_cylinder(self, radius: float, height: float, segments: int,
                        center: np.ndarray, color: Tuple[float, float, float],
                        horizontal: bool = False) -> Tuple[np.ndarray, np.ndarray]:
        """Cria geometria de cilindro."""
        vertices = []
        indices = []
        
        # Vértices do cilindro
        for i in range(segments + 1):
            angle = 2 * np.pi * i / segments
            x = radius * np.cos(angle)
            z = radius * np.sin(angle)
            
            if horizontal:
                # Cilindro horizontal (para haste)
                vertices.extend([
                    [center[0] - height/2, center[1] + x, center[2] + z, 0, 1, 0, 0, 0, *color],
                    [center[0] + height/2, center[1] + x, center[2] + z, 0, 1, 0, 1, 0, *color]
                ])
            else:
                # Cilindro vertical (para poste)
                vertices.extend([
                    [center[0] + x, center[1] - height/2, center[2] + z, 0, 1, 0, 0, 0, *color],
                    [center[0] + x, center[1] + height/2, center[2] + z, 0, 1, 0, 1, 0, *color]
                ])
        
        # Índices para faces do cilindro
        for i in range(segments):
            base = i * 2
            indices.extend([
                base, base + 1, base + 2,
                base + 1, base + 3, base + 2
            ])
        
        return np.array(vertices, dtype=np.float32), np.array(indices, dtype=np.uint32)
    
    def _create_box(self, size: np.ndarray, center: np.ndarray, 
                   color: Tuple[float, float, float]) -> Tuple[np.ndarray, np.ndarray]:
        """Cria geometria de caixa."""
        half_size = size / 2
        
        vertices = np.array([
            # Face frontal
            [center[0] - half_size[0], center[1] - half_size[1], center[2] + half_size[2], 0, 0, 1, 0, 0, *color],
            [center[0] + half_size[0], center[1] - half_size[1], center[2] + half_size[2], 0, 0, 1, 1, 0, *color],
            [center[0] + half_size[0], center[1] + half_size[1], center[2] + half_size[2], 0, 0, 1, 1, 1, *color],
            [center[0] - half_size[0], center[1] + half_size[1], center[2] + half_size[2], 0, 0, 1, 0, 1, *color],
            
            # Face traseira
            [center[0] + half_size[0], center[1] - half_size[1], center[2] - half_size[2], 0, 0, -1, 0, 0, *color],
            [center[0] - half_size[0], center[1] - half_size[1], center[2] - half_size[2], 0, 0, -1, 1, 0, *color],
            [center[0] - half_size[0], center[1] + half_size[1], center[2] - half_size[2], 0, 0, -1, 1, 1, *color],
            [center[0] + half_size[0], center[1] + half_size[1], center[2] - half_size[2], 0, 0, -1, 0, 1, *color],
            
            # Outras faces... (simplificado para brevidade)
        ], dtype=np.float32)
        
        indices = np.array([
            0, 1, 2, 0, 2, 3,  # Frente
            4, 5, 6, 4, 6, 7,  # Trás
            # Adicionar outras faces...
        ], dtype=np.uint32)
        
        return vertices, indices
    
    def _create_sphere(self, radius: float, center: np.ndarray, 
                      color: Tuple[float, float, float], segments: int) -> Tuple[np.ndarray, np.ndarray]:
        """Cria geometria de esfera (simplificada como icosfera)."""
        vertices = []
        indices = []
        
        # Criar esfera simplificada (8 faces triangulares)
        for i in range(segments):
            for j in range(segments):
                theta = 2 * np.pi * i / segments
                phi = np.pi * j / segments
                
                x = radius * np.sin(phi) * np.cos(theta) + center[0]
                y = radius * np.cos(phi) + center[1]
                z = radius * np.sin(phi) * np.sin(theta) + center[2]
                
                vertices.append([x, y, z, 0, 1, 0, 0, 0, *color])
        
        # Índices simplificados
        for i in range(len(vertices)):
            indices.append(i)
        
        return np.array(vertices, dtype=np.float32), np.array(indices, dtype=np.uint32)
    
    def _update_model_matrix(self):
        """Atualiza matriz de modelo do semáforo."""
        translation = create_translation_matrix(*self.position)
        rotation = create_rotation_matrix(0, self.rotation_y, 0)
        self.model_matrix = translation @ rotation
    
    def set_state(self, state: LightState):
        """Define estado do semáforo."""
        self.current_state = state
        # Aqui poderíamos atualizar cores/intensidades das luzes
    
    def get_current_state(self) -> int:
        """Retorna estado atual como integer (compatibilidade com protótipo)."""
        return self.current_state.value
    
    def get_state_name(self) -> str:
        """Retorna nome do estado atual."""
        return self.current_state.name
    
    def get_model_matrix(self) -> np.ndarray:
        """Retorna matriz de modelo."""
        return self.model_matrix
    
    def get_vertices(self) -> np.ndarray:
        """Retorna vértices do semáforo."""
        return self.vertices
    
    def get_indices(self) -> np.ndarray:
        """Retorna índices do semáforo."""
        return self.indices


class TrafficLightSystem:
    """
    Sistema de gerenciamento de semáforos sincronizados.
    Implementa a lógica do protótipo HTML: 2 na rua principal + 1 na mão única.
    """
    
    def __init__(self):
        """Inicializa sistema de semáforos."""
        self.lights: List[TrafficLight] = []
        self.start_time = time.time()
        self.cycle_time = LIGHT_TIMING['total_cycle'] / 1000.0  # Converter para segundos
        
        # Criar semáforos
        self._create_traffic_lights()
        
        # Estado do sistema
        self.is_running = True
        self.debug_info = {}
    
    def _create_traffic_lights(self):
        """Cria os 3 semáforos: 2 na rua principal, 1 na mão única."""
        # Semáforo 1: Rua principal - lado esquerdo
        light1 = TrafficLight(
            position=np.array([-5.0, 0.0, 5.0]),
            rotation_y=np.pi / 2,  # Apontando para rua
            light_type=TrafficLightType.MAIN_ROAD,
            light_id="main_road_1"
        )
        self.lights.append(light1)
        
        # Semáforo 2: Rua principal - lado direito  
        light2 = TrafficLight(
            position=np.array([5.0, 0.0, -5.0]),
            rotation_y=-np.pi / 2,  # Apontando para rua
            light_type=TrafficLightType.MAIN_ROAD,
            light_id="main_road_2"
        )
        self.lights.append(light2)
        
        # Semáforo 3: Rua de mão única
        light3 = TrafficLight(
            position=np.array([-5.0, 0.0, -5.0]),
            rotation_y=0.0,  # Apontando para baixo
            light_type=TrafficLightType.ONE_WAY_ROAD,
            light_id="one_way_1"
        )
        self.lights.append(light3)
    
    def update(self, dt: float):
        """
        Atualiza estados dos semáforos baseado no tempo.
        Implementa lógica exata do protótipo HTML.
        """
        if not self.is_running:
            return
        
        current_time = time.time()
        elapsed_time = (current_time - self.start_time) % self.cycle_time
        phase = elapsed_time / self.cycle_time
        
        # Calcular estados baseado na fase do ciclo
        main_road_state, one_way_state = self._calculate_states(phase)
        
        # Aplicar estados aos semáforos
        for light in self.lights:
            if light.type == TrafficLightType.MAIN_ROAD:
                light.set_state(main_road_state)
            else:  # ONE_WAY_ROAD
                light.set_state(one_way_state)
        
        # Atualizar debug info
        self.debug_info = {
            'cycle_phase': phase,
            'elapsed_time': elapsed_time,
            'main_road_state': main_road_state.name,
            'one_way_state': one_way_state.name,
        }
    
    def _calculate_states(self, phase: float) -> Tuple[LightState, LightState]:
        """
        Calcula estados dos semáforos baseado na fase do ciclo.
        
        Lógica do protótipo (37 segundos total):
        - 0-15s: Rua principal VERDE, mão única VERMELHO
        - 15-18s: Rua principal AMARELO, mão única VERMELHO  
        - 18-19s: SEGURANÇA - ambos VERMELHO
        - 19-34s: Rua principal VERMELHO, mão única VERDE
        - 34-37s: Rua principal VERMELHO, mão única AMARELO
        """
        green_time = LIGHT_TIMING['green_time'] / 1000.0  # 15s
        yellow_time = LIGHT_TIMING['yellow_time'] / 1000.0  # 3s
        safety_time = LIGHT_TIMING['safety_time'] / 1000.0  # 1s
        
        # Tempos acumulativos
        main_green_end = green_time / self.cycle_time  # ~0.405
        main_yellow_end = (green_time + yellow_time) / self.cycle_time  # ~0.486
        safety_end = (green_time + yellow_time + safety_time) / self.cycle_time  # ~0.513
        one_way_green_end = (green_time + yellow_time + safety_time + green_time) / self.cycle_time  # ~0.918
        one_way_yellow_end = (green_time + yellow_time + safety_time + green_time + yellow_time) / self.cycle_time  # ~1.0
        
        if phase < main_green_end:
            # Rua principal verde, mão única vermelho
            return LightState.GREEN, LightState.RED
        
        elif phase < main_yellow_end:
            # Rua principal amarelo, mão única vermelho
            return LightState.YELLOW, LightState.RED
        
        elif phase < safety_end:
            # Tempo de segurança - ambos vermelhos
            return LightState.RED, LightState.RED
        
        elif phase < one_way_green_end:
            # Rua principal vermelho, mão única verde
            return LightState.RED, LightState.GREEN
        
        elif phase < one_way_yellow_end:
            # Rua principal vermelho, mão única amarelo
            return LightState.RED, LightState.YELLOW
        
        else:
            # Tempo de segurança final
            return LightState.RED, LightState.RED
    
    def get_lights_by_type(self, light_type: TrafficLightType) -> List[TrafficLight]:
        """Retorna semáforos de um tipo específico."""
        return [light for light in self.lights if light.type == light_type]
    
    def get_main_road_state(self) -> LightState:
        """Retorna estado atual dos semáforos da rua principal."""
        main_lights = self.get_lights_by_type(TrafficLightType.MAIN_ROAD)
        return main_lights[0].current_state if main_lights else LightState.RED
    
    def get_one_way_state(self) -> LightState:
        """Retorna estado atual do semáforo da mão única."""
        one_way_lights = self.get_lights_by_type(TrafficLightType.ONE_WAY_ROAD)
        return one_way_lights[0].current_state if one_way_lights else LightState.RED
    
    def reset_cycle(self):
        """Reinicia ciclo dos semáforos."""
        self.start_time = time.time()
    
    def pause(self):
        """Pausa sistema de semáforos."""
        self.is_running = False
    
    def resume(self):
        """Resume sistema de semáforos."""
        if not self.is_running:
            # Ajustar tempo para manter sincronia
            current_time = time.time()
            self.start_time = current_time - ((current_time - self.start_time) % self.cycle_time)
            self.is_running = True
    
    def get_lights(self) -> List[TrafficLight]:
        """Retorna lista de todos os semáforos."""
        return self.lights
    
    def get_debug_info(self) -> Dict[str, Any]:
        """Retorna informações de debug do sistema."""
        return self.debug_info
    
    def cleanup(self):
        """Limpa recursos do sistema."""
        self.lights.clear()