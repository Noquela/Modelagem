"""
Gerenciador de Tráfego - Veículos e Pedestres
============================================

Sistema completo de simulação de tráfego com:
- Modelo IDM para seguimento veicular
- Spawning inteligente com pooling
- Detecção de colisão 3D
- Pedestres com comportamento realístico
"""

import random
import math
from typing import List, Dict, Optional
from scene.types import Pos3, Colors, AABB, Transform3D

class Vehicle:
    """Veículo com modelo IDM de seguimento"""
    
    def __init__(self, spawn_pos: Pos3, direction: str, lane_id: int):
        self.position = spawn_pos
        self.direction = direction  # 'north', 'south', 'east', 'west'
        self.lane_id = lane_id
        
        # Parâmetros IDM
        self.desired_speed = random.uniform(12.0, 16.0)  # m/s (~43-58 km/h)
        self.min_spacing = 3.0  # s0
        self.time_headway = 1.2  # T
        self.max_acceleration = 1.5  # a
        self.comfortable_deceleration = 2.5  # b
        
        # Estado atual
        self.speed = 0.0
        self.acceleration = 0.0
        self.waiting = False
        self.wait_time = 0.0
        self.completed = False
        
        # Visual
        self.color = random.choice(Colors.CAR_COLORS).as_tuple()
        self.size = Pos3(2.0, 1.0, 0.8)
        
        # Estatísticas
        self.spawn_time = 0.0
        self.total_wait_time = 0.0
    
    def update(self, dt: float, signal_state: dict, leader_vehicle=None):
        """Atualiza veículo usando modelo IDM"""
        if self.completed:
            return
        
        # Calcular aceleração IDM
        acceleration = self._calculate_idm_acceleration(leader_vehicle)
        
        # Verificar semáforo
        distance_to_signal = self._distance_to_signal()
        
        if self._should_stop_for_signal(signal_state, distance_to_signal):
            # Aplicar frenagem para semáforo
            signal_deceleration = self._calculate_signal_deceleration(distance_to_signal)
            acceleration = min(acceleration, signal_deceleration)
            
            if not self.waiting and self.speed < 0.1:
                self.waiting = True
        else:
            if self.waiting and self.speed > 0.1:
                self.waiting = False
        
        # Atualizar estado
        if self.waiting:
            self.wait_time += dt
            self.total_wait_time += dt
        
        # Integração numérica
        self.speed = max(0.0, self.speed + acceleration * dt)
        self.acceleration = acceleration
        
        # Mover veículo
        self._move(dt)
        
        # Verificar se completou travessia
        self._check_completion()
    
    def _calculate_idm_acceleration(self, leader=None):
        """Calcula aceleração usando modelo IDM"""
        if leader is None:
            # Aceleração livre
            return self.max_acceleration * (1 - (self.speed / self.desired_speed)**4)
        
        # Distância e velocidade relativa
        distance = self._distance_to_leader(leader)
        relative_speed = self.speed - leader.speed
        
        # Espaçamento desejado
        desired_spacing = (self.min_spacing + 
                          max(0, self.speed * self.time_headway +
                              (self.speed * relative_speed) / 
                              (2 * math.sqrt(self.max_acceleration * self.comfortable_deceleration))))
        
        # Aceleração IDM
        free_road_term = (self.speed / self.desired_speed)**4
        interaction_term = (desired_spacing / max(distance, 0.1))**2
        
        return self.max_acceleration * (1 - free_road_term - interaction_term)
    
    def _distance_to_leader(self, leader):
        """Calcula distância até o veículo líder"""
        if self.direction == 'north':
            return leader.position.y - self.position.y - leader.size.x
        elif self.direction == 'south':
            return self.position.y - leader.position.y - leader.size.x
        elif self.direction == 'east':
            return leader.position.x - self.position.x - leader.size.y
        else:  # west
            return self.position.x - leader.position.x - leader.size.y
    
    def _distance_to_signal(self):
        """Calcula distância até o semáforo"""
        if self.direction == 'north':
            return 12.0 - self.position.y  # Posição aproximada do semáforo
        elif self.direction == 'south':
            return self.position.y + 12.0
        elif self.direction == 'east':
            return 12.0 - self.position.x
        else:  # west
            return self.position.x + 12.0
    
    def _should_stop_for_signal(self, signal_state: dict, distance: float):
        """Verifica se deve parar pelo semáforo"""
        if distance < 0:  # Já passou
            return False
        
        phase = signal_state.get('phase', 'red')
        
        if phase == 'red':
            return distance < 15.0
        elif phase == 'yellow':
            # Decisão baseada em tempo e distância
            time_remaining = signal_state.get('time_remaining', 0)
            time_to_reach = distance / max(self.speed, 0.1)
            
            # Para se não conseguir passar ou se muito longe
            return time_to_reach > time_remaining or distance > 25.0
        
        return False  # Verde
    
    def _calculate_signal_deceleration(self, distance):
        """Calcula desaceleração necessária para parar no semáforo"""
        if distance <= 0 or self.speed <= 0:
            return -self.comfortable_deceleration
        
        # Usar equação cinemática: v² = u² + 2as
        # Para parar: 0 = v² + 2as -> a = -v²/(2s)
        required_decel = -(self.speed**2) / (2 * distance)
        return max(required_decel, -self.comfortable_deceleration * 1.5)
    
    def _move(self, dt: float):
        """Move o veículo na direção apropriada"""
        distance = self.speed * dt
        
        if self.direction == 'north':
            self.position.y += distance
        elif self.direction == 'south':
            self.position.y -= distance
        elif self.direction == 'east':
            self.position.x += distance
        else:  # west
            self.position.x -= distance
    
    def _check_completion(self):
        """Verifica se completou a travessia"""
        if (abs(self.position.x) > 60 or abs(self.position.y) > 60):
            self.completed = True
    
    def get_transform(self):
        """Retorna transformação para renderização"""
        rotation = Pos3(0, 0, 0)
        if self.direction == 'north':
            rotation.z = 0
        elif self.direction == 'south':
            rotation.z = 180
        elif self.direction == 'east':
            rotation.z = -90
        else:  # west
            rotation.z = 90
        
        return Transform3D(
            position=Pos3(self.position.x, self.position.y, self.size.z/2 + 0.2),
            rotation=rotation,
            scale=self.size
        )
    
    def get_aabb(self):
        """Retorna bounding box do veículo"""
        return AABB.from_center_size(self.position, self.size)

