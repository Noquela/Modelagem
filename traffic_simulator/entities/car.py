"""
Classe Car com sistema de IA comportamental avançado
Implementa personalidades de motorista, lógica de decisão e física realística
"""
import numpy as np
import random
import time
from dataclasses import dataclass
from enum import Enum
from typing import Optional, List, Tuple, Dict, Any

from ..utils.config import (
    CAR_CONFIG, CAR_DIRECTIONS, CAR_STATES, DRIVER_PERSONALITIES, 
    REALISTIC_CAR_COLORS, SCENE_CONFIG
)
from ..utils.math_helpers import (
    calculate_directional_distance, get_spawn_position, get_target_position,
    create_car_vertices, create_translation_matrix, create_rotation_matrix
)


class Direction(Enum):
    LEFT_TO_RIGHT = CAR_DIRECTIONS['LEFT_TO_RIGHT']
    RIGHT_TO_LEFT = CAR_DIRECTIONS['RIGHT_TO_LEFT'] 
    TOP_TO_BOTTOM = CAR_DIRECTIONS['TOP_TO_BOTTOM']


class CarState(Enum):
    DRIVING = CAR_STATES['DRIVING']
    STOPPING = CAR_STATES['STOPPING']
    WAITING = CAR_STATES['WAITING']
    ACCELERATING = CAR_STATES['ACCELERATING']


class DriverPersonality(Enum):
    AGGRESSIVE = "AGGRESSIVE"
    CONSERVATIVE = "CONSERVATIVE"
    NORMAL = "NORMAL"
    ELDERLY = "ELDERLY"


@dataclass
class CarPhysics:
    """Propriedades físicas do carro."""
    position: np.ndarray
    velocity: float = 0.0
    acceleration: float = 0.0
    max_speed: float = CAR_CONFIG['base_speed']
    length: float = CAR_CONFIG['length']
    width: float = CAR_CONFIG['width']
    height: float = CAR_CONFIG['height']
    
    # Caixa de colisão
    def get_bounding_box(self) -> Tuple[np.ndarray, np.ndarray]:
        """Retorna caixa de colisão (min, max)."""
        half_length = self.length / 2
        half_width = self.width / 2
        
        min_pos = self.position - np.array([half_length, 0, half_width])
        max_pos = self.position + np.array([half_length, self.height, half_width])
        
        return min_pos, max_pos


