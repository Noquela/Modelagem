import pygame
import sys
import time
import random
import math
from car import Car, Direction, DriverPersonality
from traffic_light import TrafficLightSystem
from advanced_spawn_system import AdvancedSpawnSystem
from traffic_analytics import TrafficAnalytics
from event_system import EventSystem
from config import *

class TrafficSim2D:
    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode((WINDOW_WIDTH, WINDOW_HEIGHT))
        pygame.display.set_caption("Traffic Simulator 2D - Sistema Completo Otimizado")
        self.clock = pygame.time.Clock()
        
        # Cache de superfícies para otimização
        self._intersection_surface = None
        self._intersection_dirty = True
        
        # Sistemas principais
        self.cars = []
        self.traffic_lights = TrafficLightSystem()
        self.spawn_system = AdvancedSpawnSystem()
        self.analytics = TrafficAnalytics()
        self.event_system = EventSystem()
        
        # Estado da simulação
        self.running = True
        self.paused = False
        self.show_debug = True
        
        # Estatísticas
        self.start_time = time.time()
        self.total_cars_spawned = 0
        self.total_cars_despawned = 0
        
        # === SISTEMA DE ANIMAÇÕES ===
        self.animation_time = 0
        self.weather_particles = []
        self.dust_particles = []
        
        # Fonte para UI
        self.font = pygame.font.Font(None, 24)
        self.small_font = pygame.font.Font(None, 18)
        
        print("=== TRAFFIC SIMULATOR 2D - SISTEMA COMPLETO ===")
        print("Controles:")
        print("  SPACE: Pausar/Continuar")
        print("  F1: Toggle Debug Info")
        print("  ESC: Sair")
        print("  R: Reset simulação")
        print()
    
    def draw_intersection(self):
        """Intersecção otimizada com cache de superfície"""
        
        # Usar cache se disponível
        if self._intersection_surface is None or self._intersection_dirty:
            self._create_intersection_surface()
            self._intersection_dirty = False
        
        # Blit cached surface
        self.screen.blit(self._intersection_surface, (0, 0))
    
    def _create_intersection_surface(self):
        """Intersecção com detalhes urbanos ultra-realísticos"""
        self._intersection_surface = pygame.Surface((WINDOW_WIDTH, WINDOW_HEIGHT))
        surface = self._intersection_surface
        
        # === FUNDO COM TEXTURA DE GRAMA ===
        surface.fill(COLORS['grass'])
        
        # Adicionar textura de grama (pontos aleatórios mais escuros)
        for _ in range(800):
            x = random.randint(0, WINDOW_WIDTH)
            y = random.randint(0, WINDOW_HEIGHT)
            if not self._is_on_road(x, y):  # Só na grama
                pygame.draw.circle(surface, COLORS['grass_dark'], (x, y), 1)
        
        # Variações de cor na grama
        for _ in range(400):
            x = random.randint(0, WINDOW_WIDTH)
            y = random.randint(0, WINDOW_HEIGHT)
            if not self._is_on_road(x, y):
                pygame.draw.circle(surface, COLORS['grass_light'], (x, y), 1)
        
        # === POSIÇÕES CENTRALIZADAS ===
        center_x = WINDOW_WIDTH // 2
        center_y = WINDOW_HEIGHT // 2
        road_y = center_y - 80
        cross_road_x = center_x - 40
        
        # === RUAS COM TEXTURA DE ASFALTO ===
        # Rua principal
        main_road_rect = pygame.Rect(0, road_y, WINDOW_WIDTH, 160)
        pygame.draw.rect(surface, COLORS['asphalt'], main_road_rect)
        
        # Textura do asfalto (pontos mais claros)
        for _ in range(300):
            x = random.randint(0, WINDOW_WIDTH)
            y = random.randint(road_y, road_y + 160)
            pygame.draw.circle(surface, COLORS['asphalt_worn'], (x, y), 1)
        
        # Rua vertical
        cross_road_rect = pygame.Rect(cross_road_x, 0, 80, WINDOW_HEIGHT)
        pygame.draw.rect(surface, COLORS['asphalt'], cross_road_rect)
        
        # Textura do asfalto vertical
        for _ in range(150):
            x = random.randint(cross_road_x, cross_road_x + 80)
            y = random.randint(0, WINDOW_HEIGHT)
            pygame.draw.circle(surface, COLORS['asphalt_worn'], (x, y), 1)
        
        # === MARCAÇÕES VIÁRIAS PREMIUM ===
        self._draw_premium_lane_markings(surface, cross_road_x, road_y)
        
        # === FAIXAS DE PEDESTRE ORGANIZADAS ===
        self._draw_organized_crosswalks(surface, cross_road_x, road_y)
        
        # === ELEMENTOS URBANOS ===
        self._draw_urban_elements(surface, cross_road_x, road_y)
        
        # === SISTEMA DE FAIXAS ORGANIZADO ===
        self._draw_organized_lane_system(surface, cross_road_x, road_y)
    
    def _draw_organized_crosswalks(self, surface, cross_road_x, road_y):
        """Faixas de pedestres organizadas e limpas"""
        
        # === FAIXA HORIZONTAL (NORTE-SUL) ===
        # Posicionada nas bordas da intersecção
        crosswalk_north_y = road_y - 10  # Borda norte da intersecção
        crosswalk_south_y = road_y + 170  # Borda sul da intersecção
        
        # Faixa norte (entrada da intersecção)
        for i in range(cross_road_x + 10, cross_road_x + 70, 10):
            # Faixas brancas com espaçamento organizado
            pygame.draw.rect(surface, COLORS['crosswalk'], 
                           (i, crosswalk_north_y, 6, 20))
            # Sombra sutil
            pygame.draw.rect(surface, COLORS['shadow_light'], 
                           (i + 1, crosswalk_north_y + 1, 6, 20))
        
        # Faixa sul (saída da intersecção)
        for i in range(cross_road_x + 10, cross_road_x + 70, 10):
            pygame.draw.rect(surface, COLORS['crosswalk'],
                           (i, crosswalk_south_y, 6, 20))
            pygame.draw.rect(surface, COLORS['shadow_light'],
                           (i + 1, crosswalk_south_y + 1, 6, 20))
        
        # === FAIXA VERTICAL (LESTE-OESTE) ===
        # Posicionada nas bordas da intersecção vertical
        crosswalk_west_x = cross_road_x - 10  # Borda oeste da intersecção
        crosswalk_east_x = cross_road_x + 90  # Borda leste da intersecção
        
        # Faixa oeste (entrada da intersecção)
        for i in range(road_y + 10, road_y + 150, 10):
            pygame.draw.rect(surface, COLORS['crosswalk'],
                           (crosswalk_west_x, i, 20, 6))
            pygame.draw.rect(surface, COLORS['shadow_light'],
                           (crosswalk_west_x + 1, i + 1, 20, 6))
        
        # Faixa leste (saída da intersecção)
        for i in range(road_y + 10, road_y + 150, 10):
            pygame.draw.rect(surface, COLORS['crosswalk'],
                           (crosswalk_east_x, i, 20, 6))
            pygame.draw.rect(surface, COLORS['shadow_light'],
                           (crosswalk_east_x + 1, i + 1, 20, 6))
    
    def _draw_organized_lane_system(self, surface, cross_road_x, road_y):
        """Sistema de faixas realístico e organizado - Padrão brasileiro"""
        
        # === 1. LINHA DIVISÓRIA CENTRAL (AMARELA CONTÍNUA) ===
        central_y = road_y + 80  # Centro da rua principal
        
        # Antes da intersecção
        pygame.draw.rect(surface, COLORS['yellow_line'], 
                        (0, central_y, cross_road_x - 40, 4))
        
        # Depois da intersecção  
        pygame.draw.rect(surface, COLORS['yellow_line'],
                        (cross_road_x + 120, central_y, WINDOW_WIDTH - (cross_road_x + 120), 4))
        
        # === 2. FAIXAS SENTIDO ESQUERDA→DIREITA ===
        # Faixa 1 (mais externa)
        lane1_y = road_y + 25
        self._draw_dashed_lane_line(surface, lane1_y, cross_road_x, 'horizontal')
        
        # Faixa 2 (mais interna - próxima ao centro)
        lane2_y = road_y + 55
        self._draw_dashed_lane_line(surface, lane2_y, cross_road_x, 'horizontal')
        
        # === 3. FAIXAS SENTIDO DIREITA→ESQUERDA ===
        # Faixa 3 (mais interna - próxima ao centro)
        lane3_y = road_y + 105  
        self._draw_dashed_lane_line(surface, lane3_y, cross_road_x, 'horizontal')
        
        # Faixa 4 (mais externa)
        lane4_y = road_y + 135
        self._draw_dashed_lane_line(surface, lane4_y, cross_road_x, 'horizontal')
        
        # === 4. FAIXA VERTICAL (RUA QUE CORTA) ===
        # Linha divisória central vertical
        vertical_center_x = cross_road_x + 40
        
        # Antes da intersecção
        pygame.draw.rect(surface, COLORS['white_line'],
                        (vertical_center_x, 0, 2, road_y - 40))
        
        # Depois da intersecção
        pygame.draw.rect(surface, COLORS['white_line'],
                        (vertical_center_x, road_y + 200, 2, WINDOW_HEIGHT - (road_y + 200)))
        
        # === 5. SETAS DIRECIONAIS ===
        self._draw_directional_arrows(surface, cross_road_x, road_y)
    
    def _draw_dashed_lane_line(self, surface, y_pos, cross_road_x, orientation):
        """Desenhar linha pontilhada entre faixas do mesmo sentido - CORRIGIDO PRECISO"""
        dash_length = 15
        gap_length = 10
        
        if orientation == 'horizontal':
            # === CALCULAR LIMITES EXATOS DA INTERSECÇÃO ===
            intersection_width = 80  # Largura exata da rua vertical
            crosswalk_margin = 20   # Margem para faixas de pedestres (reduzido de 50 para 20)
            
            # Limites precisos considerando crosswalks
            intersection_start = cross_road_x - crosswalk_margin  # Começar 20px antes da rua
            intersection_end = cross_road_x + intersection_width + crosswalk_margin  # Terminar 20px depois
            
            # === ANTES DA INTERSECÇÃO ===
            x = 0
            while x + dash_length <= intersection_start:  # Parar ANTES do limite
                pygame.draw.rect(surface, COLORS['white_line'], 
                               (x, y_pos, dash_length, 2))
                x += dash_length + gap_length
            
            # === DEPOIS DA INTERSECÇÃO ===
            x = intersection_end
            while x < WINDOW_WIDTH:
                if x + dash_length <= WINDOW_WIDTH:
                    pygame.draw.rect(surface, COLORS['white_line'],
                                   (x, y_pos, dash_length, 2))
                x += dash_length + gap_length
    
    def _draw_directional_arrows(self, surface, cross_road_x, road_y):
        """Desenhar setas direcionais nas faixas"""
        arrow_color = COLORS['white_line']
        
        # === SETAS HORIZONTAIS - POSICIONADAS FORA DA INTERSECÇÃO ===
        # Calcular posições seguras para as setas (evitar intersecção)
        intersection_start = cross_road_x - 20  # Margem da intersecção
        intersection_end = cross_road_x + 80 + 20  # Fim da intersecção + margem
        
        # Faixas esquerda→direita  
        for lane_y in [road_y + 25, road_y + 55]:
            # Setas ANTES da intersecção (mais afastadas)
            safe_positions_before = [cross_road_x - 250, cross_road_x - 150]
            # Setas DEPOIS da intersecção (mais afastadas)
            safe_positions_after = [cross_road_x + 150, cross_road_x + 250]
            
            for arrow_x in safe_positions_before + safe_positions_after:
                if 0 < arrow_x < WINDOW_WIDTH:
                    self._draw_right_arrow(surface, arrow_x, lane_y, arrow_color)
        
        # Faixas direita→esquerda
        for lane_y in [road_y + 105, road_y + 135]:
            # Usar as mesmas posições seguras
            for arrow_x in safe_positions_before + safe_positions_after:
                if 0 < arrow_x < WINDOW_WIDTH:
                    self._draw_left_arrow(surface, arrow_x, lane_y, arrow_color)
        
        # === SETAS VERTICAIS - POSICIONADAS FORA DA INTERSECÇÃO ===
        arrow_x = cross_road_x + 40
        # Setas ANTES da intersecção horizontal (mais afastadas)
        safe_y_before = [road_y - 250, road_y - 150]
        # Setas DEPOIS da intersecção horizontal (mais afastadas)  
        safe_y_after = [road_y + 200, road_y + 300]
        
        for arrow_y in safe_y_before + safe_y_after:
            if 0 < arrow_y < WINDOW_HEIGHT:
                self._draw_down_arrow(surface, arrow_x, arrow_y, arrow_color)
    
    def _draw_right_arrow(self, surface, x, y, color):
        """Desenhar seta apontando para direita"""
        points = [
            (x - 8, y - 4),   # Ponta esquerda superior
            (x + 4, y),       # Ponta direita
            (x - 8, y + 4),   # Ponta esquerda inferior
            (x - 4, y),       # Centro esquerdo
        ]
        pygame.draw.polygon(surface, color, points)
    
    def _draw_left_arrow(self, surface, x, y, color):
        """Desenhar seta apontando para esquerda"""
        points = [
            (x + 8, y - 4),   # Ponta direita superior
            (x - 4, y),       # Ponta esquerda
            (x + 8, y + 4),   # Ponta direita inferior
            (x + 4, y),       # Centro direito
        ]
        pygame.draw.polygon(surface, color, points)
    
    def _draw_down_arrow(self, surface, x, y, color):
        """Desenhar seta apontando para baixo"""
        points = [
            (x - 4, y - 8),   # Ponta superior esquerda
            (x, y + 4),       # Ponta inferior
            (x + 4, y - 8),   # Ponta superior direita
            (x, y - 4),       # Centro superior
        ]
        pygame.draw.polygon(surface, color, points)
    
    def _draw_crosswalks_on_surface(self, surface, cross_road_x, road_y):
        """Desenhar faixas de pedestre na superfície cached"""
        # Faixa horizontal (cruzando a rua vertical)
        for i in range(cross_road_x + 5, cross_road_x + 75, 8):
            pygame.draw.rect(surface, COLORS['white'], (i, road_y - 15, 4, 170))
        
        # Faixa vertical (cruzando a rua horizontal)  
        for i in range(road_y + 5, road_y + 155, 8):
            pygame.draw.rect(surface, COLORS['white'], (cross_road_x - 15, i, 160, 4))
    
    def _draw_premium_lane_markings(self, surface, cross_road_x, road_y):
        """Marcações viárias com efeito 3D"""
        
        # Linha central com efeito de profundidade
        central_y = road_y + 75
        
        # Sombra da linha
        pygame.draw.rect(surface, (0, 0, 0, 40), 
                        (0, central_y + 1, cross_road_x - 50, 5))
        pygame.draw.rect(surface, (0, 0, 0, 40), 
                        (cross_road_x + 130, central_y + 1, WINDOW_WIDTH - (cross_road_x + 130), 5))
        
        # Linha principal
        pygame.draw.rect(surface, COLORS['yellow_line'], 
                        (0, central_y, cross_road_x - 50, 4))
        pygame.draw.rect(surface, COLORS['yellow_line'], 
                        (cross_road_x + 130, central_y, WINDOW_WIDTH - (cross_road_x + 130), 4))
        
        # Brilho da linha
        pygame.draw.rect(surface, (255, 255, 150), 
                        (0, central_y, cross_road_x - 50, 1))
        pygame.draw.rect(surface, (255, 255, 150), 
                        (cross_road_x + 130, central_y, WINDOW_WIDTH - (cross_road_x + 130), 1))
    
    def _draw_detailed_crosswalks(self, surface, cross_road_x, road_y):
        """Faixas de pedestre com efeito 3D"""
        
        # Faixa horizontal
        for i in range(cross_road_x + 5, cross_road_x + 75, 12):
            # Sombra
            pygame.draw.rect(surface, (0, 0, 0, 60), 
                            (i + 1, road_y - 14, 8, 169))
            # Faixa principal
            pygame.draw.rect(surface, COLORS['crosswalk'], 
                            (i, road_y - 15, 8, 170))
            # Brilho
            pygame.draw.rect(surface, (255, 255, 255), 
                            (i, road_y - 15, 8, 2))
            
        # Faixa vertical
        for i in range(road_y + 5, road_y + 155, 12):
            # Sombra
            pygame.draw.rect(surface, (0, 0, 0, 60), 
                            (cross_road_x - 14, i + 1, 109, 8))
            # Faixa principal
            pygame.draw.rect(surface, COLORS['crosswalk'], 
                            (cross_road_x - 15, i, 110, 8))
            # Brilho
            pygame.draw.rect(surface, (255, 255, 255), 
                            (cross_road_x - 15, i, 110, 2))
    
    def _draw_urban_elements(self, surface, cross_road_x, road_y):
        """Elementos urbanos decorativos"""
        
        # === BUEIROS ===
        manhole_positions = [
            (cross_road_x - 150, road_y + 80),
            (cross_road_x + 230, road_y + 80),
            (cross_road_x + 40, road_y - 150),
            (cross_road_x + 40, road_y + 310)
        ]
        
        for pos in manhole_positions:
            if not self._is_on_road(pos[0], pos[1]):  # Só fora das ruas
                # Sombra do bueiro
                pygame.draw.circle(surface, COLORS['shadow'][:3], 
                                 (pos[0] + 2, pos[1] + 2), 17)
                # Tampa do bueiro
                pygame.draw.circle(surface, COLORS['manhole_cover'], pos, 15)
                pygame.draw.circle(surface, COLORS['manhole_rim'], pos, 12)
                pygame.draw.circle(surface, COLORS['manhole_dark'], pos, 8)
                # Padrão da tampa
                for angle in range(0, 360, 45):
                    x = pos[0] + 6 * math.cos(math.radians(angle))
                    y = pos[1] + 6 * math.sin(math.radians(angle))
                    pygame.draw.circle(surface, COLORS['manhole_rim'], (int(x), int(y)), 2)
        
        # === ÁRVORES NAS CALÇADAS ===
        tree_positions = [
            (200, 200), (400, 200), (WINDOW_WIDTH - 200, 200),
            (200, WINDOW_HEIGHT - 200), (400, WINDOW_HEIGHT - 200),
            (WINDOW_WIDTH - 200, WINDOW_HEIGHT - 200),
            (100, road_y - 120), (WINDOW_WIDTH - 100, road_y - 120),
            (100, road_y + 280), (WINDOW_WIDTH - 100, road_y + 280)
        ]
        
        for pos in tree_positions:
            if not self._is_on_road(pos[0], pos[1]):
                # Sombra da árvore
                pygame.draw.ellipse(surface, COLORS['shadow'][:3], 
                                  (pos[0] - 18, pos[1] + 15, 36, 25))
                # Tronco
                pygame.draw.rect(surface, COLORS['tree_trunk'], 
                               (pos[0] - 4, pos[1] + 12, 8, 20))
                # Copa da árvore (múltiplas camadas)
                pygame.draw.circle(surface, COLORS['tree_leaves_dark'], pos, 20)
                pygame.draw.circle(surface, COLORS['tree_leaves'], pos, 18)
                pygame.draw.circle(surface, COLORS['tree_leaves_light'], pos, 15)
                # Detalhes na copa
                for _ in range(8):
                    detail_x = pos[0] + random.randint(-12, 12)
                    detail_y = pos[1] + random.randint(-12, 12)
                    pygame.draw.circle(surface, COLORS['tree_leaves_dark'], 
                                     (detail_x, detail_y), 2)
    
    def _is_on_road(self, x, y):
        """Verificar se posição está na rua"""
        center_x = WINDOW_WIDTH // 2
        center_y = WINDOW_HEIGHT // 2
        road_y = center_y - 80
        cross_road_x = center_x - 40
        
        # Na rua horizontal
        if road_y <= y <= road_y + 160:
            return True
        
        # Na rua vertical
        if cross_road_x <= x <= cross_road_x + 80:
            return True
        
        return False
    
    
    def update_simulation(self, dt):
        """Atualizar toda a simulação"""
        if self.paused:
            return
        
        # Atualizar semáforos
        self.traffic_lights.update()
        
        # Spawnar novos carros
        new_cars = self.spawn_system.update(self.cars)
        self.cars.extend(new_cars)
        self.total_cars_spawned += len(new_cars)
        
        # Atualizar carros
        for car in self.cars[:]:  # Cópia para poder remover
            car.update(self.cars, self.traffic_lights)
            
            # Remover carros que saíram da tela
            if car.is_out_of_bounds():
                self.cars.remove(car)
                self.total_cars_despawned += 1
        
        # Atualizar analytics
        self.analytics.update(self.cars, self.traffic_lights)
        
        # Atualizar eventos
        self.event_system.update(self.cars, self.traffic_lights)
        
        # === ATUALIZAR EFEITOS VISUAIS ===
        self.update_animation_effects(dt)
    
    def draw_cars(self):
        """Desenhar carros otimizado por camadas (z-order)"""
        # Separar carros por layers para renderização correta
        cars_by_layer = self._sort_cars_by_render_order()
        
        for layer in cars_by_layer:
            for car in layer:
                car.draw(self.screen)
    
    def _sort_cars_by_render_order(self):
        """Separar carros em camadas de renderização para otimizar z-order"""
        # Carros indo para baixo (rua vertical) ficam atrás
        # Carros da rua horizontal ficam na frente
        
        vertical_cars = [car for car in self.cars if car.direction.name == 'TOP_TO_BOTTOM']
        horizontal_cars = [car for car in self.cars if car.direction.name in ['LEFT_TO_RIGHT', 'RIGHT_TO_LEFT']]
        
        # Ordenar horizontal cars por Y para sobreposição correta
        horizontal_cars.sort(key=lambda c: c.y)
        
        return [vertical_cars, horizontal_cars]
    
    def update_animation_effects(self, dt):
        """Atualizar efeitos visuais dinâmicos"""
        self.animation_time += dt
        
        # === PARTÍCULAS DE POEIRA ===
        # Adicionar novas partículas para carros rápidos
        for car in self.cars:
            if car.current_speed > 1.5 and random.random() < 0.3:  # 30% chance
                particle = {
                    'x': car.x + random.randint(-3, 3),
                    'y': car.y + car.height + random.randint(0, 2),
                    'life': 1.0,
                    'decay': random.uniform(0.02, 0.04)
                }
                self.dust_particles.append(particle)
        
        # Atualizar partículas existentes
        for particle in self.dust_particles[:]:
            particle['life'] -= particle['decay']
            particle['y'] += 0.5  # Deriva para baixo
            particle['x'] += random.uniform(-0.2, 0.2)  # Deriva aleatória
            
            if particle['life'] <= 0:
                self.dust_particles.remove(particle)
        
        # Limitar número de partículas para performance
        if len(self.dust_particles) > 50:
            self.dust_particles = self.dust_particles[-50:]
    
    def draw_dynamic_effects(self):
        """Efeitos dinâmicos sobre a cena"""
        
        # === PARTÍCULAS DE POEIRA ===
        for particle in self.dust_particles:
            alpha = int(particle['life'] * 120)
            if alpha > 0:
                particle_color = (*COLORS['dust_particle'][:3], alpha)
                particle_surface = pygame.Surface((3, 3), pygame.SRCALPHA)
                particle_surface.fill(particle_color)
                self.screen.blit(particle_surface, (int(particle['x']), int(particle['y'])))
        
        # === REFLEXOS DOS SEMÁFOROS (SIMULAÇÃO DE PISTA MOLHADA) ===
        if hasattr(self, '_show_reflections') and self._show_reflections:
            self._draw_light_reflections()
        
        # === ANIMAÇÃO SUTIL DOS SEMÁFOROS AMARELOS ===
        if (self.traffic_lights.main_road_state == "yellow" or 
            self.traffic_lights.cross_road_state == "yellow"):
            # Efeito de piscar sutil já implementado nos semáforos
            pass
    
    def _draw_light_reflections(self):
        """Desenhar reflexos dos semáforos na pista (efeito de chuva)"""
        from config import TRAFFIC_LIGHTS
        
        for light_id, light_config in TRAFFIC_LIGHTS.items():
            state = light_config['state']
            pos = light_config['pos']
            
            if state in ['red', 'yellow', 'green']:
                # Reflexo na pista abaixo do semáforo
                reflection_y = pos[1] + 80
                reflection_color = (*COLORS[state][:3], 40)
                
                # Criar efeito de reflexo oval
                reflection_surface = pygame.Surface((60, 30), pygame.SRCALPHA)
                pygame.draw.ellipse(reflection_surface, reflection_color, 
                                  (0, 0, 60, 30))
                self.screen.blit(reflection_surface, (pos[0] - 30, reflection_y))
    
    def draw_ui(self):
        """Interface EXATA baseada no que desenvolvemos"""
        if not self.show_debug:
            return
        
        # Fundo semi-transparente para o debug (expandido para filas)
        debug_surface = pygame.Surface((340, 550))
        debug_surface.set_alpha(180)
        debug_surface.fill((0, 0, 0))
        self.screen.blit(debug_surface, (10, 10))
        
        y = 20
        
        # Título
        text = self.font.render("=== TRAFFIC SIMULATOR DEBUG ===", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 35
        
        # Tempo de simulação e FPS
        elapsed = time.time() - self.start_time
        fps = self.clock.get_fps()
        fps_color = COLORS['green'] if fps >= 55 else COLORS['yellow'] if fps >= 40 else COLORS['red']
        
        text = self.font.render(f"Tempo: {elapsed:.1f}s", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 20
        
        text = self.small_font.render(f"FPS: {fps:.1f}", True, fps_color)
        self.screen.blit(text, (20, y))
        y += 25
        
        # Contador de carros
        text = self.font.render(f"Carros na tela: {len(self.cars)}", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 20
        
        text = self.small_font.render(f"Spawnados: {self.total_cars_spawned}", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 15
        
        text = self.small_font.render(f"Despawnados: {self.total_cars_despawned}", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 25
        
        # Estado dos semáforos
        debug_info = self.traffic_lights.get_debug_info()
        
        text = self.font.render("=== SEMÁFOROS ===", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 25
        
        main_state = debug_info['main_road_state'].upper()
        main_color = COLORS['green'] if main_state == "GREEN" else \
                    COLORS['yellow'] if main_state == "YELLOW" else COLORS['red']
        text = self.small_font.render(f"Rua Principal: {main_state}", True, main_color)
        self.screen.blit(text, (20, y))
        y += 20
        
        cross_state = debug_info['cross_road_state'].upper()
        cross_color = COLORS['green'] if cross_state == "GREEN" else \
                     COLORS['yellow'] if cross_state == "YELLOW" else COLORS['red']
        text = self.small_font.render(f"Rua que Corta: {cross_state}", True, cross_color)
        self.screen.blit(text, (20, y))
        y += 20
        
        progress = debug_info['cycle_progress'] * 100
        text = self.small_font.render(f"Progresso do Ciclo: {progress:.1f}%", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 25
        
        # Estatísticas por personalidade
        text = self.font.render("=== PERSONALIDADES ===", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 25
        
        personalities = {}
        for car in self.cars:
            p = car.personality.value
            personalities[p] = personalities.get(p, 0) + 1
        
        personality_colors = {
            'aggressive': COLORS['red'],
            'normal': COLORS['green'],
            'conservative': COLORS['blue'],
            'elderly': COLORS['yellow']
        }
        
        for personality in ['aggressive', 'normal', 'conservative', 'elderly']:
            count = personalities.get(personality, 0)
            color = personality_colors.get(personality, COLORS['white'])
            text = self.small_font.render(f"{personality.title()}: {count}", True, color)
            self.screen.blit(text, (20, y))
            y += 18
        
        # === ANALYTICS AVANÇADOS ===
        y += 10
        text = self.font.render("=== ANALYTICS AVANÇADOS ===", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 25
        
        # Estatísticas do sistema de analytics
        analytics_report = self.analytics.get_detailed_report()
        
        # Throughput
        text = self.small_font.render(f"Throughput Total: {analytics_report['total_crossings']}", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 18
        
        # Velocidade média
        text = self.small_font.render(f"Velocidade Média: {analytics_report['average_speed']:.1f}", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 18
        
        # Congestionamento
        congestion_color = COLORS['green'] if analytics_report['current_congestion'] < 30 else \
                          COLORS['yellow'] if analytics_report['current_congestion'] < 60 else COLORS['red']
        text = self.small_font.render(f"Congestionamento: {analytics_report['current_congestion']:.0f}%", True, congestion_color)
        self.screen.blit(text, (20, y))
        y += 18
        
        # Eficiência
        efficiency_color = COLORS['green'] if analytics_report['efficiency_rating'] > 80 else \
                          COLORS['yellow'] if analytics_report['efficiency_rating'] > 60 else COLORS['red']
        text = self.small_font.render(f"Eficiência: {analytics_report['efficiency_rating']:.0f}%", True, efficiency_color)
        self.screen.blit(text, (20, y))
        y += 18
        
        # Quase-colisões
        if analytics_report['near_misses'] > 0:
            text = self.small_font.render(f"Quase-colisões: {analytics_report['near_misses']}", True, COLORS['red'])
            self.screen.blit(text, (20, y))
            y += 18
        
        # Status do rush hour
        if hasattr(self.spawn_system, 'rush_hour_active') and self.spawn_system.rush_hour_active:
            text = self.small_font.render("🚗 RUSH HOUR ATIVO", True, COLORS['yellow'])
            self.screen.blit(text, (20, y))
            y += 18
        
        # Na intersecção
        text = self.small_font.render(f"Na Intersecção: {analytics_report.get('cars_in_intersection', 0)}", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 18
        
        # === SISTEMA DE FILAS ===
        text = self.font.render("=== FILAS ===", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 20
        
        # Contar carros parados por direção
        stopped_cars = {
            'LEFT_TO_RIGHT': len([car for car in self.cars 
                                if car.direction.name == 'LEFT_TO_RIGHT' and car.current_speed < 0.1]),
            'RIGHT_TO_LEFT': len([car for car in self.cars 
                                if car.direction.name == 'RIGHT_TO_LEFT' and car.current_speed < 0.1]),
            'TOP_TO_BOTTOM': len([car for car in self.cars 
                                if car.direction.name == 'TOP_TO_BOTTOM' and car.current_speed < 0.1])
        }
        
        text = self.small_font.render(f"Fila Esq→Dir: {stopped_cars['LEFT_TO_RIGHT']}", True, COLORS['yellow'])
        self.screen.blit(text, (20, y))
        y += 15
        
        text = self.small_font.render(f"Fila Dir→Esq: {stopped_cars['RIGHT_TO_LEFT']}", True, COLORS['yellow'])
        self.screen.blit(text, (20, y))
        y += 15
        
        text = self.small_font.render(f"Fila Vertical: {stopped_cars['TOP_TO_BOTTOM']}", True, COLORS['yellow'])
        self.screen.blit(text, (20, y))
        y += 20
        
        # === GRÁFICO DE THROUGHPUT ===
        graph_rect = pygame.Rect(WINDOW_WIDTH - 220, 20, 200, 120)
        self.analytics.draw_throughput_graph(self.screen, graph_rect)
        
        # === NOTIFICAÇÕES DE EVENTOS ===
        self.event_system.draw_notifications(self.screen, self.font)
        
        # Estado de pausa
        if self.paused:
            pause_text = self.font.render("*** PAUSADO ***", True, COLORS['yellow'])
            self.screen.blit(pause_text, (WINDOW_WIDTH // 2 - 80, 50))
    
    def handle_events(self):
        """Processar eventos"""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return False
            
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return False
                elif event.key == pygame.K_SPACE:
                    self.paused = not self.paused
                    print(f"Simulação {'pausada' if self.paused else 'retomada'}")
                elif event.key == pygame.K_F1:
                    self.show_debug = not self.show_debug
                    print(f"Debug info {'habilitado' if self.show_debug else 'desabilitado'}")
                elif event.key == pygame.K_r:
                    self._reset_simulation()
                    print("Simulação reiniciada")
        
        return True
    
    def _reset_simulation(self):
        """Reiniciar simulação"""
        self.cars.clear()
        self.spawn_system = AdvancedSpawnSystem()
        self.traffic_lights = TrafficLightSystem()
        self.start_time = time.time()
        self.total_cars_spawned = 0
        self.total_cars_despawned = 0
    
    def run(self):
        """Loop principal OTIMIZADO para alta performance"""
        print("Iniciando simulação...")
        
        # === OTIMIZAÇÕES DE PERFORMANCE ===
        frame_count = 0
        last_fps_update = time.time()
        fps_display_interval = 0.5  # Atualizar FPS a cada 0.5s
        
        while self.running:
            dt = self.clock.tick(60) / 1000.0  # 60 FPS
            frame_count += 1
            
            # Processar eventos
            if not self.handle_events():
                break
            
            # Atualizar simulação se não pausado
            if not self.paused:
                self.update_simulation(dt)
            
            # Renderizar
            self.draw_intersection()
            self.traffic_lights.draw(self.screen)
            
            # Desenhar carros com culling básico
            for car in self.cars:
                if (-50 <= car.x <= WINDOW_WIDTH + 50 and
                    -50 <= car.y <= WINDOW_HEIGHT + 50):
                    car.draw(self.screen)
            
            # UI se debug habilitado
            if self.show_debug:
                self.draw_ui()
            
            pygame.display.flip()
        
        # Estatísticas finais após o loop
        elapsed = time.time() - self.start_time
        print(f"\n=== ESTATÍSTICAS FINAIS ===")
        print(f"Tempo total: {elapsed:.1f}s")
        print(f"Carros spawnados: {self.total_cars_spawned}")
        print(f"Carros despawnados: {self.total_cars_despawned}")
        print(f"Taxa média de spawn: {self.total_cars_spawned/max(elapsed, 1):.2f} carros/s")
        
        pygame.quit()
        sys.exit()

if __name__ == "__main__":
    sim = TrafficSim2D()
    sim.run()