class Pedestrian:
    """Pedestre com comportamento realístico"""
    
    def __init__(self, start_pos: Pos3, end_pos: Pos3, crossing_type: str):
        self.start_position = start_pos
        self.position = start_pos
        self.end_position = end_pos
        self.crossing_type = crossing_type  # 'horizontal' ou 'vertical'
        
        # Parâmetros
        self.walking_speed = random.uniform(1.2, 1.6)  # m/s
        self.size = Pos3(0.3, 0.3, 1.7)
        self.color = random.choice([
            (0.8, 0.4, 0.2), (0.2, 0.6, 0.8), (0.6, 0.2, 0.8),
            (0.8, 0.6, 0.2), (0.2, 0.8, 0.4)
        ])
        
        # Estado
        self.waiting = True
        self.crossing = False
        self.completed = False
        self.wait_time = 0.0
        
        # Grupo (30% chance de estar em grupo)
        self.in_group = random.random() < 0.3
        self.group_leader = True
    
    def update(self, dt: float, signal_can_cross: bool):
        """Atualiza comportamento do pedestre"""
        if self.completed:
            return
        
        if self.waiting:
            self.wait_time += dt
            
            if signal_can_cross:
                self.waiting = False
                self.crossing = True
        
        elif self.crossing:
            # Mover em direção ao destino
            direction = self.end_position - self.position
            distance = math.sqrt(direction.x**2 + direction.y**2)
            
            if distance < 0.5:
                self.completed = True
                return
            
            # Normalizar direção e mover
            if distance > 0:
                direction = direction * (1.0 / distance)
                movement = direction * (self.walking_speed * dt)
                
                self.position = self.position + movement
    
    def request_crossing(self) -> bool:
        """Retorna se quer atravessar (probabilístico)"""
        if self.waiting:
            return random.random() < 0.01  # 1% chance por frame
        return False
    
    def get_transform(self):
        """Retorna transformação para renderização"""
        return Transform3D(
            position=Pos3(self.position.x, self.position.y, self.size.z/2 + 0.3),
            scale=self.size
        )

