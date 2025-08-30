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
        """Caixa do semáforo com efeitos ultra-realísticos"""
        x, y = position
        
        # === SOMBRA DA CAIXA ===
        shadow_rect = pygame.Rect(x - 17, y - 27, 34, 54)
        shadow_surface = pygame.Surface((34, 54), pygame.SRCALPHA)
        shadow_surface.fill((*COLORS['shadow'][:3], 100))
        screen.blit(shadow_surface, (x - 17, y - 27))
        
        # === CAIXA PRINCIPAL COM GRADIENTE ===
        box_rect = pygame.Rect(x - 15, y - 25, 30, 50)
        pygame.draw.rect(screen, (40, 40, 40), box_rect)
        # Gradiente superior (mais claro)
        pygame.draw.rect(screen, (60, 60, 60), 
                        (x - 15, y - 25, 30, 12))
        # Gradiente inferior (mais escuro)
        pygame.draw.rect(screen, (25, 25, 25), 
                        (x - 15, y + 13, 30, 12))
        
        # === BORDA METÁLICA ===
        pygame.draw.rect(screen, COLORS['pole_highlight'], box_rect, 2)
        pygame.draw.rect(screen, (180, 180, 180), box_rect, 1)
        
        # === LUZES COM EFEITOS AVANÇADOS ===
        light_positions = [(x, y - 15), (x, y), (x, y + 15)]
        light_colors = ['red', 'yellow', 'green']
        light_states = [state == 'red', state == 'yellow', state == 'green']
        
        for i, (pos, color, is_active) in enumerate(zip(light_positions, light_colors, light_states)):
            # === FUNDO DA LUZ ===
            pygame.draw.circle(screen, (15, 15, 15), pos, 10)
            pygame.draw.circle(screen, (30, 30, 30), pos, 9)
            pygame.draw.circle(screen, (20, 20, 20), pos, 8)
            
            if is_active:
                # === LUZ ATIVA COM MÚLTIPLAS CAMADAS DE BRILHO ===
                base_color = COLORS[color]
                
                # Efeito de brilho externo (múltiplas camadas)
                for radius in range(20, 8, -3):
                    alpha = max(0, 80 - (20 - radius) * 8)
                    glow_surface = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
                    pygame.draw.circle(glow_surface, (*base_color, alpha), 
                                     (radius, radius), radius)
                    screen.blit(glow_surface, (pos[0] - radius, pos[1] - radius))
                
                # Luz principal
                pygame.draw.circle(screen, base_color, pos, 8)
                
                # Brilho interno intenso
                inner_color = tuple(min(255, c + 100) for c in base_color)
                pygame.draw.circle(screen, inner_color, pos, 6)
                
                # Núcleo super brilhante
                core_color = tuple(min(255, c + 150) for c in base_color)
                pygame.draw.circle(screen, core_color, pos, 4)
                
                # Reflexo realístico
                pygame.draw.circle(screen, (255, 255, 255), 
                                 (pos[0] - 2, pos[1] - 2), 2)
                pygame.draw.circle(screen, (255, 255, 255, 150), 
                                 (pos[0] - 1, pos[1] - 1), 1)
            else:
                # === LUZ DESLIGADA ===
                dark_color = COLORS[f'{color}_dark']
                pygame.draw.circle(screen, dark_color, pos, 8)
                # Reflexo sutil mesmo desligada
                pygame.draw.circle(screen, (80, 80, 80), pos, 6)
                pygame.draw.circle(screen, (60, 60, 60), pos, 4)