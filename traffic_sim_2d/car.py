from enum import Enum
import random
import pygame
import time
import math
from config import *

class Direction(Enum):
    LEFT_TO_RIGHT = 0
    RIGHT_TO_LEFT = 1
    TOP_TO_BOTTOM = 2

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
        """Posições ajustadas para resolução ultrawide centralizada"""
        from config import WINDOW_WIDTH, WINDOW_HEIGHT
        
        # Calcular posições baseadas na intersecção centralizada
        center_y = WINDOW_HEIGHT // 2  # 720
        road_y = center_y - 80  # Posição da rua principal
        center_x = WINDOW_WIDTH // 2  # 1720
        cross_road_x = center_x - 40  # Posição da rua vertical
        
        if self.direction == Direction.LEFT_TO_RIGHT:
            x = -30  # Fora da tela à esquerda
            # Faixas organizadas: lane 0 = externa, lane 1 = interna
            if self.lane == 0:
                y = road_y + 30  # Faixa externa (CORRIGIDO - era 40)
            else:
                y = road_y + 60  # Faixa interna (CORRIGIDO - era 25)
        elif self.direction == Direction.RIGHT_TO_LEFT:
            x = WINDOW_WIDTH + 30  # Fora da tela à direita
            # Faixas organizadas: lane 0 = interna, lane 1 = externa
            if self.lane == 0:
                y = road_y + 100  # Faixa interna (CORRIGIDO - era 105)
            else:
                y = road_y + 130  # Faixa externa (CORRIGIDO - era 135)
        elif self.direction == Direction.TOP_TO_BOTTOM:
            x = cross_road_x + 25  # Centralizado na faixa de descida
            y = -30  # Fora da tela DE CIMA
        
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
        """Algoritmo OTIMIZADO de detecção de obstáculos"""
        self.should_stop = False
        
        # PRIORIDADE 1: Carros à frente - DETECÇÃO INTELIGENTE
        car_ahead = self._get_car_ahead(all_cars)
        if car_ahead:
            distance = self._calculate_distance_to_car(car_ahead)
            safe_distance = self._calculate_safe_following_distance(car_ahead)
            
            # === SISTEMA ANTI-ENGAVETAMENTO OTIMIZADO ===
            relative_speed = self.current_speed - car_ahead.current_speed
            
            if distance <= safe_distance:
                # === ANÁLISE DE RISCO ===
                # Distância crítica (zona de perigo)
                critical_distance = safe_distance * 0.4
                # Distância de alerta (zona de cuidado)
                alert_distance = safe_distance * 0.75
                
                if distance < critical_distance:
                    # PERIGO IMINENTE: parar imediatamente
                    self.should_stop = True
                elif distance < alert_distance and relative_speed > 0.2:
                    # APROXIMAÇÃO PERIGOSA: reduzir velocidade drasticamente
                    self.should_stop = True
                elif relative_speed > 0.4:  # Me aproximando muito rápido
                    # VELOCIDADE PERIGOSA: começar a desacelerar
                    self.should_stop = True
                else:
                    # SITUAÇÃO CONTROLADA: manter velocidade similar ao carro da frente
                    # Apenas desacelerar se realmente necessário
                    if distance < safe_distance * 0.9 and self.current_speed > car_ahead.current_speed:
                        self.should_stop = True
                
                return  # Se há carro na frente, não verificar semáforo
        
        # PRIORIDADE 2: Semáforos - LÓGICA APRIMORADA
        if not self.has_passed_intersection:
            distance_to_intersection = self._get_distance_to_intersection()
            should_stop_at_light = self._should_stop_at_traffic_light(traffic_lights)
            
            # === CÁLCULO DINÂMICO DE DISTÂNCIA DE PARADA ===
            stopping_distance = self._calculate_stopping_distance()
            safety_margin = 20  # Margem de segurança
            minimum_stop_distance = stopping_distance + safety_margin
            
            if should_stop_at_light and distance_to_intersection > minimum_stop_distance:
                self.should_stop = True
        
        # Marcar se passou a intersecção
        if self._has_passed_intersection() and not self.has_passed_intersection:
            self.has_passed_intersection = True
    
    def _calculate_safe_following_distance(self, car_ahead):
        """Calcular distância segura otimizada com anti-engavetamento - CORRIGIDO"""
        
        # === DISTÂNCIAS OTIMIZADAS BASEADAS NO PROTÓTIPO HTML ===
        base_distance = 28        # REDUZIDO de 32 para 28
        queue_distance = 18       # REDUZIDO de 22 para 18  
        max_limit = 65           # REDUZIDO de 80 para 65
        
        # === ANÁLISE DE VELOCIDADE RELATIVA ===
        my_speed = self.current_speed
        ahead_speed = car_ahead.current_speed if car_ahead else 0
        speed_difference = my_speed - ahead_speed
        
        # === DISTÂNCIA BASEADA NO ESTADO ===
        # Se ambos estão praticamente parados (fila)
        if my_speed < 0.15 and ahead_speed < 0.15:
            return queue_distance  # Filas compactas (18px)
        
        # === FATOR DE VELOCIDADE DINÂMICO ===
        # Mais velocidade = mais distância necessária (reduzido)
        speed_factor = (my_speed / self.max_speed) * 12  # REDUZIDO de 15 para 12
        
        # === FATOR DE APROXIMAÇÃO ===
        # Se estou me aproximando rápido, aumentar distância
        approach_factor = 1.0
        if speed_difference > 0.3:  # Me aproximando muito rápido
            approach_factor = 1.3  # REDUZIDO de 1.4 para 1.3
        elif speed_difference > 0.1:  # Me aproximando
            approach_factor = 1.15  # REDUZIDO de 1.2 para 1.15
        
        # === FATOR DE PERSONALIDADE OTIMIZADO ===
        personality_factor = self.following_distance_factor * 8  # REDUZIDO de 10 para 8
        
        # === CÁLCULO FINAL ===
        dynamic_distance = (base_distance + speed_factor + personality_factor) * approach_factor
        
        # Limites de segurança OTIMIZADOS
        return max(min(dynamic_distance, max_limit), queue_distance)  # Entre 18 e 65 pixels
    
    def _calculate_stopping_distance(self):
        """Calcular distância necessária para parar baseada na velocidade atual"""
        if self.current_speed <= 0:
            return 0
        
        # Fórmula física: d = v²/(2*a) + tempo_reação * v
        reaction_distance = self.current_speed * self.reaction_time * 10  # Converter para pixels
        braking_distance = (self.current_speed ** 2) / (2 * self.deceleration * 10)
        
        return reaction_distance + braking_distance
    
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
        elif self.direction == Direction.TOP_TO_BOTTOM:
            return other_car.y > self.y  # À frente = Y maior (indo para baixo)
        
        return False
    
    def _calculate_distance_to_car(self, other_car):
        """Calcular distância até outro carro"""
        if self.direction == Direction.LEFT_TO_RIGHT:
            return abs(other_car.x - self.x)
        elif self.direction == Direction.RIGHT_TO_LEFT:
            return abs(self.x - other_car.x)
        elif self.direction == Direction.TOP_TO_BOTTOM:
            return abs(other_car.y - self.y)  # Distância para carro à frente (Y maior)
        
        return 0
    
    def _get_distance_to_intersection(self):
        """Calcular distância baseada na posição real da intersecção"""
        # Obter posição dinâmica da intersecção
        center_x = WINDOW_WIDTH // 2
        center_y = WINDOW_HEIGHT // 2
        intersection_bounds = {
            'left': center_x - 40,
            'right': center_x + 40, 
            'top': center_y - 80,
            'bottom': center_y + 80
        }
        
        if self.direction == Direction.LEFT_TO_RIGHT:
            return max(0, intersection_bounds['left'] - self.x)
        elif self.direction == Direction.RIGHT_TO_LEFT:
            return max(0, self.x - intersection_bounds['right'])
        elif self.direction == Direction.TOP_TO_BOTTOM:
            return max(0, intersection_bounds['top'] - self.y)
        
        return 0
    
    def _should_stop_at_traffic_light(self, traffic_lights):
        """Lógica EXATA do HTML"""
        relevant_light_state = self._get_relevant_light_state(traffic_lights)
        
        if relevant_light_state == "red":
            return True
        elif relevant_light_state == "yellow":
            # LÓGICA EXATA DO HTML
            distance_to_intersection = self._get_distance_to_intersection()
            return distance_to_intersection > 50  # HTML usa 10, mas em 2D precisa ser maior
        
        return False
    
    def _advanced_yellow_light_decision(self):
        """Decisão mais realística no amarelo baseada em múltiplos fatores"""
        distance_to_intersection = self._get_distance_to_intersection()
        
        # Tempo para parar baseado na velocidade atual
        if self.current_speed > 0:
            stopping_time = self.current_speed / self.deceleration
            stopping_distance = self.current_speed * stopping_time
        else:
            return True  # Se parado, continuar parado
        
        # Fatores de decisão
        factors = {
            'distance_factor': distance_to_intersection / 300,
            'speed_factor': self.current_speed / self.max_speed,
            'personality_factor': self.aggression_level,
            'reaction_factor': 1.0 / self.reaction_time,
            'stopping_ability': stopping_distance / distance_to_intersection if distance_to_intersection > 0 else 1.0
        }
        
        # Algoritmo de decisão ponderado
        decision_score = (
            factors['distance_factor'] * 0.3 +
            factors['speed_factor'] * 0.25 +
            factors['personality_factor'] * 0.25 +
            factors['reaction_factor'] * 0.1 +
            (1.0 - factors['stopping_ability']) * 0.1
        )
        
        # Motoristas agressivos com velocidade alta tendem a continuar
        # Motoristas conservadores com distância segura tendem a parar
        return decision_score > 0.6
    
    def _calculate_adaptive_following_distance(self, car_ahead):
        """Distância adaptativa - MENOR quando parado para formar filas"""
        base_distance = CAR_CONFIG['min_following_distance']
        
        # LÓGICA DE FILA: Distância muito menor quando ambos estão parados
        if self.current_speed < 0.1 and car_ahead and car_ahead.current_speed < 0.1:
            # Na fila: carros podem ficar bem mais próximos
            return 30  # Distância de fila (era 50)
        
        # Ajustes baseados em:
        # - Personalidade
        # - Velocidade relativa
        # - Velocidade atual
        
        personality_mult = self.following_distance_factor
        speed_mult = self.current_speed / self.max_speed  # Mais distância = mais velocidade
        
        # Consideração da velocidade relativa
        relative_speed_factor = 1.0
        if car_ahead and hasattr(car_ahead, 'current_speed'):
            if car_ahead.current_speed < self.current_speed:
                # Se o carro da frente está mais lento, aumentar distância
                relative_speed_factor = 1.2
            elif car_ahead.current_speed > self.current_speed:
                # Se o carro da frente está mais rápido, pode diminuir um pouco
                relative_speed_factor = 0.9
        
        adaptive_distance = base_distance * personality_mult * (0.8 + speed_mult * 0.4) * relative_speed_factor
        
        return max(adaptive_distance, 45)  # Distância mínima reduzida (era 50)
    
    def _get_relevant_light_state(self, traffic_lights):
        """Obter estado do semáforo relevante para esta direção"""
        if self.direction in [Direction.LEFT_TO_RIGHT, Direction.RIGHT_TO_LEFT]:
            return traffic_lights.main_road_state
        else:
            return traffic_lights.cross_road_state
    
    def _has_passed_intersection(self):
        """Verificar dinamicamente se passou da intersecção"""
        center_x = WINDOW_WIDTH // 2
        center_y = WINDOW_HEIGHT // 2
        
        if self.direction == Direction.LEFT_TO_RIGHT:
            return self.x > center_x + 60  # Passou da intersecção
        elif self.direction == Direction.RIGHT_TO_LEFT:
            return self.x < center_x - 60
        elif self.direction == Direction.TOP_TO_BOTTOM:
            return self.y > center_y + 100  # Passou da intersecção
        
        return False
    
    def _update_physics(self):
        """Atualizar física do movimento - SUAVIZADA E REALÍSTICA"""
        
        if self.should_stop:
            # === DESACELERAÇÃO SUAVIZADA ===
            # Desaceleração progressiva baseada na velocidade atual
            speed_factor = self.current_speed / self.max_speed  # 0.0 a 1.0
            
            # Desaceleração mais intensa quando rápido, mais suave quando lento
            dynamic_deceleration = self.deceleration * (0.5 + speed_factor * 0.5)
            
            # Personalidade afeta a desaceleração
            personality_decel_factor = 1.0
            if hasattr(self, 'aggression_level'):
                # Motoristas agressivos freiam mais tarde mas mais forte
                personality_decel_factor = 0.8 + (self.aggression_level * 0.4)
            
            # === APLICAR SUAVIZAÇÃO TAMBÉM NA DESACELERAÇÃO ===
            smooth_factor = CAR_CONFIG.get('smooth_factor', 0.85)
            
            final_deceleration = dynamic_deceleration * personality_decel_factor * smooth_factor
            self.current_speed = max(0, self.current_speed - final_deceleration)
            
            # Estados mais precisos
            if self.current_speed > 0.1:
                self.state = CarState.STOPPING
            else:
                self.current_speed = 0  # Parar completamente
                self.state = CarState.WAITING
                
        else:
            # === ACELERAÇÃO SUAVIZADA ===
            if self.current_speed < self.max_speed:
                # Curva de aceleração realística 
                speed_ratio = self.current_speed / self.max_speed
                
                # Aceleração forte no início, mais fraca próximo da velocidade máxima
                acceleration_curve = 1.0 - (speed_ratio * 0.6)  # Reduzi de 0.8 para 0.6
                
                # Personalidade afeta aceleração
                personality_accel_factor = 1.0
                if hasattr(self, 'aggression_level'):
                    # Motoristas agressivos aceleram mais
                    personality_accel_factor = 0.8 + (self.aggression_level * 0.4)
                
                # Aceleração gradual após parar (suavizar saída do semáforo)
                startup_factor = 1.0
                if self.current_speed < 0.3:  # Aumentado de 0.2 para 0.3
                    startup_factor = 0.6  # Ainda mais suave (40% menos aceleração)
                
                # === APLICAR FATOR DE SUAVIZAÇÃO GLOBAL ===
                smooth_factor = CAR_CONFIG.get('smooth_factor', 0.85)  # 85% da aceleração
                
                final_acceleration = (self.acceleration * acceleration_curve * 
                                    personality_accel_factor * startup_factor * smooth_factor)
                
                self.current_speed = min(self.max_speed, self.current_speed + final_acceleration)
                self.state = CarState.ACCELERATING
            else:
                self.state = CarState.DRIVING
    
    def _move(self):
        """Mover o carro baseado na velocidade atual"""
        if self.direction == Direction.LEFT_TO_RIGHT:
            self.x += self.current_speed
        elif self.direction == Direction.RIGHT_TO_LEFT:
            self.x -= self.current_speed
        elif self.direction == Direction.TOP_TO_BOTTOM:
            self.y += self.current_speed  # Move para BAIXO (Y aumenta)
    
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
        elif self.direction == Direction.TOP_TO_BOTTOM:
            return self.y > WINDOW_HEIGHT + 50  # Saiu pela parte de baixo da tela
        
        return False
    
    def draw(self, screen):
        """Desenhar carro com detalhes ultra-realísticos"""
        
        # === SOMBRA DO CARRO ===
        shadow_color = (*COLORS['shadow'][:3], 60)
        shadow_surface = pygame.Surface((self.width + 4, self.height + 4), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surface, shadow_color, 
                           (0, 0, self.width + 4, self.height + 4))
        screen.blit(shadow_surface, (self.x - 2, self.y + 2))
        
        # === CORPO PRINCIPAL COM GRADIENTE ===
        car_rect = pygame.Rect(self.x, self.y, self.width, self.height)
        pygame.draw.rect(screen, self.color, car_rect)
        
        # Brilho superior para efeito 3D
        highlight_color = tuple(min(255, c + 40) for c in self.color[:3])
        pygame.draw.rect(screen, highlight_color, 
                        (self.x, self.y, self.width, self.height // 3))
        
        # Sombra inferior para profundidade
        shadow_color = tuple(max(0, c - 30) for c in self.color[:3])
        pygame.draw.rect(screen, shadow_color, 
                        (self.x, self.y + (self.height * 2) // 3, self.width, self.height // 3))
        
        # === JANELAS REALÍSTICAS ===
        window_rect = (self.x + 3, self.y + 2, self.width - 6, self.height - 4)
        pygame.draw.rect(screen, COLORS['window_tint'], window_rect)
        
        # Reflexo nas janelas
        reflection_surface = pygame.Surface((self.width - 8, self.height - 6), pygame.SRCALPHA)
        reflection_color = COLORS['window_reflection']
        pygame.draw.rect(reflection_surface, reflection_color, 
                        (0, 0, (self.width - 8) // 2, self.height - 6))
        screen.blit(reflection_surface, (self.x + 4, self.y + 3))
        
        # === RODAS DETALHADAS ===
        wheel_positions = [
            (self.x + 4, self.y + 3),    # Dianteira esquerda
            (self.x + self.width - 4, self.y + 3),  # Dianteira direita
            (self.x + 4, self.y + self.height - 3), # Traseira esquerda
            (self.x + self.width - 4, self.y + self.height - 3) # Traseira direita
        ]
        
        for wheel_pos in wheel_positions:
            # Sombra da roda
            pygame.draw.circle(screen, COLORS['shadow_light'][:3], 
                             (wheel_pos[0] + 1, wheel_pos[1] + 1), 4)
            # Pneu
            pygame.draw.circle(screen, COLORS['wheel_tire'], wheel_pos, 3)
            # Aro
            pygame.draw.circle(screen, COLORS['wheel_rim'], wheel_pos, 2)
            # Detalhe cromado
            pygame.draw.circle(screen, COLORS['wheel_chrome'], wheel_pos, 1)
        
        # === FARÓIS DIRECIONAIS ===
        self._draw_headlights(screen)
        
        # === LUZES DE FREIO ===
        if self.should_stop and self.current_speed > 0.1:
            self._draw_brake_lights(screen)
        
        # === INDICADOR DE PERSONALIDADE SUTIL ===
        personality_colors = {
            DriverPersonality.AGGRESSIVE: (*COLORS['red'][:3], 120),
            DriverPersonality.NORMAL: (*COLORS['green'][:3], 120),
            DriverPersonality.CONSERVATIVE: (*COLORS['blue'][:3], 120),
            DriverPersonality.ELDERLY: (*COLORS['yellow'][:3], 120)
        }
        
        color = personality_colors[self.personality]
        indicator_surface = pygame.Surface((8, 3), pygame.SRCALPHA)
        indicator_surface.fill(color)
        screen.blit(indicator_surface, (self.x, self.y - 6))
    
    def _draw_headlights(self, screen):
        """Desenhar faróis baseados na direção"""
        headlight_color = COLORS['headlight']
        
        if self.direction == Direction.LEFT_TO_RIGHT:
            # Faróis à direita (frente do carro)
            pygame.draw.circle(screen, headlight_color, 
                              (self.x + self.width - 2, self.y + 4), 2)
            pygame.draw.circle(screen, headlight_color, 
                              (self.x + self.width - 2, self.y + self.height - 4), 2)
            # Efeito de brilho
            glow_surface = pygame.Surface((8, 8), pygame.SRCALPHA)
            pygame.draw.circle(glow_surface, (*headlight_color, 60), (4, 4), 4)
            screen.blit(glow_surface, (self.x + self.width - 6, self.y))
            screen.blit(glow_surface, (self.x + self.width - 6, self.y + self.height - 8))
            
        elif self.direction == Direction.RIGHT_TO_LEFT:
            # Faróis à esquerda (frente do carro)
            pygame.draw.circle(screen, headlight_color, 
                              (self.x + 2, self.y + 4), 2)
            pygame.draw.circle(screen, headlight_color, 
                              (self.x + 2, self.y + self.height - 4), 2)
            # Efeito de brilho
            glow_surface = pygame.Surface((8, 8), pygame.SRCALPHA)
            pygame.draw.circle(glow_surface, (*headlight_color, 60), (4, 4), 4)
            screen.blit(glow_surface, (self.x - 2, self.y))
            screen.blit(glow_surface, (self.x - 2, self.y + self.height - 8))
            
        elif self.direction == Direction.TOP_TO_BOTTOM:
            # Faróis embaixo (frente do carro)
            pygame.draw.circle(screen, headlight_color, 
                              (self.x + 4, self.y + self.height - 2), 2)
            pygame.draw.circle(screen, headlight_color, 
                              (self.x + self.width - 4, self.y + self.height - 2), 2)
            # Efeito de brilho
            glow_surface = pygame.Surface((8, 8), pygame.SRCALPHA)
            pygame.draw.circle(glow_surface, (*headlight_color, 60), (4, 4), 4)
            screen.blit(glow_surface, (self.x, self.y + self.height - 6))
            screen.blit(glow_surface, (self.x + self.width - 8, self.y + self.height - 6))
    
    def _draw_brake_lights(self, screen):
        """Desenhar luzes de freio"""
        brake_color = COLORS['brake_light']
        brake_surface = pygame.Surface((4, 6), pygame.SRCALPHA)
        brake_surface.fill(brake_color)
        
        if self.direction == Direction.LEFT_TO_RIGHT:
            # Luzes traseiras à esquerda
            screen.blit(brake_surface, (self.x - 2, self.y + 2))
            screen.blit(brake_surface, (self.x - 2, self.y + self.height - 8))
            
        elif self.direction == Direction.RIGHT_TO_LEFT:
            # Luzes traseiras à direita
            screen.blit(brake_surface, (self.x + self.width - 2, self.y + 2))
            screen.blit(brake_surface, (self.x + self.width - 2, self.y + self.height - 8))
            
        elif self.direction == Direction.TOP_TO_BOTTOM:
            # Luzes traseiras em cima
            brake_surface_h = pygame.Surface((6, 4), pygame.SRCALPHA)
            brake_surface_h.fill(brake_color)
            screen.blit(brake_surface_h, (self.x + 2, self.y - 2))
            screen.blit(brake_surface_h, (self.x + self.width - 8, self.y - 2))