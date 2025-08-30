"""
Sistema de spawn inteligente para carros
Implementa lógica baseada no protótipo HTML com formação de filas e spawn dinâmico
"""
import random
import time
import numpy as np
from typing import List, Dict, Any, Optional, Tuple
from ..entities.car import Car, Direction, DriverPersonality
from ..utils.config import SPAWN_CONFIG, CAR_CONFIG, SCENE_CONFIG
from ..utils.math_helpers import calculate_directional_distance, get_spawn_position


class SpawnPoint:
    """Representa um ponto de spawn para carros."""
    
    def __init__(self, direction: Direction, lane: int):
        """
        Inicializa ponto de spawn.
        
        Args:
            direction: Direção do tráfego
            lane: Número da faixa (0, 1 para ruas principais)
        """
        self.direction = direction
        self.lane = lane
        self.position = get_spawn_position(direction.value, lane)
        
        # Estatísticas
        self.cars_spawned = 0
        self.last_spawn_time = 0.0
        self.spawn_attempts = 0
        self.blocked_attempts = 0
        
        # Controle de spawn
        self.cooldown_time = 1.0  # Tempo mínimo entre spawns
        self.is_blocked = False
        self.block_reason = ""
    
    def can_spawn(self, current_time: float) -> bool:
        """Verifica se pode spawnar baseado no cooldown."""
        return (current_time - self.last_spawn_time) >= self.cooldown_time
    
    def record_spawn(self, current_time: float):
        """Registra spawn realizado."""
        self.cars_spawned += 1
        self.last_spawn_time = current_time
    
    def record_blocked(self, reason: str):
        """Registra tentativa de spawn bloqueada."""
        self.spawn_attempts += 1
        self.blocked_attempts += 1
        self.is_blocked = True
        self.block_reason = reason
    
    def clear_block(self):
        """Limpa estado de bloqueio."""
        self.is_blocked = False
        self.block_reason = ""
    
    def get_stats(self) -> Dict[str, Any]:
        """Retorna estatísticas do ponto de spawn."""
        success_rate = 0.0
        if self.spawn_attempts > 0:
            success_rate = (self.spawn_attempts - self.blocked_attempts) / self.spawn_attempts
        
        return {
            'direction': self.direction.name,
            'lane': self.lane,
            'cars_spawned': self.cars_spawned,
            'spawn_attempts': self.spawn_attempts,
            'blocked_attempts': self.blocked_attempts,
            'success_rate': success_rate,
            'is_blocked': self.is_blocked,
            'block_reason': self.block_reason,
        }