class Lane:
    """Faixa de tráfego com gerenciamento de veículos"""
    
    def __init__(self, direction: str, lane_id: int, spawn_pos: Pos3):
        self.direction = direction
        self.lane_id = lane_id
        self.spawn_position = spawn_pos
        self.vehicles: List[Vehicle] = []
        
        # Pool de objetos para otimização
        self.vehicle_pool: List[Vehicle] = []
        self.max_pool_size = 50
        
        # Estatísticas
        self.vehicles_spawned = 0
        self.vehicles_completed = 0
        self.total_wait_time = 0.0
        self.max_queue_length = 0
    
    def update(self, dt: float, signal_state: dict, spawn_rate: float):
        """Atualiza faixa e todos os veículos"""
        # Tentar spawnar novo veículo
        if random.random() < spawn_rate * dt:
            self._spawn_vehicle()
        
        # Atualizar veículos existentes
        for i in range(len(self.vehicles) - 1, -1, -1):
            vehicle = self.vehicles[i]
            
            # Encontrar veículo líder
            leader = self.vehicles[i-1] if i > 0 else None
            
            # Atualizar veículo
            vehicle.update(dt, signal_state, leader)
            
            # Remover se completou
            if vehicle.completed:
                self.total_wait_time += vehicle.total_wait_time
                self.vehicles_completed += 1
                self._return_vehicle_to_pool(vehicle)
                self.vehicles.pop(i)
        
        # Atualizar estatísticas
        current_queue = sum(1 for v in self.vehicles if v.waiting)
        self.max_queue_length = max(self.max_queue_length, len(self.vehicles))
    
    def _spawn_vehicle(self):
        """Spawna novo veículo se houver espaço"""
        if not self._can_spawn():
            return
        
        # Usar veículo do pool ou criar novo
        if self.vehicle_pool:
            vehicle = self.vehicle_pool.pop()
            vehicle._reset(self.spawn_position, self.direction, self.lane_id)
        else:
            vehicle = Vehicle(self.spawn_position, self.direction, self.lane_id)
        
        self.vehicles.append(vehicle)
        self.vehicles_spawned += 1
    
    def _can_spawn(self):
        """Verifica se pode spawnar veículo"""
        if not self.vehicles:
            return True
        
        last_vehicle = self.vehicles[-1]
        distance = self._distance_from_spawn(last_vehicle)
        
        return distance > 8.0  # Distância mínima de segurança
    
    def _distance_from_spawn(self, vehicle):
        """Calcula distância do spawn até o veículo"""
        if self.direction == 'north':
            return vehicle.position.y - self.spawn_position.y
        elif self.direction == 'south':
            return self.spawn_position.y - vehicle.position.y
        elif self.direction == 'east':
            return vehicle.position.x - self.spawn_position.x
        else:  # west
            return self.spawn_position.x - vehicle.position.x
    
    def _return_vehicle_to_pool(self, vehicle):
        """Retorna veículo ao pool para reuso"""
        if len(self.vehicle_pool) < self.max_pool_size:
            vehicle._reset_for_pool()
            self.vehicle_pool.append(vehicle)
    
    def get_statistics(self):
        """Retorna estatísticas da faixa"""
        return {
            'spawned': self.vehicles_spawned,
            'completed': self.vehicles_completed,
            'current_count': len(self.vehicles),
            'waiting_count': sum(1 for v in self.vehicles if v.waiting),
            'max_queue': self.max_queue_length,
            'total_wait_time': self.total_wait_time
        }

