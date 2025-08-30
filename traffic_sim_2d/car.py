from enum import Enum
import random
import pygame
import time
import math
from config import *

class Direction(Enum):
    LEFT_TO_RIGHT = 0
    RIGHT_TO_LEFT = 1
    BOTTOM_TO_TOP = 2

class DriverPersonality(Enum):
    AGGRESSIVE = "aggressive"
    CONSERVATIVE = "conservative"
    NORMAL = "normal"
    ELDERLY = "elderly"

class CarState(Enum):
    DRIVING = "driving"
    STOPPING = "stopping"
    WAITING = "waiting"
    ACCELERATING = "accelerating"

class Car:
    def __init__(self, direction, lane):
        # Propriedades físicas
        self.width = CAR_CONFIG['width']
        self.height = CAR_CONFIG['height']
        self.direction = direction
        self.lane = lane
        
        # Posição inicial baseada na direção (EXATO como desenvolvemos)
        self.x, self.y = self._get_spawn_position()
        
        # IA e Personalidade (EXATO como desenvolvemos)
        self.personality = random.choice(list(DriverPersonality))
        self.reaction_time = self._get_reaction_time()
        self.following_distance_factor = self._get_following_distance()
        self.aggression_level = self._get_aggression()
        
        # Física (valores EXATOS que desenvolvemos)
        self.current_speed = 0
        self.max_speed = CAR_CONFIG['max_speed'] + random.uniform(-0.2, 0.2)  # Variação ±20%
        self.acceleration = CAR_CONFIG['acceleration']
        self.deceleration = CAR_CONFIG['deceleration']
        
        # Estado atual
        self.state = CarState.DRIVING
        self.should_stop = False
        self.has_passed_intersection = False
        
        # Estatísticas
        self.spawn_time = time.time()
        self.total_wait_time = 0
        
        # Visual
        self.color = random.choice(CAR_COLORS)
    
    def _get_spawn_position(self):
        """Posições EXATAS baseadas no sistema desenvolvido"""
        if self.direction == Direction.LEFT_TO_RIGHT:
            x = -30  # Fora da tela à esquerda
            y = 370 + (self.lane * 35)  # Faixas: 370, 405
        elif self.direction == Direction.RIGHT_TO_LEFT:
            x = WINDOW_WIDTH + 30  # Fora da tela à direita
            y = 430 - (self.lane * 35)  # Faixas: 430, 395
        elif self.direction == Direction.BOTTOM_TO_TOP:
            x = 580  # Centralizado na rua de mão única
            y = WINDOW_HEIGHT + 30  # Fora da tela EMBAIXO
        
        return x, y
    
    def _get_reaction_time(self):
        """Tempos de reação baseados na personalidade (EXATO)"""
        config = DRIVER_PERSONALITIES[self.personality.value.upper()]
        return random.uniform(*config['reaction_time'])
    
    def _get_following_distance(self):
        """Fatores de distância por personalidade (EXATO)"""
        config = DRIVER_PERSONALITIES[self.personality.value.upper()]
        return config['following_distance_factor']
    
    def _get_aggression(self):
        """Nível de agressividade (EXATO)"""
        config = DRIVER_PERSONALITIES[self.personality.value.upper()]
        return config['aggression_level']
    
    def update(self, all_cars, traffic_lights):
        """Atualização principal do carro - LÓGICA EXATA"""
        # Verificar obstáculos (prioridade: carro > semáforo)
        self.check_obstacles(all_cars, traffic_lights)
        
        # Atualizar física
        self._update_physics()
        
        # Mover
        self._move()
        
        # Atualizar estado
        self._update_state()
    
    def check_obstacles(self, all_cars, traffic_lights):
        """Algoritmo EXATO de detecção que desenvolvemos"""
        self.should_stop = False
        
        # PRIORIDADE 1: Carros à frente (CRUCIAL)
        car_ahead = self._get_car_ahead(all_cars)
        if car_ahead:
            distance = self._calculate_distance_to_car(car_ahead)
            min_distance = CAR_CONFIG['min_following_distance'] * self.following_distance_factor
            
            if distance <= min_distance:
                self.should_stop = True
                return  # Se há carro na frente, NÃO verificar semáforo
        
        # PRIORIDADE 2: Semáforos (SÓ se não há carro na frente)
        if not self.has_passed_intersection:
            distance_to_intersection = self._get_distance_to_intersection()
            should_stop_at_light = self._should_stop_at_traffic_light(traffic_lights)
            
            # REGRA CRUCIAL: Só parar se conseguir parar ANTES da intersecção
            if (should_stop_at_light and 
                distance_to_intersection > CAR_CONFIG['minimum_stop_distance']):
                self.should_stop = True
        
        # Marcar se passou da intersecção
        if self._has_passed_intersection():
            self.has_passed_intersection = True
    
    def _get_car_ahead(self, all_cars):
        """Encontrar carro à frente na mesma faixa"""
        cars_ahead = []
        
        for car in all_cars:
            if car == self:
                continue
            
            # Deve estar na mesma direção e faixa
            if car.direction != self.direction or car.lane != self.lane:
                continue
            
            # Deve estar à frente
            if self._is_car_ahead(car):
                distance = self._calculate_distance_to_car(car)
                cars_ahead.append((car, distance))
        
        # Retornar o mais próximo
        if cars_ahead:
            cars_ahead.sort(key=lambda x: x[1])
            return cars_ahead[0][0]
        
        return None
    
    def _is_car_ahead(self, other_car):
        """Verificar se outro carro está à frente"""
        if self.direction == Direction.LEFT_TO_RIGHT:
            return other_car.x > self.x
        elif self.direction == Direction.RIGHT_TO_LEFT:
            return other_car.x < self.x
        elif self.direction == Direction.BOTTOM_TO_TOP:
            return other_car.y < self.y  # À frente = Y menor (indo para cima)
        
        return False
    
    def _calculate_distance_to_car(self, other_car):
        """Calcular distância até outro carro"""
        if self.direction == Direction.LEFT_TO_RIGHT:
            return abs(other_car.x - self.x)
        elif self.direction == Direction.RIGHT_TO_LEFT:
            return abs(self.x - other_car.x)
        elif self.direction == Direction.BOTTOM_TO_TOP:
            return abs(self.y - other_car.y)  # Distância para carro à frente (Y menor)
        
        return 0
    
    def _get_distance_to_intersection(self):
        """Calcular distância até a intersecção"""
        if self.direction == Direction.LEFT_TO_RIGHT:
            return abs(520 - self.x)  # Centro da intersecção
        elif self.direction == Direction.RIGHT_TO_LEFT:
            return abs(self.x - 680)  # Centro da intersecção
        elif self.direction == Direction.BOTTOM_TO_TOP:
            return abs(self.y - 420)  # Distância até centro da intersecção (indo para cima)
        
        return 0
    
    def _should_stop_at_traffic_light(self, traffic_lights):
        """Lógica de parada no semáforo (NOSSA LÓGICA EXATA)"""
        relevant_light_state = self._get_relevant_light_state(traffic_lights)
        
        if relevant_light_state == "red":
            return True
        elif relevant_light_state == "yellow":
            # Decisão baseada na distância + personalidade (EXATO)
            distance = self._get_distance_to_intersection()
            return distance > 300  # Só para no amarelo se está longe
        
        return False
    
    def _get_relevant_light_state(self, traffic_lights):
        """Obter estado do semáforo relevante para esta direção"""
        if self.direction in [Direction.LEFT_TO_RIGHT, Direction.RIGHT_TO_LEFT]:
            return traffic_lights.main_road_state
        else:
            return traffic_lights.cross_road_state
    
    def _has_passed_intersection(self):
        """Verificar se passou da intersecção"""
        if self.direction == Direction.LEFT_TO_RIGHT:
            return self.x > 720
        elif self.direction == Direction.RIGHT_TO_LEFT:
            return self.x < 480
        elif self.direction == Direction.BOTTOM_TO_TOP:
            return self.y < 300  # Passou da intersecção (indo para cima)
        
        return False
    
    def _update_physics(self):
        """Atualizar física do movimento"""
        if self.should_stop:
            # Desacelerar
            self.current_speed = max(0, self.current_speed - self.deceleration)
            self.state = CarState.STOPPING if self.current_speed > 0 else CarState.WAITING
        else:
            # Acelerar até velocidade máxima
            if self.current_speed < self.max_speed:
                self.current_speed = min(self.max_speed, self.current_speed + self.acceleration)
                self.state = CarState.ACCELERATING
            else:
                self.state = CarState.DRIVING
    
    def _move(self):
        """Mover o carro baseado na velocidade atual"""
        if self.direction == Direction.LEFT_TO_RIGHT:
            self.x += self.current_speed
        elif self.direction == Direction.RIGHT_TO_LEFT:
            self.x -= self.current_speed
        elif self.direction == Direction.BOTTOM_TO_TOP:
            self.y -= self.current_speed  # Move para CIMA (Y diminui)
    
    def _update_state(self):
        """Atualizar estatísticas"""
        if self.state == CarState.WAITING:
            self.total_wait_time += 1/60  # Assumindo 60 FPS
    
    def is_out_of_bounds(self):
        """Verificar se saiu da tela"""
        if self.direction == Direction.LEFT_TO_RIGHT:
            return self.x > WINDOW_WIDTH + 50
        elif self.direction == Direction.RIGHT_TO_LEFT:
            return self.x < -50
        elif self.direction == Direction.BOTTOM_TO_TOP:
            return self.y < -50  # Saiu pela parte de cima da tela
        
        return False
    
    def draw(self, screen):
        """Desenhar o carro na tela"""
        # Corpo do carro
        pygame.draw.rect(screen, self.color, (self.x, self.y, self.width, self.height))
        
        # Janelas (retângulo menor e mais escuro)
        pygame.draw.rect(screen, (30, 30, 30), 
                        (self.x + 3, self.y + 2, self.width - 6, self.height - 4))
        
        # Indicador de personalidade (pequeno retângulo colorido)
        personality_colors = {
            DriverPersonality.AGGRESSIVE: (255, 0, 0),
            DriverPersonality.NORMAL: (0, 255, 0),
            DriverPersonality.CONSERVATIVE: (0, 0, 255),
            DriverPersonality.ELDERLY: (255, 255, 0)
        }
        
        color = personality_colors[self.personality]
        pygame.draw.rect(screen, color, (self.x, self.y - 5, 5, 3))