class Car:
    """
    Classe principal do carro com IA comportamental avançada.
    Baseada nas especificações do protótipo HTML mas expandida.
    """
    
    def __init__(self, direction: Direction, lane: int = 0, 
                 personality: Optional[DriverPersonality] = None):
        """
        Inicializa um carro.
        
        Args:
            direction: Direção do movimento
            lane: Faixa de rodagem (0, 1 para ruas principais)
            personality: Personalidade do motorista (aleatória se None)
        """
        self.direction = direction
        self.lane = lane
        
        # Personalidade do motorista
        if personality is None:
            personalities = list(DriverPersonality)
            weights = [0.15, 0.25, 0.5, 0.1]  # Agressivo, Conservador, Normal, Idoso
            self.personality = random.choices(personalities, weights=weights)[0]
        else:
            self.personality = personality
        
        # Configurações baseadas na personalidade
        self._setup_personality_traits()
        
        # Física do carro
        spawn_pos = get_spawn_position(direction.value, lane)
        self.physics = CarPhysics(
            position=spawn_pos,
            max_speed=self._calculate_max_speed()
        )
        
        # Estado atual
        self.state = CarState.DRIVING
        self.target_position = get_target_position(direction.value, lane)
        
        # Controle de movimento
        self.should_stop = False
        self.distance_to_obstacle = float('inf')
        self.has_passed_intersection = False
        self.stuck_timer = 0.0
        
        # Histórico e estatísticas
        self.spawn_time = time.time()
        self.total_wait_time = 0.0
        self.wait_start_time = 0.0
        
        # Visual
        self.color = random.choice(REALISTIC_CAR_COLORS)
        self.model_matrix = np.eye(4, dtype=np.float32)
        self.rotation_y = self._get_initial_rotation()
        
        # IA e decisão
        self.last_decision_time = 0.0
        self.decision_cooldown = self.reaction_time
        self.yellow_light_decision = None  # Cache da decisão no amarelo
        
        # Debug info
        self.debug_info = {}
        
        # Criar geometria
        self.vertices, self.indices = create_car_vertices()
        self._update_model_matrix()
    
    def _setup_personality_traits(self):
        """Configura traços baseados na personalidade do motorista."""
        traits = DRIVER_PERSONALITIES[self.personality.value]
        
        self.reaction_time = random.uniform(*traits['reaction_time'])
        self.following_distance_factor = traits['following_distance_factor']
        self.aggression_level = traits['aggression_level']
        self.yellow_light_probability = traits['yellow_light_probability']
        self.speed_factor = traits['speed_factor']
        
        # Variação individual dentro da personalidade
        variation = random.uniform(0.9, 1.1)
        self.following_distance_factor *= variation
        self.reaction_time *= variation
    
    def _calculate_max_speed(self) -> float:
        """Calcula velocidade máxima baseada na personalidade e variações."""
        base_speed = CAR_CONFIG['base_speed']
        speed_variation = random.uniform(*CAR_CONFIG['speed_variation_range'])
        return base_speed * self.speed_factor * speed_variation
    
    def _get_initial_rotation(self) -> float:
        """Retorna rotação inicial baseada na direção."""
        if self.direction == Direction.LEFT_TO_RIGHT:
            return 0.0
        elif self.direction == Direction.RIGHT_TO_LEFT:
            return np.pi
        elif self.direction == Direction.TOP_TO_BOTTOM:
            return -np.pi / 2
        return 0.0
    
    def _update_model_matrix(self):
        """Atualiza matriz de modelo do carro."""
        translation = create_translation_matrix(*self.physics.position)
        rotation = create_rotation_matrix(0, self.rotation_y, 0)
        self.model_matrix = translation @ rotation
    
    def update(self, dt: float, traffic_lights: List[Any], other_cars: List['Car']):
        """
        Atualiza o carro (IA, física, estado).
        
        Args:
            dt: Delta time em segundos
            traffic_lights: Lista de semáforos
            other_cars: Lista de outros carros
        """
        current_time = time.time()
        
        # Atualizar timer de stuck
        if self.physics.velocity < 0.001:
            self.stuck_timer += dt
        else:
            self.stuck_timer = 0.0
        
        # IA: Analisar situação e tomar decisões
        if current_time - self.last_decision_time >= self.decision_cooldown:
            self._make_driving_decision(traffic_lights, other_cars)
            self.last_decision_time = current_time
        
        # Atualizar física
        self._update_physics(dt)
        
        # Atualizar estado
        self._update_state(dt)
        
        # Atualizar estatísticas
        self._update_statistics(dt)
        
        # Atualizar matriz de modelo
        self._update_model_matrix()
    
    def _make_driving_decision(self, traffic_lights: List[Any], other_cars: List['Car']):
        """Lógica principal de IA para tomada de decisões."""
        self.should_stop = False
        self.distance_to_obstacle = float('inf')
        
        # PRIORIDADE 1: Verificar carros à frente
        car_ahead = self._find_car_ahead(other_cars)
        if car_ahead:
            distance_to_car = self._calculate_distance_to_car(car_ahead)
            min_following_distance = CAR_CONFIG['min_distance'] * self.following_distance_factor
            
            if distance_to_car <= min_following_distance:
                self.should_stop = True
                self.distance_to_obstacle = distance_to_car
                self.debug_info['reason'] = f'Following car at {distance_to_car:.1f}m'
                return
        
        # PRIORIDADE 2: Verificar semáforos (só se não passou da intersecção)
        if not self.has_passed_intersection:
            should_stop_light, distance_to_light = self._should_stop_at_traffic_light(traffic_lights)
            
            if should_stop_light:
                # REGRA CRÍTICA: Só para se conseguir parar com segurança ANTES da intersecção
                distance_to_intersection = self._get_distance_to_intersection()
                min_safe_distance = CAR_CONFIG['minimum_safe_stop_distance']
                
                if distance_to_intersection > min_safe_distance:
                    self.should_stop = True
                    self.distance_to_obstacle = distance_to_light
                    self.debug_info['reason'] = f'Traffic light at {distance_to_light:.1f}m'
                else:
                    # Muito perto para parar com segurança - continua
                    self.debug_info['reason'] = f'Too close to stop safely ({distance_to_intersection:.1f}m)'
        
        # Verificar se passou da intersecção
        if self._has_passed_intersection() and not self.has_passed_intersection:
            self.has_passed_intersection = True
            self.yellow_light_decision = None  # Reset decisão amarelo
    
    def _find_car_ahead(self, other_cars: List['Car']) -> Optional['Car']:
        """Encontra carro mais próximo à frente na mesma faixa."""
        closest_car = None
        closest_distance = float('inf')
        
        for car in other_cars:
            if (car == self or 
                car.direction != self.direction or 
                car.lane != self.lane):
                continue
            
            # Verificar se está à frente
            if self._is_car_ahead(car):
                distance = calculate_directional_distance(
                    self.physics.position, 
                    car.physics.position, 
                    self.direction.value
                )
                
                if 0 < distance < closest_distance and distance < CAR_CONFIG['visibility_range']:
                    closest_distance = distance
                    closest_car = car
        
        return closest_car
    
    def _is_car_ahead(self, other_car: 'Car') -> bool:
        """Verifica se outro carro está à frente na direção do movimento."""
        my_pos = self.physics.position
        other_pos = other_car.physics.position
        
        if self.direction == Direction.LEFT_TO_RIGHT:
            return other_pos[0] > my_pos[0]
        elif self.direction == Direction.RIGHT_TO_LEFT:
            return other_pos[0] < my_pos[0]
        elif self.direction == Direction.TOP_TO_BOTTOM:
            return other_pos[2] < my_pos[2]
        
        return False
    
    def _calculate_distance_to_car(self, other_car: 'Car') -> float:
        """Calcula distância até outro carro."""
        return calculate_directional_distance(
            self.physics.position,
            other_car.physics.position,
            self.direction.value
        )
    
    def _should_stop_at_traffic_light(self, traffic_lights: List[Any]) -> Tuple[bool, float]:
        """
        Verifica se deve parar no semáforo.
        
        Returns:
            Tuple[should_stop, distance_to_light]
        """
        relevant_light = self._find_relevant_traffic_light(traffic_lights)
        if not relevant_light:
            return False, float('inf')
        
        distance_to_light = self._get_distance_to_intersection()
        light_state = relevant_light.get_current_state()
        
        # VERMELHO: Sempre para
        if light_state == 0:  # RED
            return True, distance_to_light
        
        # VERDE: Não para
        if light_state == 2:  # GREEN
            return False, distance_to_light
        
        # AMARELO: Decisão baseada na personalidade e distância
        if light_state == 1:  # YELLOW
            return self._decide_on_yellow_light(distance_to_light), distance_to_light
        
        return False, distance_to_light
    
    def _decide_on_yellow_light(self, distance_to_intersection: float) -> bool:
        """Decide se para ou acelera no amarelo baseado na personalidade."""
        # Cache da decisão para evitar mudanças constantes
        if self.yellow_light_decision is not None:
            return self.yellow_light_decision
        
        # Fatores para decisão
        can_stop_safely = distance_to_intersection > CAR_CONFIG['minimum_safe_stop_distance']
        current_speed = self.physics.velocity
        
        # Muito próximo - não consegue parar
        if distance_to_intersection < 5.0:
            self.yellow_light_decision = False
            return False
        
        # Muito longe - fácil de parar
        if distance_to_intersection > 15.0:
            self.yellow_light_decision = True
            return True
        
        # Zona de decisão (5-15m) - usar personalidade
        if can_stop_safely:
            # Chance de parar baseada na personalidade
            stop_chance = 1.0 - self.yellow_light_probability
            
            # Ajustar pela velocidade atual
            if current_speed > self.physics.max_speed * 0.8:
                stop_chance -= 0.2  # Menos provável de parar se indo rápido
            
            # Ajustar pela distância
            distance_factor = (distance_to_intersection - 5.0) / 10.0  # 0-1
            stop_chance += distance_factor * 0.3
            
            self.yellow_light_decision = random.random() < stop_chance
            return self.yellow_light_decision
        
        # Não consegue parar com segurança
        self.yellow_light_decision = False
        return False
    
    def _find_relevant_traffic_light(self, traffic_lights: List[Any]) -> Optional[Any]:
        """Encontra semáforo relevante para este carro."""
        for light in traffic_lights:
            if self.direction in [Direction.LEFT_TO_RIGHT, Direction.RIGHT_TO_LEFT]:
                if hasattr(light, 'type') and light.type == 'main_road':
                    return light
            elif self.direction == Direction.TOP_TO_BOTTOM:
                if hasattr(light, 'type') and light.type == 'one_way_road':
                    return light
        return None
    
    def _get_distance_to_intersection(self) -> float:
        """Calcula distância até a intersecção."""
        intersection_boundary = SCENE_CONFIG['intersection_size'] / 2
        
        if self.direction == Direction.LEFT_TO_RIGHT:
            return max(0, -intersection_boundary - self.physics.position[0])
        elif self.direction == Direction.RIGHT_TO_LEFT:
            return max(0, self.physics.position[0] - intersection_boundary)
        elif self.direction == Direction.TOP_TO_BOTTOM:
            return max(0, self.physics.position[2] - intersection_boundary)
        
        return 0.0
    
    def _has_passed_intersection(self) -> bool:
        """Verifica se o carro passou da intersecção."""
        intersection_boundary = SCENE_CONFIG['intersection_size'] / 2
        
        if self.direction == Direction.LEFT_TO_RIGHT:
            return self.physics.position[0] > intersection_boundary
        elif self.direction == Direction.RIGHT_TO_LEFT:
            return self.physics.position[0] < -intersection_boundary
        elif self.direction == Direction.TOP_TO_BOTTOM:
            return self.physics.position[2] < -intersection_boundary
        
        return False
    
    def _update_physics(self, dt: float):
        """Atualiza física do carro (velocidade, posição)."""
        target_speed = 0.0 if self.should_stop else self.physics.max_speed
        
        # Calcular aceleração baseada no estado
        if self.should_stop:
            # Desaceleração mais suave quando próximo do obstáculo
            if self.distance_to_obstacle < 3.0:
                deceleration = CAR_CONFIG['deceleration'] * 2.0
            else:
                deceleration = CAR_CONFIG['deceleration']
            
            self.physics.acceleration = -deceleration
        else:
            self.physics.acceleration = CAR_CONFIG['acceleration']
        
        # Atualizar velocidade
        self.physics.velocity += self.physics.acceleration * dt * 60  # Ajustar por FPS
        self.physics.velocity = max(0, min(target_speed, self.physics.velocity))
        
        # Atualizar posição se há velocidade
        if self.physics.velocity > 0.001:
            self._move_car(dt)
    
    def _move_car(self, dt: float):
        """Move o carro baseado na velocidade e direção."""
        movement = self.physics.velocity * dt * 60  # Ajustar por FPS
        
        if self.direction == Direction.LEFT_TO_RIGHT:
            self.physics.position[0] += movement
        elif self.direction == Direction.RIGHT_TO_LEFT:
            self.physics.position[0] -= movement
        elif self.direction == Direction.TOP_TO_BOTTOM:
            self.physics.position[2] -= movement
    
    def _update_state(self, dt: float):
        """Atualiza estado do carro."""
        current_speed = self.physics.velocity
        
        if current_speed < 0.001:
            if self.should_stop:
                self.state = CarState.WAITING
                if self.wait_start_time == 0.0:
                    self.wait_start_time = time.time()
            else:
                self.state = CarState.ACCELERATING
        else:
            if self.wait_start_time > 0.0:
                self.total_wait_time += time.time() - self.wait_start_time
                self.wait_start_time = 0.0
            
            if current_speed < self.physics.max_speed * 0.9:
                self.state = CarState.ACCELERATING
            else:
                self.state = CarState.DRIVING
    
    def _update_statistics(self, dt: float):
        """Atualiza estatísticas do carro."""
        if self.state == CarState.WAITING and self.wait_start_time > 0.0:
            # Tempo de espera sendo contado em tempo real
            pass
        
        # Detectar se está stuck (parado por muito tempo sem razão)
        if self.stuck_timer > 5.0 and not self.should_stop:
            self.debug_info['stuck'] = True
    
    def is_out_of_bounds(self) -> bool:
        """Verifica se o carro saiu dos limites da cena."""
        pos = self.physics.position
        world_boundary = SCENE_CONFIG['world_size'] / 2 + 5  # Margem extra
        
        return (abs(pos[0]) > world_boundary or 
                abs(pos[2]) > world_boundary)
    
    def get_age(self) -> float:
        """Retorna idade do carro em segundos."""
        return time.time() - self.spawn_time
    
    def get_total_wait_time(self) -> float:
        """Retorna tempo total de espera."""
        wait_time = self.total_wait_time
        if self.wait_start_time > 0.0:
            wait_time += time.time() - self.wait_start_time
        return wait_time
    
    def get_info(self) -> Dict[str, Any]:
        """Retorna informações do carro para debug/UI."""
        return {
            'id': id(self),
            'direction': self.direction.name,
            'lane': self.lane,
            'personality': self.personality.value,
            'state': self.state.value,
            'position': tuple(self.physics.position),
            'velocity': self.physics.velocity,
            'should_stop': self.should_stop,
            'distance_to_obstacle': self.distance_to_obstacle,
            'has_passed_intersection': self.has_passed_intersection,
            'age': self.get_age(),
            'total_wait_time': self.get_total_wait_time(),
            'stuck_timer': self.stuck_timer,
            'debug': self.debug_info,
        }
    
    def get_model_matrix(self) -> np.ndarray:
        """Retorna matriz de modelo atual."""
        return self.model_matrix
    
    def get_vertices(self) -> np.ndarray:
        """Retorna vértices do carro."""
        return self.vertices
    
    def get_indices(self) -> np.ndarray:
        """Retorna índices do carro."""
        return self.indices
    
    def get_color(self) -> Tuple[float, float, float]:
        """Retorna cor do carro."""
        return self.color