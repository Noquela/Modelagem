import random
import time
import pygame
from config import COLORS

class Event:
    """Classe base para eventos"""
    def __init__(self, duration=30):
        self.start_time = time.time()
        self.duration = duration  # segundos
        self.active = True
    
    def update(self, cars, traffic_lights):
        """Atualizar evento - deve ser implementado pelas subclasses"""
        pass
    
    def is_finished(self):
        """Verificar se evento terminou"""
        return time.time() - self.start_time > self.duration
    
    def draw_notification(self, screen, font):
        """Desenhar notificação do evento"""
        pass

class AccidentEvent(Event):
    """Evento de acidente que bloqueia uma faixa"""
    def __init__(self, duration=45):
        super().__init__(duration)
        self.lane_blocked = random.choice([0, 1])  # Faixa bloqueada
        self.direction_blocked = random.choice(['LEFT_TO_RIGHT', 'RIGHT_TO_LEFT'])
        self.accident_pos = self._get_accident_position()
        self.message = f"🚨 ACIDENTE - Faixa {self.lane_blocked + 1} bloqueada"
        
    def _get_accident_position(self):
        """Posição do acidente"""
        if self.direction_blocked == 'LEFT_TO_RIGHT':
            return (600, 330 + (self.lane_blocked * 35))
        else:
            return (600, 445 - (self.lane_blocked * 35))
    
    def update(self, cars, traffic_lights):
        """Forçar carros a evitar a faixa bloqueada"""
        for car in cars:
            if (car.direction.name == self.direction_blocked and 
                car.lane == self.lane_blocked and
                abs(car.x - self.accident_pos[0]) < 200):
                # Forçar parada antes do acidente
                car.should_stop = True
    
    def draw_notification(self, screen, font):
        """Desenhar notificação e local do acidente"""
        # Notificação no topo
        text = font.render(self.message, True, COLORS['red'])
        screen.blit(text, (400, 100))
        
        # Indicador visual do acidente
        pygame.draw.circle(screen, COLORS['red'], self.accident_pos, 20)
        pygame.draw.circle(screen, COLORS['yellow'], self.accident_pos, 25, 3)