class TrafficManager:
    """Gerenciador principal de tráfego"""
    
    def __init__(self, intersection_controller):
        self.intersection = intersection_controller
        
        # Faixas de tráfego
        self.lanes = self._create_lanes()
        
        # Pedestres
        self.pedestrians: List[Pedestrian] = []
        self.pedestrian_pool: List[Pedestrian] = []
        
        # Configurações de spawn
        self.car_spawn_rate = 0.3  # carros por segundo por faixa
        self.pedestrian_spawn_rate = 0.1  # pedestres por segundo
        
        print("Gerenciador de tráfego inicializado")
    
    def _create_lanes(self):
        """Cria todas as faixas de tráfego"""
        lanes = {}
        
        # Posições de spawn (fora da área visível)
        spawn_positions = {
            'north_1': Pos3(-3.5, -50, 0.2),
            'north_2': Pos3(0, -50, 0.2),
            'south_1': Pos3(3.5, 50, 0.2),
            'south_2': Pos3(0, 50, 0.2),
            'east_1': Pos3(-50, -3.5, 0.2),
            'east_2': Pos3(-50, 0, 0.2),
            'west_1': Pos3(50, 3.5, 0.2),
            'west_2': Pos3(50, 0, 0.2),
        }
        
        for lane_id, spawn_pos in spawn_positions.items():
            direction = lane_id.split('_')[0]
            lane_num = int(lane_id.split('_')[1])
            lanes[lane_id] = Lane(direction, lane_num, spawn_pos)
        
        return lanes
    
    def update(self, dt: float):
        """Atualiza todo o sistema de tráfego"""
        signal_states = self.intersection.get_signal_states()
        
        # Atualizar faixas de veículos
        for lane_id, lane in self.lanes.items():
            signal_state = signal_states.get(lane_id, {})
            lane.update(dt, signal_state, self.car_spawn_rate)
        
        # Spawnar pedestres
        self._update_pedestrians(dt, signal_states)
        
        # Fornecer dados de tráfego para os semáforos
        self._update_signal_detection()
    
    def _update_pedestrians(self, dt: float, signal_states: dict):
        """Atualiza sistema de pedestres"""
        # Spawnar novos pedestres
        if random.random() < self.pedestrian_spawn_rate * dt:
            self._spawn_pedestrian()
        
        # Atualizar pedestres existentes
        for i in range(len(self.pedestrians) - 1, -1, -1):
            ped = self.pedestrians[i]
            
            # Determinar semáforo apropriado
            signal_key = self._get_pedestrian_signal_key(ped)
            signal_state = signal_states.get(signal_key, {})
            can_cross = signal_state.get('phase') == 'walk'
            
            # Solicitar travessia ocasionalmente
            if ped.request_crossing():
                self.intersection.pedestrian_signals[signal_key].request_crossing()
            
            ped.update(dt, can_cross)
            
            # Remover se completou
            if ped.completed:
                self.pedestrians.pop(i)
    
    def _spawn_pedestrian(self):
        """Spawna novo pedestre"""
        # Escolher travessia aleatória
        crossings = [
            (Pos3(-15, -3, 0.3), Pos3(15, -3, 0.3), 'horizontal'),
            (Pos3(15, 3, 0.3), Pos3(-15, 3, 0.3), 'horizontal'),
            (Pos3(-3, -15, 0.3), Pos3(-3, 15, 0.3), 'vertical'),
            (Pos3(3, 15, 0.3), Pos3(3, -15, 0.3), 'vertical'),
        ]
        
        start, end, crossing_type = random.choice(crossings)
        ped = Pedestrian(start, end, crossing_type)
        self.pedestrians.append(ped)
    
    def _get_pedestrian_signal_key(self, pedestrian):
        """Retorna chave do semáforo apropriado para o pedestre"""
        if pedestrian.crossing_type == 'horizontal':
            if pedestrian.position.y < 0:
                return 'north_crossing'
            else:
                return 'south_crossing'
        else:  # vertical
            if pedestrian.position.x < 0:
                return 'west_crossing'
            else:
                return 'east_crossing'
    
    def _update_signal_detection(self):
        """Atualiza detecção de veículos para os semáforos"""
        for lane_id, lane in self.lanes.items():
            if lane_id in self.intersection.vehicle_signals:
                signal = self.intersection.vehicle_signals[lane_id]
                
                # Contar veículos na fila (esperando)
                signal.queue_length = sum(1 for v in lane.vehicles if v.waiting)
                
                # Contar veículos se aproximando
                approaching = sum(1 for v in lane.vehicles 
                                if not v.waiting and self._is_approaching_signal(v))
                signal.vehicles_detected = approaching
    
    def _is_approaching_signal(self, vehicle, detection_distance=30.0):
        """Verifica se veículo está se aproximando do semáforo"""
        distance = vehicle._distance_to_signal()
        return 0 < distance < detection_distance
    
    def render(self, renderer):
        """Renderiza todos os elementos de tráfego"""
        # Renderizar veículos
        for lane in self.lanes.values():
            for vehicle in lane.vehicles:
                if not renderer.is_in_frustum(vehicle.position, 3.0):
                    continue
                
                transform = vehicle.get_transform()
                renderer.draw_mesh('cube',
                                 transform_pos=transform.position,
                                 transform_rot=Pos3(transform.rotation.x, 
                                                   transform.rotation.y, 
                                                   transform.rotation.z),
                                 transform_scale=transform.scale,
                                 color=vehicle.color)
        
        # Renderizar pedestres
        for pedestrian in self.pedestrians:
            if not renderer.is_in_frustum(pedestrian.position, 2.0):
                continue
            
            transform = pedestrian.get_transform()
            renderer.draw_mesh('cylinder',
                             transform_pos=transform.position,
                             transform_scale=transform.scale,
                             color=pedestrian.color)
    
    def set_car_spawn_rate(self, rate: float):
        """Define taxa de spawn de carros"""
        self.car_spawn_rate = max(0.05, min(1.0, rate))
    
    def set_pedestrian_spawn_rate(self, rate: float):
        """Define taxa de spawn de pedestres"""
        self.pedestrian_spawn_rate = max(0.02, min(0.5, rate))
    
    def get_statistics(self):
        """Retorna estatísticas consolidadas"""
        stats = {}
        
        for direction in ['north', 'south', 'east', 'west']:
            direction_stats = {
                'passed': 0,
                'waiting': 0,
                'max_queue': 0,
                'total_wait_time': 0.0
            }
            
            # Consolidar estatísticas das faixas da direção
            for lane_id in [f"{direction}_1", f"{direction}_2"]:
                if lane_id in self.lanes:
                    lane_stats = self.lanes[lane_id].get_statistics()
                    direction_stats['passed'] += lane_stats['completed']
                    direction_stats['waiting'] += lane_stats['waiting_count']
                    direction_stats['max_queue'] = max(direction_stats['max_queue'], 
                                                     lane_stats['max_queue'])
                    direction_stats['total_wait_time'] += lane_stats['total_wait_time']
            
            stats[direction] = direction_stats
        
        return stats
    
    def reset(self):
        """Reinicia o sistema de tráfego"""
        # Limpar veículos
        for lane in self.lanes.values():
            lane.vehicles.clear()
            lane.vehicle_pool.clear()
            lane.vehicles_spawned = 0
            lane.vehicles_completed = 0
            lane.total_wait_time = 0.0
            lane.max_queue_length = 0
        
        # Limpar pedestres
        self.pedestrians.clear()
        self.pedestrian_pool.clear()
        
        print("Sistema de tráfego reiniciado")