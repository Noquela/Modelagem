import pygame
import time
from config import *

class TrafficLightSystem:
    def __init__(self):
        # Tempos EXATOS (baseado no sistema de 37 segundos desenvolvido)
        self.green_time = TRAFFIC_LIGHT_TIMING['green_time']
        self.yellow_time = TRAFFIC_LIGHT_TIMING['yellow_time']
        self.safety_time = TRAFFIC_LIGHT_TIMING['safety_time']
        self.total_cycle = TRAFFIC_LIGHT_TIMING['total_cycle']
        
        self.cycle_start = time.time()
        
        # Estados dos semáforos
        self.main_road_state = "red"
        self.cross_road_state = "red"
        
        # Posições dos semáforos (EXATAS)
        self.semaforo_1_pos = SEMAFORO_1  # Rua principal - esquerda→direita
        self.semaforo_2_pos = SEMAFORO_2  # Rua principal - direita→esquerda
        self.semaforo_3_pos = SEMAFORO_3  # Rua que corta - cima→baixo
    
    def update(self):
        """Lógica EXATA dos tempos que desenvolvemos"""
        elapsed = (time.time() - self.cycle_start) % self.total_cycle
        
        if elapsed < self.green_time:
            # Rua principal verde, rua que corta vermelho
            self.main_road_state = "green"
            self.cross_road_state = "red"
        elif elapsed < (self.green_time + self.yellow_time):
            # Rua principal amarelo, rua que corta vermelho
            self.main_road_state = "yellow"
            self.cross_road_state = "red"
        elif elapsed < (self.green_time + self.yellow_time + self.safety_time):
            # TEMPO DE SEGURANÇA: ambos vermelhos (IMPORTANTE!)
            self.main_road_state = "red"
            self.cross_road_state = "red"
        elif elapsed < (self.green_time + self.yellow_time + self.safety_time + self.green_time):
            # Rua principal vermelho, rua que corta verde
            self.main_road_state = "red"
            self.cross_road_state = "green"
        else:
            # Rua principal vermelho, rua que corta amarelo
            self.main_road_state = "red"
            self.cross_road_state = "yellow"
    
    def get_cycle_progress(self):
        """Retornar progresso do ciclo (0.0 a 1.0)"""
        elapsed = (time.time() - self.cycle_start) % self.total_cycle
        return elapsed / self.total_cycle
    
    def get_debug_info(self):
        """Informações para debug"""
        elapsed = (time.time() - self.cycle_start) % self.total_cycle
        return {
            'main_road_state': self.main_road_state,
            'cross_road_state': self.cross_road_state,
            'cycle_elapsed': elapsed,
            'cycle_progress': self.get_cycle_progress()
        }
    
    def draw(self, screen):
        """Desenhar todos os semáforos com hastes direcionais"""
        from config import TRAFFIC_LIGHTS
        
        # Atualizar estados nos configs
        TRAFFIC_LIGHTS['semaforo_1']['state'] = self.main_road_state
        TRAFFIC_LIGHTS['semaforo_2']['state'] = self.main_road_state
        TRAFFIC_LIGHTS['semaforo_3']['state'] = self.cross_road_state
        
        # Desenhar semáforos com hastes
        for light_id, light_config in TRAFFIC_LIGHTS.items():
            self._draw_traffic_light_with_arm(screen, light_config)
    
    def _draw_traffic_light(self, screen, position, state):
        """Desenhar um semáforo individual"""
        x, y = position
        
        # Poste do semáforo
        pygame.draw.rect(screen, COLORS['pole'], (x - 8, y - 30, 16, 80))
        
        # Fundo da caixa do semáforo
        pygame.draw.rect(screen, (40, 40, 40), (x - 15, y - 25, 30, 50))
        
        # Luz vermelha (topo)
        red_color = COLORS['red'] if state == "red" else COLORS['dark_red']
        pygame.draw.circle(screen, red_color, (x, y - 15), 8)
        
        # Luz amarela (meio)
        yellow_color = COLORS['yellow'] if state == "yellow" else COLORS['dark_yellow']
        pygame.draw.circle(screen, yellow_color, (x, y), 8)
        
        # Luz verde (base)
        green_color = COLORS['green'] if state == "green" else COLORS['dark_green']
        pygame.draw.circle(screen, green_color, (x, y + 15), 8)
    
    def _draw_traffic_light_with_arm(self, screen, light_config):
        """Desenhar semáforo com haste direcionada para a rua"""
        pos = light_config['pos']
        direction = light_config['direction']
        state = light_config['state']
        
        # Poste vertical
        pygame.draw.rect(screen, COLORS['pole'], (pos[0]-4, pos[1], 8, 40))
        
        # Haste horizontal direcionada
        if direction == 'horizontal_left':
            # Haste apontando para a pista da esquerda
            arm_start = (pos[0], pos[1]+20)
            arm_end = (pos[0]-30, pos[1]+20)
            light_pos = (pos[0]-35, pos[1]+20)
        elif direction == 'horizontal_right':
            # Haste apontando para a pista da direita
            arm_start = (pos[0], pos[1]+20)
            arm_end = (pos[0]+30, pos[1]+20)
            light_pos = (pos[0]+35, pos[1]+20)
        elif direction == 'vertical_up':
            # Haste apontando para a pista vertical
            arm_start = (pos[0], pos[1]+20)
            arm_end = (pos[0], pos[1]-30)
            light_pos = (pos[0], pos[1]-35)
        
        # Desenhar haste
        pygame.draw.line(screen, COLORS['pole'], arm_start, arm_end, 3)
        
        # Desenhar semáforo na ponta da haste
        self._draw_light_box(screen, light_pos, state)
    
    def _draw_light_box(self, screen, position, state):
        """Desenhar caixa do semáforo"""
        x, y = position
        
        # Fundo da caixa do semáforo
        pygame.draw.rect(screen, (40, 40, 40), (x - 15, y - 25, 30, 50))
        
        # Luz vermelha (topo)
        red_color = COLORS['red'] if state == "red" else COLORS['dark_red']
        pygame.draw.circle(screen, red_color, (x, y - 15), 8)
        
        # Luz amarela (meio)
        yellow_color = COLORS['yellow'] if state == "yellow" else COLORS['dark_yellow']
        pygame.draw.circle(screen, yellow_color, (x, y), 8)
        
        # Luz verde (base)
        green_color = COLORS['green'] if state == "green" else COLORS['dark_green']
        pygame.draw.circle(screen, green_color, (x, y + 15), 8)