class EmergencyVehicleEvent(Event):
    """Veículo de emergência atravessando"""
    def __init__(self, duration=15):
        super().__init__(duration)
        self.emergency_pos = [0, 380]  # Posição inicial
        self.speed = 4.0  # Mais rápido que carros normais
        self.message = "🚑 AMBULÂNCIA - Dê passagem!"
        self.siren_blink = 0
        
    def update(self, cars, traffic_lights):
        """Mover ambulância e forçar carros a dar passagem"""
        # Mover ambulância
        self.emergency_pos[0] += self.speed
        self.siren_blink += 1
        
        # Forçar carros próximos a parar
        for car in cars:
            distance = ((car.x - self.emergency_pos[0])**2 + (car.y - self.emergency_pos[1])**2)**0.5
            if distance < 150 and car.x < self.emergency_pos[0]:
                car.should_stop = True
    
    def draw_notification(self, screen, font):
        """Desenhar ambulância e notificação"""
        # Notificação
        text = font.render(self.message, True, COLORS['red'])
        screen.blit(text, (400, 120))
        
        # Ambulância
        if self.emergency_pos[0] < 1250:  # Ainda na tela
            # Corpo da ambulância
            pygame.draw.rect(screen, COLORS['white'], 
                           (self.emergency_pos[0], self.emergency_pos[1], 35, 18))
            
            # Sirene piscando
            siren_color = COLORS['red'] if (self.siren_blink // 5) % 2 == 0 else COLORS['blue']
            pygame.draw.circle(screen, siren_color, 
                             (int(self.emergency_pos[0] + 17), int(self.emergency_pos[1] - 5)), 8)

class ConstructionEvent(Event):
    """Obra que reduz velocidade"""
    def __init__(self, duration=120):  # 2 minutos
        super().__init__(duration)
        self.construction_zone = pygame.Rect(300, 320, 200, 160)
        self.message = "🚧 OBRA - Velocidade reduzida"
        
    def update(self, cars, traffic_lights):
        """Reduzir velocidade dos carros na zona de obra"""
        for car in cars:
            car_rect = pygame.Rect(car.x, car.y, car.width, car.height)
            if self.construction_zone.colliderect(car_rect):
                # Reduzir velocidade máxima temporariamente
                if not hasattr(car, '_original_max_speed'):
                    car._original_max_speed = car.max_speed
                car.max_speed = car._original_max_speed * 0.6  # 60% da velocidade
            else:
                # Restaurar velocidade original
                if hasattr(car, '_original_max_speed'):
                    car.max_speed = car._original_max_speed
                    delattr(car, '_original_max_speed')
    
    def draw_notification(self, screen, font):
        """Desenhar zona de obra"""
        # Notificação
        text = font.render(self.message, True, COLORS['yellow'])
        screen.blit(text, (400, 140))
        
        # Zona de obra
        pygame.draw.rect(screen, COLORS['yellow'], self.construction_zone, 3)
        
        # Cones de trânsito
        for i in range(5):
            cone_x = self.construction_zone.left + (i * 40)
            cone_y = self.construction_zone.top + 20
            pygame.draw.polygon(screen, COLORS['yellow'], 
                              [(cone_x, cone_y), (cone_x - 5, cone_y + 15), (cone_x + 5, cone_y + 15)])

class RushHourEvent(Event):
    """Evento especial de rush hour intenso"""
    def __init__(self, duration=180):  # 3 minutos
        super().__init__(duration)
        self.message = "🚗 RUSH HOUR INTENSO"
        self.spawn_multiplier = 3.0
        
    def update(self, cars, traffic_lights):
        """Aumentar drasticamente o spawn rate"""
        # O sistema de spawn avançado já detecta rush hour automaticamente
        pass
    
    def draw_notification(self, screen, font):
        """Notificação de rush hour"""
        text = font.render(self.message, True, COLORS['yellow'])
        screen.blit(text, (400, 160))

class EventSystem:
    def __init__(self):
        self.active_events = []
        self.event_probability = 0.0003  # REDUZIDO de 0.0008 para 0.0003 - eventos menos frequentes
        self.last_event_time = time.time()
        self.min_event_interval = 15  # Mínimo 15 segundos entre eventos
        
        # Tipos de eventos e suas probabilidades
        self.event_types = {
            'accident': 0.3,
            'emergency': 0.25,
            'construction': 0.2,
            'rush_hour': 0.15
        }
    
    def update(self, cars, traffic_lights):
        """Atualizar eventos ativos e gerar novos"""
        current_time = time.time()
        
        # Chance de evento aleatório (respeitando intervalo mínimo)
        if (current_time - self.last_event_time > self.min_event_interval and
            random.random() < self.event_probability):
            
            event_type = self._choose_event_type()
            self._trigger_event(event_type)
            self.last_event_time = current_time
        
        # Processar eventos ativos
        for event in self.active_events[:]:
            event.update(cars, traffic_lights)
            if event.is_finished():
                self.active_events.remove(event)
                # Restaurar carros afetados por construção
                if isinstance(event, ConstructionEvent):
                    for car in cars:
                        if hasattr(car, '_original_max_speed'):
                            car.max_speed = car._original_max_speed
                            delattr(car, '_original_max_speed')
    
    def _choose_event_type(self):
        """Escolher tipo de evento baseado em probabilidades"""
        rand = random.random()
        cumulative = 0
        
        for event_type, probability in self.event_types.items():
            cumulative += probability
            if rand <= cumulative:
                return event_type
        
        return 'accident'  # fallback
    
    def _trigger_event(self, event_type):
        """Disparar evento específico"""
        if event_type == 'accident':
            self.active_events.append(AccidentEvent())
        elif event_type == 'emergency':
            self.active_events.append(EmergencyVehicleEvent())
        elif event_type == 'construction':
            # Só iniciar obra se não há outra ativa
            if not any(isinstance(e, ConstructionEvent) for e in self.active_events):
                self.active_events.append(ConstructionEvent())
        elif event_type == 'rush_hour':
            # Só iniciar rush hour se não há outro ativo
            if not any(isinstance(e, RushHourEvent) for e in self.active_events):
                self.active_events.append(RushHourEvent())
    
    def draw_notifications(self, screen, font):
        """Desenhar todas as notificações de eventos"""
        for event in self.active_events:
            event.draw_notification(screen, font)
    
    def get_active_events(self):
        """Retornar lista de eventos ativos"""
        return [(type(event).__name__, event.duration - (time.time() - event.start_time)) 
                for event in self.active_events]