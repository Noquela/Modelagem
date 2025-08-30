"""
Renderizador 3D simplificado usando ModernGL puro
Cria geometria simples que funciona sem problemas de VAO
"""
import numpy as np
import moderngl
import pygame
from typing import List


class SimpleRenderer:
    """Renderizador simplificado usando ModernGL."""
    
    def __init__(self, ctx: moderngl.Context):
        self.ctx = ctx
        
        # Criar shader simples
        self.shader = self.ctx.program(
            vertex_shader="""
            #version 330 core
            layout (location = 0) in vec3 position;
            uniform mat4 mvp;
            uniform vec3 color;
            out vec3 fragColor;
            void main() {
                fragColor = color;
                gl_Position = mvp * vec4(position, 1.0);
            }
            """,
            fragment_shader="""
            #version 330 core
            in vec3 fragColor;
            out vec4 FragColor;
            void main() {
                FragColor = vec4(fragColor, 1.0);
            }
            """
        )
        
        # Criar geometrias básicas
        self._create_basic_geometries()
        
    def _create_basic_geometries(self):
        """Cria geometrias básicas uma vez só."""
        # Cubo para carros
        cube_vertices = np.array([
            # Frente
            -0.5, -0.5,  0.5,
             0.5, -0.5,  0.5,
             0.5,  0.5,  0.5,
            -0.5,  0.5,  0.5,
            # Trás
            -0.5, -0.5, -0.5,
            -0.5,  0.5, -0.5,
             0.5,  0.5, -0.5,
             0.5, -0.5, -0.5,
        ], dtype=np.float32)
        
        cube_indices = np.array([
            0, 1, 2, 2, 3, 0,  # frente
            4, 5, 6, 6, 7, 4,  # trás
            4, 0, 3, 3, 5, 4,  # esquerda
            1, 7, 6, 6, 2, 1,  # direita
            3, 2, 6, 6, 5, 3,  # topo
            4, 7, 1, 1, 0, 4,  # base
        ], dtype=np.uint32)
        
        self.cube_vbo = self.ctx.buffer(cube_vertices)
        self.cube_ibo = self.ctx.buffer(cube_indices)
        self.cube_vao = self.ctx.vertex_array(self.shader, [(self.cube_vbo, '3f', 'position')], self.cube_ibo)
        
        # Plano para ruas
        plane_vertices = np.array([
            -1.0, 0.0, -1.0,
             1.0, 0.0, -1.0,
             1.0, 0.0,  1.0,
            -1.0, 0.0,  1.0,
        ], dtype=np.float32)
        
        plane_indices = np.array([0, 1, 2, 2, 3, 0], dtype=np.uint32)
        
        self.plane_vbo = self.ctx.buffer(plane_vertices)
        self.plane_ibo = self.ctx.buffer(plane_indices)
        self.plane_vao = self.ctx.vertex_array(self.shader, [(self.plane_vbo, '3f', 'position')], self.plane_ibo)
        
    def render_cars(self, cars: List, view_matrix: np.ndarray, projection_matrix: np.ndarray):
        """Renderiza carros usando VAOs criados."""
        for car in cars:
            # Criar matriz MVP
            pos = car.physics.position
            
            # Matriz de transformação do carro
            from ..utils.math_helpers import create_translation_matrix, create_rotation_matrix, create_scale_matrix
            
            translation = create_translation_matrix(pos[0], pos[1] + 0.5, pos[2])
            
            # Rotação baseada na direção
            rotation_y = 0.0
            if car.direction.name == 'RIGHT_TO_LEFT':
                rotation_y = np.pi
            elif car.direction.name == 'TOP_TO_BOTTOM':
                rotation_y = -np.pi / 2
            
            rotation = create_rotation_matrix(0, rotation_y, 0)
            scale = create_scale_matrix(2.0, 0.8, 1.2)  # Formato de carro
            
            model_matrix = translation @ rotation @ scale
            mvp_matrix = projection_matrix @ view_matrix @ model_matrix
            
            # Configurar uniforms
            self.shader['mvp'].write(mvp_matrix.astype(np.float32))
            self.shader['color'].write(np.array(car.get_color(), dtype=np.float32))
            
            # Renderizar
            self.cube_vao.render()
        
    def render_roads(self, view_matrix: np.ndarray, projection_matrix: np.ndarray):
        """Renderiza ruas como planos simples."""
        from ..utils.math_helpers import create_translation_matrix, create_scale_matrix
        
        # Grama (chão verde)
        grass_scale = create_scale_matrix(50.0, 1.0, 50.0)
        grass_translation = create_translation_matrix(0, -0.1, 0)
        grass_model = grass_translation @ grass_scale
        mvp_matrix = projection_matrix @ view_matrix @ grass_model
        
        # Renderizar grama
        self.shader['mvp'].write(mvp_matrix.astype(np.float32))
        self.shader['color'].write(np.array([0.133, 0.545, 0.133], dtype=np.float32))  # Verde
        self.plane_vao.render()
        
        # Rua principal horizontal
        road_scale = create_scale_matrix(50.0, 1.0, 8.0)
        road_translation = create_translation_matrix(0, 0.0, 0)
        road_model = road_translation @ road_scale
        mvp_matrix = projection_matrix @ view_matrix @ road_model
        
        self.shader['mvp'].write(mvp_matrix.astype(np.float32))
        self.shader['color'].write(np.array([0.2, 0.2, 0.2], dtype=np.float32))  # Cinza
        self.plane_vao.render()
        
        # Rua vertical (mão única)
        road_v_scale = create_scale_matrix(6.0, 1.0, 50.0)
        road_v_translation = create_translation_matrix(0, 0.0, 0)
        road_v_model = road_v_translation @ road_v_scale
        mvp_matrix = projection_matrix @ view_matrix @ road_v_model
        
        self.shader['mvp'].write(mvp_matrix.astype(np.float32))
        self.shader['color'].write(np.array([0.2, 0.2, 0.2], dtype=np.float32))  # Cinza
        self.plane_vao.render()
    
    def render_traffic_lights(self, traffic_lights, view_matrix: np.ndarray, projection_matrix: np.ndarray):
        """Renderiza semáforos."""
        from ..utils.math_helpers import create_translation_matrix, create_scale_matrix
        
        for light in traffic_lights.get_lights():
            pos = light.position
            
            # Poste vertical
            pole_scale = create_scale_matrix(0.2, 4.0, 0.2)
            pole_translation = create_translation_matrix(pos[0], 2.0, pos[2])
            pole_model = pole_translation @ pole_scale
            mvp_matrix = projection_matrix @ view_matrix @ pole_model
            
            self.shader['mvp'].write(mvp_matrix.astype(np.float32))
            self.shader['color'].write(np.array([0.4, 0.4, 0.4], dtype=np.float32))  # Cinza escuro
            self.cube_vao.render()
            
            # Caixa do semáforo
            box_scale = create_scale_matrix(0.6, 1.8, 0.3)
            box_translation = create_translation_matrix(pos[0] + 3, 4.0, pos[2])
            box_model = box_translation @ box_scale
            mvp_matrix = projection_matrix @ view_matrix @ box_model
            
            self.shader['mvp'].write(mvp_matrix.astype(np.float32))
            self.shader['color'].write(np.array([0.2, 0.2, 0.2], dtype=np.float32))  # Preto
            self.cube_vao.render()
            
            # Luz ativa (simplificada - apenas uma luz baseada no estado)
            state = light.get_current_state()
            light_colors = [
                (1.0, 0.0, 0.0),  # Vermelho
                (1.0, 1.0, 0.0),  # Amarelo
                (0.0, 1.0, 0.0),  # Verde
            ]
            
            # Posição da luz ativa
            light_y_positions = [4.5, 4.0, 3.5]  # Topo, meio, base
            
            light_scale = create_scale_matrix(0.3, 0.3, 0.3)
            light_translation = create_translation_matrix(pos[0] + 3.2, light_y_positions[state], pos[2])
            light_model = light_translation @ light_scale
            mvp_matrix = projection_matrix @ view_matrix @ light_model
            
            self.shader['mvp'].write(mvp_matrix.astype(np.float32))
            self.shader['color'].write(np.array(light_colors[state], dtype=np.float32))
            self.cube_vao.render()