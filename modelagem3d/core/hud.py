"""
HUD 2D Resolution-Independent 
============================

Sistema de interface 2D sobreposto com:
- Ancoragem por cantos e escala relativa
- Suporte para qualquer resolução incluindo ultrawide
- Painéis informativos com métricas em tempo real
"""

import pygame
import math
from OpenGL.GL import *

class HUD:
    """Sistema de HUD 2D sobreposto"""
    
    def __init__(self, screen_width, screen_height):
        self.screen_width = screen_width
        self.screen_height = screen_height
        
        # Superfície para desenho 2D
        self.surface = pygame.Surface((screen_width, screen_height), pygame.SRCALPHA)
        
        # Fontes com tamanhos relativos
        base_size = int(min(screen_width, screen_height) * 0.02)  # 2% da menor dimensão
        
        self.font_large = pygame.font.Font(None, int(base_size * 1.8))
        self.font_medium = pygame.font.Font(None, base_size)
        self.font_small = pygame.font.Font(None, int(base_size * 0.75))
        
        # Cores
        self.colors = {
            'background': (0, 0, 0, 180),
            'text': (255, 255, 255),
            'text_highlight': (255, 255, 0),
            'text_success': (0, 255, 0),
            'text_warning': (255, 165, 0),
            'text_error': (255, 0, 0),
            'border': (255, 255, 255, 100)
        }
        
        # Layout responsivo (porcentagens da tela)
        self.panels = {
            'stats': {
                'rect': (0.01, 0.02, 0.25, 0.45),  # x%, y%, w%, h%
                'anchor': 'top_left'
            },
            'controls': {
                'rect': (0.01, 0.88, 0.4, 0.1),
                'anchor': 'bottom_left'
            },
            'status': {
                'rect': (0.75, 0.02, 0.24, 0.12),
                'anchor': 'top_right'
            },
            'signals': {
                'rect': (0.75, 0.16, 0.24, 0.3),
                'anchor': 'top_right'
            }
        }
        
        print(f"HUD inicializado para {screen_width}×{screen_height}")
    
    def resize(self, new_width, new_height):
        """Redimensiona HUD para nova resolução"""
        self.screen_width = new_width
        self.screen_height = new_height
        
        # Recriar superfície
        self.surface = pygame.Surface((new_width, new_height), pygame.SRCALPHA)
        
        # Recriar fontes com novos tamanhos
        base_size = int(min(new_width, new_height) * 0.02)
        
        self.font_large = pygame.font.Font(None, int(base_size * 1.8))
        self.font_medium = pygame.font.Font(None, base_size)
        self.font_small = pygame.font.Font(None, int(base_size * 0.75))
        
        print(f"HUD redimensionado para {new_width}×{new_height}")
    
    def render(self, stats, show_debug=False):
        """Renderiza todo o HUD"""
        # Limpar superfície
        self.surface.fill((0, 0, 0, 0))
        
        # Renderizar painéis
        self._render_stats_panel(stats.get('traffic_stats', {}))
        self._render_controls_panel(stats)
        self._render_status_panel(stats)
        self._render_signals_panel(stats.get('intersection_states', {}))
        
        if show_debug:
            self._render_debug_panel(stats)
        
        # Renderizar superfície na tela OpenGL
        self._blit_to_opengl()
    
    def _render_stats_panel(self, traffic_stats):
        """Renderiza painel de estatísticas de tráfego"""
        panel_rect = self._get_panel_rect('stats')
        
        # Fundo semi-transparente
        self._draw_panel_background(panel_rect)
        
        # Título
        title_y = panel_rect.top + 10
        self._draw_text("ESTATÍSTICAS TRÁFEGO", self.font_medium, 
                       self.colors['text_highlight'], panel_rect.left + 10, title_y)
        
        y_offset = title_y + 35
        
        # Dados por direção
        directions = [
            ('Norte ↑', 'north'),
            ('Sul ↓', 'south'),
            ('Leste →', 'east'),
            ('Oeste ←', 'west')
        ]
        
        for direction_name, direction_key in directions:
            # Título da direção
            self._draw_text(direction_name, self.font_small, 
                           self.colors['text'], panel_rect.left + 15, y_offset)
            y_offset += 25
            
            # Estatísticas (valores placeholder por enquanto)
            stats_data = traffic_stats.get(direction_key, {})
            
            stats_lines = [
                f"  Passaram: {stats_data.get('passed', 0):>3}",
                f"  Esperando: {stats_data.get('waiting', 0):>2}",
                f"  Fila máx: {stats_data.get('max_queue', 0):>2}"
            ]
            
            for line in stats_lines:
                self._draw_text(line, self.font_small, self.colors['text'], 
                              panel_rect.left + 20, y_offset)
                y_offset += 18
            
            y_offset += 8  # Espaçamento entre direções
        
        # Totais gerais
        y_offset += 15
        self._draw_text("TOTAIS GERAIS", self.font_small, 
                       self.colors['text_success'], panel_rect.left + 15, y_offset)
        y_offset += 25
        
        total_cars = sum(stats_data.get('passed', 0) for stats_data in traffic_stats.values())
        self._draw_text(f"Total carros: {total_cars}", self.font_small, 
                       self.colors['text'], panel_rect.left + 20, y_offset)
    
    def _render_controls_panel(self, stats):
        """Renderiza painel de controles"""
        panel_rect = self._get_panel_rect('controls')
        self._draw_panel_background(panel_rect)
        
        controls_text = [
            "CONTROLES 3D ULTRA:",
            f"P-Pausa | R-Reset | W/S-Zoom | A/D-Rot | Q/E-Alt | Mouse-Câmera",
            f"1-5: Carros ({stats.get('car_spawn_rate', 0):.1f}) | 8-9: Pedestres ({stats.get('pedestrian_spawn_rate', 0):.1f})",
            f"[/]: MinGreen | {{/}}: MaxGreen | ;/': Yellow | ,/.: AllRed | ESC-Sair"
        ]
        
        y_offset = panel_rect.top + 8
        for i, line in enumerate(controls_text):
            color = self.colors['text_highlight'] if i == 0 else self.colors['text']
            font = self.font_small if i == 0 else self.font_small
            
            self._draw_text(line, font, color, panel_rect.left + 10, y_offset)
            y_offset += 18
    
    def _render_status_panel(self, stats):
        """Renderiza painel de status"""
        panel_rect = self._get_panel_rect('status')
        self._draw_panel_background(panel_rect)
        
        # Status de simulação
        status_text = "PAUSADO" if stats.get('paused', False) else "EXECUTANDO"
        status_color = self.colors['text_warning'] if stats.get('paused', False) else self.colors['text_success']
        
        self._draw_text("STATUS:", self.font_medium, self.colors['text'], 
                       panel_rect.left + 10, panel_rect.top + 10)
        self._draw_text(status_text, self.font_medium, status_color, 
                       panel_rect.left + 10, panel_rect.top + 35)
        
        # FPS
        fps = stats.get('fps', 0)
        fps_color = self.colors['text_success'] if fps >= 50 else \
                   self.colors['text_warning'] if fps >= 30 else self.colors['text_error']
        
        self._draw_text(f"FPS: {fps:.0f}", self.font_small, fps_color,
                       panel_rect.left + 10, panel_rect.top + 65)
        
        # Resolução
        self._draw_text(f"{self.screen_width}×{self.screen_height}", self.font_small, 
                       self.colors['text'], panel_rect.left + 70, panel_rect.top + 65)
    
    def _render_signals_panel(self, intersection_states):
        """Renderiza painel de estado dos semáforos"""
        panel_rect = self._get_panel_rect('signals')
        self._draw_panel_background(panel_rect)
        
        # Título
        self._draw_text("SEMÁFOROS", self.font_medium, self.colors['text_highlight'],
                       panel_rect.left + 10, panel_rect.top + 10)
        
        y_offset = panel_rect.top + 40
        
        # Semáforos veiculares principais
        vehicle_signals = [
            ('Norte', 'north_1'),
            ('Sul', 'south_1'),
            ('Leste', 'east_1'),
            ('Oeste', 'west_1')
        ]
        
        for direction, signal_key in vehicle_signals:
            signal_data = intersection_states.get(signal_key, {})
            
            # Nome da direção
            self._draw_text(f"{direction}:", self.font_small, self.colors['text'],
                           panel_rect.left + 15, y_offset)
            
            # Estado atual
            phase = signal_data.get('phase', 'unknown')
            time_remaining = signal_data.get('time_remaining', 0)
            
            # Cor baseada no estado
            if 'green' in phase:
                state_color = self.colors['text_success']
            elif 'yellow' in phase:
                state_color = self.colors['text_warning']
            else:
                state_color = self.colors['text_error']
            
            state_text = f"{phase.upper()} ({time_remaining:.1f}s)"
            self._draw_text(state_text, self.font_small, state_color,
                           panel_rect.left + 65, y_offset)
            
            # Barra de progresso mini
            progress = signal_data.get('progress', 0)
            self._draw_mini_progress_bar(panel_rect.left + 15, y_offset + 15, 
                                       100, 4, progress, state_color)
            
            y_offset += 35
        
        # Estatísticas de timing
        timing_config = intersection_states.get('timing_config', {})
        if timing_config:
            y_offset += 10
            self._draw_text("Configuração:", self.font_small, self.colors['text'],
                           panel_rect.left + 15, y_offset)
            y_offset += 20
            
            timing_lines = [
                f"Verde: {timing_config.get('main_min_green', 0):.0f}-{timing_config.get('main_max_green', 0):.0f}s",
                f"Amarelo: {timing_config.get('yellow_time', 0):.1f}s"
            ]
            
            for line in timing_lines:
                self._draw_text(line, self.font_small, self.colors['text'],
                               panel_rect.left + 20, y_offset)
                y_offset += 18
    
    def _render_debug_panel(self, stats):
        """Renderiza painel de debug (F1)"""
        debug_rect = pygame.Rect(self.screen_width * 0.5, self.screen_height * 0.02,
                                self.screen_width * 0.23, self.screen_height * 0.2)
        
        self._draw_panel_background(debug_rect)
        
        self._draw_text("DEBUG INFO", self.font_medium, self.colors['text_warning'],
                       debug_rect.left + 10, debug_rect.top + 10)
        
        # Informações técnicas
        debug_info = [
            f"OpenGL Shaders: {'OK' if stats.get('shader_support', False) else 'FALLBACK'}",
            f"Primitives: {stats.get('primitives_count', 0)}",
            f"Draw calls: {stats.get('draw_calls', 0)}",
            f"Memory: {stats.get('memory_usage', 0):.1f}MB"
        ]
        
        y_offset = debug_rect.top + 40
        for line in debug_info:
            self._draw_text(line, self.font_small, self.colors['text'],
                           debug_rect.left + 10, y_offset)
            y_offset += 18
    
    def _get_panel_rect(self, panel_name):
        """Calcula retângulo do painel baseado na configuração"""
        config = self.panels[panel_name]
        rect_config = config['rect']
        
        x = int(self.screen_width * rect_config[0])
        y = int(self.screen_height * rect_config[1])
        w = int(self.screen_width * rect_config[2])
        h = int(self.screen_height * rect_config[3])
        
        return pygame.Rect(x, y, w, h)
    
    def _draw_panel_background(self, rect):
        """Desenha fundo semi-transparente do painel"""
        # Fundo
        bg_surface = pygame.Surface((rect.width, rect.height), pygame.SRCALPHA)
        bg_surface.fill(self.colors['background'])
        self.surface.blit(bg_surface, rect)
        
        # Borda
        pygame.draw.rect(self.surface, self.colors['border'][:3], rect, 2)
    
    def _draw_text(self, text, font, color, x, y):
        """Desenha texto na superfície"""
        text_surface = font.render(text, True, color)
        self.surface.blit(text_surface, (x, y))
    
    def _draw_mini_progress_bar(self, x, y, width, height, progress, color):
        """Desenha uma mini barra de progresso"""
        # Fundo
        bg_rect = pygame.Rect(x, y, width, height)
        pygame.draw.rect(self.surface, (50, 50, 50), bg_rect)
        
        # Preenchimento
        if progress > 0:
            fill_width = int(width * max(0, min(1, progress)))
            fill_rect = pygame.Rect(x, y, fill_width, height)
            pygame.draw.rect(self.surface, color, fill_rect)
        
        # Borda
        pygame.draw.rect(self.surface, self.colors['border'][:3], bg_rect, 1)
    
    def _blit_to_opengl(self):
        """Renderiza superfície Pygame na tela OpenGL"""
        # Desabilitar funcionalidades 3D temporariamente
        glDisable(GL_DEPTH_TEST)
        glDisable(GL_LIGHTING)
        glDisable(GL_CULL_FACE)
        
        # Configurar projeção 2D
        glMatrixMode(GL_PROJECTION)
        glPushMatrix()
        glLoadIdentity()
        glOrtho(0, self.screen_width, self.screen_height, 0, -1, 1)
        
        glMatrixMode(GL_MODELVIEW)
        glPushMatrix()
        glLoadIdentity()
        
        # Converter superfície para textura
        texture_data = pygame.image.tostring(
            pygame.transform.flip(self.surface, False, True), 
            "RGBA", True)
        
        # Criar e usar textura temporária
        texture_id = glGenTextures(1)
        glBindTexture(GL_TEXTURE_2D, texture_id)
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, self.screen_width, self.screen_height, 
                     0, GL_RGBA, GL_UNSIGNED_BYTE, texture_data)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        
        # Habilitar textura e blending
        glEnable(GL_TEXTURE_2D)
        glEnable(GL_BLEND)
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        
        glColor4f(1.0, 1.0, 1.0, 1.0)
        
        # Desenhar quad com textura
        glBegin(GL_QUADS)
        glTexCoord2f(0, 0); glVertex2f(0, 0)
        glTexCoord2f(1, 0); glVertex2f(self.screen_width, 0)
        glTexCoord2f(1, 1); glVertex2f(self.screen_width, self.screen_height)
        glTexCoord2f(0, 1); glVertex2f(0, self.screen_height)
        glEnd()
        
        # Limpar textura temporária
        glDeleteTextures([texture_id])
        glDisable(GL_TEXTURE_2D)
        
        # Restaurar matrizes
        glPopMatrix()
        glMatrixMode(GL_PROJECTION)
        glPopMatrix()
        glMatrixMode(GL_MODELVIEW)
        
        # Reabilitar funcionalidades 3D
        glEnable(GL_DEPTH_TEST)
        glEnable(GL_LIGHTING)
        glEnable(GL_CULL_FACE)