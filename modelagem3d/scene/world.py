"""
Mundo estático - estruturas do cruzamento
========================================

Renderiza as estruturas fixas da cena:
- Estradas e calçadas
- Faixas de pedestres
- Skybox simples
- Elementos decorativos
"""

from scene.types import Pos3, Colors, Material

class World:
    """Mundo estático do simulador"""
    
    def __init__(self, renderer):
        self.renderer = renderer
        
        # Configurações do mundo
        self.intersection_size = 20.0
        self.road_width = 7.0  # 2 faixas de 3.5m cada
        self.road_length = 100.0
        self.sidewalk_width = 4.0
        self.sidewalk_height = 0.3
        
        print("Mundo estático inicializado")
    
    def render(self):
        """Renderiza todas as estruturas estáticas"""
        self._render_ground()
        self._render_roads()
        self._render_sidewalks()
        self._render_crosswalks()
        self._render_road_markings()
    
    def _render_ground(self):
        """Renderiza o plano de fundo (grama)"""
        # Plano de fundo grande
        ground_size = 200.0
        self.renderer.draw_mesh('plane',
                               transform_pos=Pos3(0, 0, -0.1),
                               transform_scale=Pos3(ground_size, ground_size, 1),
                               color=Colors.GRASS.as_tuple())
    
    def _render_roads(self):
        """Renderiza as estradas"""
        # Estrada norte-sul
        self.renderer.draw_mesh('cube',
                               transform_pos=Pos3(0, 0, 0.1),
                               transform_scale=Pos3(self.road_width, self.road_length, 0.2),
                               color=Colors.ASPHALT.as_tuple())
        
        # Estrada leste-oeste  
        self.renderer.draw_mesh('cube',
                               transform_pos=Pos3(0, 0, 0.1),
                               transform_scale=Pos3(self.road_length, self.road_width, 0.2),
                               color=Colors.ASPHALT.as_tuple())
        
        # Área central do cruzamento
        self.renderer.draw_mesh('cube',
                               transform_pos=Pos3(0, 0, 0.1),
                               transform_scale=Pos3(self.intersection_size, self.intersection_size, 0.2),
                               color=Colors.ASPHALT.as_tuple())
    
    def _render_sidewalks(self):
        """Renderiza as calçadas"""
        sidewalk_positions = [
            # Calçadas dos cantos
            Pos3(-15, -15, self.sidewalk_height/2),  # Sudoeste
            Pos3(15, -15, self.sidewalk_height/2),   # Sudeste
            Pos3(-15, 15, self.sidewalk_height/2),   # Noroeste
            Pos3(15, 15, self.sidewalk_height/2),    # Nordeste
        ]
        
        for pos in sidewalk_positions:
            self.renderer.draw_mesh('cube',
                                   transform_pos=pos,
                                   transform_scale=Pos3(8, 8, self.sidewalk_height),
                                   color=Colors.CONCRETE.as_tuple())
    
    def _render_crosswalks(self):
        """Renderiza as faixas de pedestres"""
        # Faixas horizontais (norte-sul)
        for y_offset in [-3, 3]:
            for x in range(-12, 13, 3):
                self.renderer.draw_mesh('cube',
                                       transform_pos=Pos3(x, y_offset, 0.21),
                                       transform_scale=Pos3(2, 1.2, 0.02),
                                       color=Colors.WHITE.as_tuple())
        
        # Faixas verticais (leste-oeste)
        for x_offset in [-3, 3]:
            for y in range(-12, 13, 3):
                self.renderer.draw_mesh('cube',
                                       transform_pos=Pos3(x_offset, y, 0.21),
                                       transform_scale=Pos3(1.2, 2, 0.02),
                                       color=Colors.WHITE.as_tuple())
    
    def _render_road_markings(self):
        """Renderiza marcações das estradas"""
        # Linhas divisórias centrais (tracejadas)
        
        # Linha central norte-sul
        for y in range(-40, 41, 8):
            if abs(y) > self.intersection_size/2:  # Não desenhar no cruzamento
                self.renderer.draw_mesh('cube',
                                       transform_pos=Pos3(0, y, 0.21),
                                       transform_scale=Pos3(0.2, 4, 0.02),
                                       color=Colors.YELLOW.as_tuple())
        
        # Linha central leste-oeste
        for x in range(-40, 41, 8):
            if abs(x) > self.intersection_size/2:  # Não desenhar no cruzamento
                self.renderer.draw_mesh('cube',
                                       transform_pos=Pos3(x, 0, 0.21),
                                       transform_scale=Pos3(4, 0.2, 0.02),
                                       color=Colors.YELLOW.as_tuple())
        
        # Linhas de parada (stop lines)
        stop_line_distance = self.intersection_size/2 + 2
        
        # Norte
        self.renderer.draw_mesh('cube',
                               transform_pos=Pos3(0, stop_line_distance, 0.21),
                               transform_scale=Pos3(self.road_width, 0.3, 0.02),
                               color=Colors.WHITE.as_tuple())
        
        # Sul
        self.renderer.draw_mesh('cube',
                               transform_pos=Pos3(0, -stop_line_distance, 0.21),
                               transform_scale=Pos3(self.road_width, 0.3, 0.02),
                               color=Colors.WHITE.as_tuple())
        
        # Leste
        self.renderer.draw_mesh('cube',
                               transform_pos=Pos3(stop_line_distance, 0, 0.21),
                               transform_scale=Pos3(0.3, self.road_width, 0.02),
                               color=Colors.WHITE.as_tuple())
        
        # Oeste
        self.renderer.draw_mesh('cube',
                               transform_pos=Pos3(-stop_line_distance, 0, 0.21),
                               transform_scale=Pos3(0.3, self.road_width, 0.02),
                               color=Colors.WHITE.as_tuple())