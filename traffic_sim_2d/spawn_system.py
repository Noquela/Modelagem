import random
import time
from car import Car, Direction
from config import *

class SpawnSystem:
    def __init__(self):
        # Configurações EXATAS que desenvolvemos
        self.base_spawn_rate = SPAWN_CONFIG['base_spawn_rate']
        self.randomness_factor = SPAWN_CONFIG['randomness_factor']
        self.min_distance = SPAWN_CONFIG['min_spawn_distance']
        self.cross_road_multiplier = SPAWN_CONFIG['cross_road_multiplier']
        
        # Estatísticas
        self.cars_spawned = 0
        self.spawn_attempts = 0
        
        # Para controle de timing
        self.last_spawn_time = {
            Direction.LEFT_TO_RIGHT: 0,
            Direction.RIGHT_TO_LEFT: 0,
            Direction.TOP_TO_BOTTOM: 0
        }
    
    def update(self, cars):
        """Sistema de spawn EXATO baseado no que desenvolvemos"""
        new_cars = []
        current_time = time.time()
        
        # Fator aleatório para variar spawn rate
        random_factor = 0.5 + random.random() * self.randomness_factor  # 0.5 a 1.0
        
        # Spawn rua principal (esquerda→direita)
        if self._should_spawn(Direction.LEFT_TO_RIGHT, current_time, random_factor):
            lane = self._choose_best_lane(Direction.LEFT_TO_RIGHT, cars)
            if lane != -1 and self._can_spawn_safely(Direction.LEFT_TO_RIGHT, lane, cars):
                new_car = Car(Direction.LEFT_TO_RIGHT, lane)
                new_cars.append(new_car)
                self.cars_spawned += 1
                self.last_spawn_time[Direction.LEFT_TO_RIGHT] = current_time
        
        # Spawn rua principal (direita→esquerda)
        if self._should_spawn(Direction.RIGHT_TO_LEFT, current_time, random_factor):
            lane = self._choose_best_lane(Direction.RIGHT_TO_LEFT, cars)
            if lane != -1 and self._can_spawn_safely(Direction.RIGHT_TO_LEFT, lane, cars):
                new_car = Car(Direction.RIGHT_TO_LEFT, lane)
                new_cars.append(new_car)
                self.cars_spawned += 1
                self.last_spawn_time[Direction.RIGHT_TO_LEFT] = current_time
        
        # Spawn rua que corta (cima→baixo) - 80% da chance das outras
        if self._should_spawn(Direction.TOP_TO_BOTTOM, current_time, 
                             random_factor * self.cross_road_multiplier):
            if self._can_spawn_safely(Direction.TOP_TO_BOTTOM, 0, cars):
                new_car = Car(Direction.TOP_TO_BOTTOM, 0)
                new_cars.append(new_car)
                self.cars_spawned += 1
                self.last_spawn_time[Direction.TOP_TO_BOTTOM] = current_time
        
        self.spawn_attempts += 1
        return new_cars
    
    def _should_spawn(self, direction, current_time, rate_factor):
        """Verificar se deve spawnar baseado na taxa e timing"""
        # Evitar spam de spawn - mínimo 1 segundo entre spawns
        if current_time - self.last_spawn_time[direction] < 1.0:
            return False
        
        # Chance baseada na taxa configurada
        spawn_chance = self.base_spawn_rate * rate_factor
        return random.random() < spawn_chance
    
    def _choose_best_lane(self, direction, cars):
        """Escolher faixa menos congestionada (NOSSA LÓGICA)"""
        max_lanes = 2 if direction != Direction.TOP_TO_BOTTOM else 1
        
        # Encontrar faixa com mais espaço
        best_lane = -1
        max_distance = 0
        
        for lane in range(max_lanes):
            distance = self._get_distance_to_nearest_car(direction, lane, cars)
            if distance >= self.min_distance and distance > max_distance:
                max_distance = distance
                best_lane = lane
        
        # Se nenhuma tem espaço ideal, escolher menos ocupada
        if best_lane == -1:
            lane_counts = [self._count_cars_in_lane(direction, lane, cars) for lane in range(max_lanes)]
            if lane_counts:
                best_lane = lane_counts.index(min(lane_counts))
            else:
                best_lane = 0
        
        return best_lane
    
    def _can_spawn_safely(self, direction, lane, cars):
        """Verificar se pode spawnar com segurança (LÓGICA CRUCIAL)"""
        # Sempre permitir spawn para formar fila (mesmo no vermelho)
        # Apenas verificar se há espaço físico
        
        distance_to_nearest = self._get_distance_to_nearest_car(direction, lane, cars)
        return distance_to_nearest >= self.min_distance
    
    def _get_distance_to_nearest_car(self, direction, lane, cars):
        """Calcular distância até o carro mais próximo na faixa"""
        cars_in_lane = [car for car in cars 
                       if car.direction == direction and car.lane == lane]
        
        if not cars_in_lane:
            return float('inf')  # Faixa vazia
        
        # Encontrar carro mais próximo do ponto de spawn
        min_distance = float('inf')
        
        for car in cars_in_lane:
            distance = self._calculate_distance_to_spawn(car)
            if distance >= 0:  # Apenas carros que ainda não passaram do spawn
                min_distance = min(min_distance, distance)
        
        return min_distance if min_distance != float('inf') else float('inf')
    
    def _calculate_distance_to_spawn(self, car):
        """Calcular distância do carro até o ponto de spawn"""
        if car.direction == Direction.LEFT_TO_RIGHT:
            # Spawn à esquerda (-30), distância até o carro
            return car.x - (-30)
        elif car.direction == Direction.RIGHT_TO_LEFT:
            # Spawn à direita (WINDOW_WIDTH + 30), distância até o carro
            return (WINDOW_WIDTH + 30) - car.x
        elif car.direction == Direction.TOP_TO_BOTTOM:
            # Spawn em cima (-30), distância até o carro
            return car.y - (-30)
        
        return 0
    
    def _count_cars_in_lane(self, direction, lane, cars):
        """Contar carros em uma faixa específica"""
        return len([car for car in cars 
                   if car.direction == direction and car.lane == lane])
    
    def get_statistics(self):
        """Retornar estatísticas do sistema de spawn"""
        return {
            'cars_spawned': self.cars_spawned,
            'spawn_attempts': self.spawn_attempts,
            'spawn_success_rate': (self.cars_spawned / max(1, self.spawn_attempts)) * 100,
            'last_spawn_times': dict(self.last_spawn_time)
        }