class SpawnSystem:
    """
    Sistema inteligente de spawn de carros.
    Baseado na lógica do protótipo HTML mas expandido.
    """
    
    def __init__(self):
        """Inicializa sistema de spawn."""
        # Pontos de spawn
        self.spawn_points: List[SpawnPoint] = []
        self._create_spawn_points()
        
        # Configurações de spawn
        self.base_spawn_rate = SPAWN_CONFIG['base_rate']
        self.randomness_factor = SPAWN_CONFIG['randomness_factor']
        
        # Multiplicadores dinâmicos
        self.main_road_multiplier = SPAWN_CONFIG['main_road_multiplier']
        self.cross_road_multiplier = SPAWN_CONFIG['cross_road_multiplier']
        self.rush_hour_multiplier = 1.0
        
        # Estado do sistema
        self.is_active = True
        self.total_cars_spawned = 0
        self.last_update_time = time.time()
        
        # Análise de tráfego
        self.traffic_density = {}  # Por direção
        self.congestion_levels = {}  # Por spawn point
        
        # Debug
        self.debug_info = {}
    
    def _create_spawn_points(self):
        """Cria pontos de spawn para todas as direções e faixas."""
        # Rua principal (esquerda para direita) - 2 faixas
        for lane in range(2):
            spawn_point = SpawnPoint(Direction.LEFT_TO_RIGHT, lane)
            self.spawn_points.append(spawn_point)
        
        # Rua principal (direita para esquerda) - 2 faixas
        for lane in range(2):
            spawn_point = SpawnPoint(Direction.RIGHT_TO_LEFT, lane)
            self.spawn_points.append(spawn_point)
        
        # Rua de mão única (cima para baixo) - 1 faixa
        spawn_point = SpawnPoint(Direction.TOP_TO_BOTTOM, 0)
        self.spawn_points.append(spawn_point)
    
    def update(self, dt: float, cars: List[Car], traffic_lights: List[Any]) -> List[Car]:
        """
        Atualiza sistema de spawn e retorna novos carros criados.
        
        Args:
            dt: Delta time em segundos
            cars: Lista atual de carros na cena
            traffic_lights: Lista de semáforos
            
        Returns:
            Lista de novos carros spawned neste frame
        """
        if not self.is_active:
            return []
        
        current_time = time.time()
        new_cars = []
        
        # Analisar densidade de tráfego
        self._analyze_traffic_density(cars)
        
        # Calcular multiplicadores dinâmicos
        self._update_dynamic_multipliers(current_time)
        
        # Tentar spawn em cada ponto
        for spawn_point in self.spawn_points:
            if not spawn_point.can_spawn(current_time):
                continue
            
            # Calcular chance de spawn para este ponto
            spawn_chance = self._calculate_spawn_chance(spawn_point, cars, traffic_lights)
            
            if random.random() < spawn_chance:
                # Verificar se pode spawnar
                can_spawn, reason = self._can_spawn_at_point(spawn_point, cars)
                
                if can_spawn:
                    # Spawnar novo carro
                    new_car = self._spawn_car(spawn_point, current_time)
                    new_cars.append(new_car)
                    spawn_point.record_spawn(current_time)
                    spawn_point.clear_block()
                    self.total_cars_spawned += 1
                else:
                    spawn_point.record_blocked(reason)
            else:
                spawn_point.spawn_attempts += 1
        
        # Atualizar debug info
        self._update_debug_info(current_time)
        
        return new_cars
    
    def _analyze_traffic_density(self, cars: List[Car]):
        """Analisa densidade de tráfego atual."""
        # Reset contadores
        for direction in Direction:
            self.traffic_density[direction] = {
                'count': 0,
                'avg_speed': 0.0,
                'stopped_count': 0,
            }
        
        # Analisar carros existentes
        for car in cars:
            direction = car.direction
            density = self.traffic_density[direction]
            
            density['count'] += 1
            density['avg_speed'] += car.physics.velocity
            
            if car.physics.velocity < 0.001:
                density['stopped_count'] += 1
        
        # Calcular médias
        for direction in Direction:
            density = self.traffic_density[direction]
            if density['count'] > 0:
                density['avg_speed'] /= density['count']
                density['congestion'] = density['stopped_count'] / density['count']
            else:
                density['congestion'] = 0.0
    
    def _update_dynamic_multipliers(self, current_time: float):
        """Atualiza multiplicadores baseados em condições dinâmicas."""
        # Simulação de rush hour (simplificada)
        hour_of_day = (current_time % (24 * 3600)) / 3600  # Hora do dia simulada
        
        if 7 <= hour_of_day <= 9 or 17 <= hour_of_day <= 19:
            # Rush hours
            self.rush_hour_multiplier = SPAWN_CONFIG['rush_hour_multiplier']
        else:
            self.rush_hour_multiplier = 1.0
        
        # Ajustar multiplicadores baseado na congestion
        for direction in Direction:
            density = self.traffic_density.get(direction, {'congestion': 0.0})
            congestion = density['congestion']
            
            # Reduzir spawn se muito congestionado
            if congestion > 0.7:  # 70% dos carros parados
                if direction in [Direction.LEFT_TO_RIGHT, Direction.RIGHT_TO_LEFT]:
                    self.main_road_multiplier *= 0.7
                else:
                    self.cross_road_multiplier *= 0.7
    
    def _calculate_spawn_chance(self, spawn_point: SpawnPoint, cars: List[Car], 
                               traffic_lights: List[Any]) -> float:
        """
        Calcula chance de spawn para um ponto específico.
        
        Returns:
            Probabilidade de spawn (0.0 a 1.0)
        """
        base_chance = self.base_spawn_rate
        
        # Aplicar fator de aleatoriedade
        randomness = self.randomness_factor
        random_multiplier = random.uniform(1.0 - randomness, 1.0 + randomness)
        
        # Multiplicador por tipo de rua
        if spawn_point.direction in [Direction.LEFT_TO_RIGHT, Direction.RIGHT_TO_LEFT]:
            road_multiplier = self.main_road_multiplier
        else:
            road_multiplier = self.cross_road_multiplier
        
        # Multiplicador de rush hour
        rush_multiplier = self.rush_hour_multiplier
        
        # Ajustar baseado na densidade de tráfego
        direction_density = self.traffic_density.get(spawn_point.direction, {'count': 0})
        density_count = direction_density['count']
        
        # Reduzir spawn se há muitos carros na direção
        density_multiplier = 1.0
        if density_count > 10:
            density_multiplier = max(0.3, 1.0 - (density_count - 10) * 0.05)
        
        # Ajustar baseado no estado do semáforo
        traffic_light_multiplier = self._get_traffic_light_multiplier(spawn_point, traffic_lights)
        
        # Chance final
        final_chance = (base_chance * 
                       random_multiplier * 
                       road_multiplier * 
                       rush_multiplier * 
                       density_multiplier * 
                       traffic_light_multiplier)
        
        return min(1.0, final_chance)
    
    def _get_traffic_light_multiplier(self, spawn_point: SpawnPoint, 
                                    traffic_lights: List[Any]) -> float:
        """Calcula multiplicador baseado no estado do semáforo."""
        relevant_light = None
        
        # Encontrar semáforo relevante
        for light in traffic_lights:
            if spawn_point.direction in [Direction.LEFT_TO_RIGHT, Direction.RIGHT_TO_LEFT]:
                if hasattr(light, 'type') and light.type == 'main_road':
                    relevant_light = light
                    break
            elif spawn_point.direction == Direction.TOP_TO_BOTTOM:
                if hasattr(light, 'type') and light.type == 'one_way_road':
                    relevant_light = light
                    break
        
        if not relevant_light:
            return 1.0
        
        light_state = relevant_light.get_current_state()
        
        # Ajustar spawn baseado no estado do semáforo
        if light_state == 2:  # GREEN
            return 1.2  # Ligeiramente mais spawn quando verde
        elif light_state == 1:  # YELLOW
            return 0.8  # Menos spawn no amarelo
        else:  # RED
            return 1.0  # Spawn normal no vermelho (para formar filas)
    
    def _can_spawn_at_point(self, spawn_point: SpawnPoint, cars: List[Car]) -> Tuple[bool, str]:
        """
        Verifica se pode spawnar em um ponto específico.
        
        Returns:
            Tuple[can_spawn, reason_if_blocked]
        """
        # Verificar se há espaço livre ou se pode formar fila
        return self._has_space_for_spawning(spawn_point, cars)
    
    def _has_space_for_spawning(self, spawn_point: SpawnPoint, cars: List[Car]) -> Tuple[bool, str]:
        """
        Verifica se há espaço para spawning (incluindo formação de filas).
        Baseado na lógica do protótipo HTML.
        """
        min_distance = SPAWN_CONFIG['min_spawn_distance']
        spawn_pos = spawn_point.position
        
        # Filtrar carros na mesma direção e faixa
        relevant_cars = [
            car for car in cars 
            if (car.direction == spawn_point.direction and 
                car.lane == spawn_point.lane)
        ]
        
        if not relevant_cars:
            return True, ""  # Sem carros, pode spawnar
        
        # Encontrar carro mais próximo do spawn
        closest_distance = float('inf')
        closest_car = None
        
        for car in relevant_cars:
            # Calcular distância direcional do spawn ao carro
            distance = calculate_directional_distance(
                spawn_pos, 
                car.physics.position, 
                spawn_point.direction.value
            )
            
            # Se distância é negativa, o carro está atrás do spawn (impossível)
            # Se positiva, está à frente
            if distance >= 0 and distance < closest_distance:
                closest_distance = distance
                closest_car = car
        
        # Verificar se há espaço suficiente
        if closest_distance >= min_distance:
            return True, ""
        
        # Espaço insuficiente - verificar se é temporário ou permanente
        if closest_car and closest_car.physics.velocity < 0.001:
            # Carro parado - pode ser fila em semáforo
            if closest_distance >= min_distance * 0.5:  # Metade da distância mínima
                return True, ""  # Pode spawnar em fila
            else:
                return False, f"Too close to stopped car ({closest_distance:.1f}m)"
        else:
            # Carro em movimento - esperar passar
            return False, f"Car moving too close ({closest_distance:.1f}m)"
    
    def _spawn_car(self, spawn_point: SpawnPoint, current_time: float) -> Car:
        """Cria novo carro no ponto de spawn."""
        # Escolher personalidade baseada em distribuição realística
        personality = self._choose_personality()
        
        # Criar carro
        car = Car(
            direction=spawn_point.direction,
            lane=spawn_point.lane,
            personality=personality
        )
        
        return car
    
    def _choose_personality(self) -> DriverPersonality:
        """Escolhe personalidade do motorista baseada em distribuição realística."""
        personalities = list(DriverPersonality)
        
        # Distribuição mais realística
        weights = [
            0.15,  # AGGRESSIVE - 15%
            0.25,  # CONSERVATIVE - 25%  
            0.50,  # NORMAL - 50%
            0.10,  # ELDERLY - 10%
        ]
        
        return random.choices(personalities, weights=weights)[0]
    
    def _update_debug_info(self, current_time: float):
        """Atualiza informações de debug."""
        self.debug_info = {
            'total_spawned': self.total_cars_spawned,
            'spawn_rate_multiplier': {
                'main_road': self.main_road_multiplier,
                'cross_road': self.cross_road_multiplier,
                'rush_hour': self.rush_hour_multiplier,
            },
            'traffic_density': dict(self.traffic_density),
            'spawn_points': [point.get_stats() for point in self.spawn_points],
            'active_spawn_points': len([p for p in self.spawn_points if not p.is_blocked]),
        }
    
    def choose_best_lane(self, direction: Direction) -> int:
        """
        Escolhe melhor faixa para spawn baseada na densidade.
        Reimplementação da lógica do protótipo HTML.
        """
        max_lanes = 1 if direction == Direction.TOP_TO_BOTTOM else 2
        
        # Encontrar spawn points relevantes
        relevant_points = [
            p for p in self.spawn_points 
            if p.direction == direction
        ]
        
        if not relevant_points:
            return 0
        
        # Escolher ponto menos congestionado
        best_point = min(relevant_points, key=lambda p: p.blocked_attempts)
        return best_point.lane
    
    def set_spawn_rate(self, rate: float):
        """Define taxa de spawn manual."""
        self.base_spawn_rate = max(0.0, min(1.0, rate))
    
    def enable_rush_hour(self, enabled: bool):
        """Habilita/desabilita modo rush hour."""
        if enabled:
            self.rush_hour_multiplier = SPAWN_CONFIG['rush_hour_multiplier']
        else:
            self.rush_hour_multiplier = 1.0
    
    def pause(self):
        """Pausa sistema de spawn."""
        self.is_active = False
    
    def resume(self):
        """Resume sistema de spawn."""
        self.is_active = True
    
    def reset_statistics(self):
        """Reseta estatísticas de spawn."""
        self.total_cars_spawned = 0
        for point in self.spawn_points:
            point.cars_spawned = 0
            point.spawn_attempts = 0
            point.blocked_attempts = 0
    
    def get_statistics(self) -> Dict[str, Any]:
        """Retorna estatísticas completas do sistema."""
        total_attempts = sum(p.spawn_attempts for p in self.spawn_points)
        total_blocked = sum(p.blocked_attempts for p in self.spawn_points)
        
        success_rate = 0.0
        if total_attempts > 0:
            success_rate = (total_attempts - total_blocked) / total_attempts
        
        return {
            'total_cars_spawned': self.total_cars_spawned,
            'total_attempts': total_attempts,
            'total_blocked': total_blocked,
            'success_rate': success_rate,
            'spawn_points': len(self.spawn_points),
            'active_points': len([p for p in self.spawn_points if not p.is_blocked]),
            'current_multipliers': {
                'main_road': self.main_road_multiplier,
                'cross_road': self.cross_road_multiplier,
                'rush_hour': self.rush_hour_multiplier,
            },
            'traffic_density': dict(self.traffic_density),
        }
    
    def get_debug_info(self) -> Dict[str, Any]:
        """Retorna informações de debug."""
        return self.debug_info