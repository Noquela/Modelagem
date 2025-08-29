"""
Sistema de Renderização 3D
=========================

Renderer moderno com suporte a shaders e fallback para pipeline fixo.
Otimizado para performance com frustum culling e instancing.
"""

import math
import numpy as np
from OpenGL.GL import *
from OpenGL.GLU import *

from scene.types import Pos3, Transform3D, Color, Colors

class Renderer:
    """Sistema de renderização 3D otimizado"""
    
    def __init__(self, gl_utils, shader_support=True):
        self.gl_utils = gl_utils
        self.shader_support = shader_support
        self.current_camera = None
        
        # Estado de renderização
        self.view_matrix = None
        self.projection_matrix = None
        
        # Configurações de iluminação
        self.light_direction = (-0.5, -0.5, -1.0)  # Sol
        self.ambient_color = (0.3, 0.3, 0.3)
        
        # Cache de matrizes para instancing
        self.instance_matrices = []
        self.max_instances = 500
        
        print("Renderer inicializado")
    
    def begin_frame(self):
        """Inicia frame de renderização"""
        if self.shader_support:
            success = self.gl_utils.use_shader('basic')
            if success:
                self._setup_shader_uniforms()
        else:
            self._setup_fixed_pipeline()
    
    def end_frame(self):
        """Finaliza frame de renderização"""
        if self.shader_support:
            glUseProgram(0)
    
    def _setup_shader_uniforms(self):
        """Configura uniformes dos shaders"""
        # Matrizes de transformação
        view_matrix = self._get_view_matrix()
        proj_matrix = self._get_projection_matrix()
        
        if view_matrix is not None:
            self.gl_utils.set_uniform('uView', view_matrix.flatten())
        if proj_matrix is not None:
            self.gl_utils.set_uniform('uProj', proj_matrix.flatten())
        
        # Iluminação
        self.gl_utils.set_uniform('uLightDir', self.light_direction)
        self.gl_utils.set_uniform('uAmbient', self.ambient_color)
    
    def _setup_fixed_pipeline(self):
        """Configura pipeline fixo como fallback"""
        glLoadIdentity()
        # A câmera já aplicou gluLookAt
        
        # Configurar iluminação
        glEnable(GL_LIGHTING)
        glEnable(GL_LIGHT0)
        
        # Posição da luz
        light_pos = [self.light_direction[0] * 100, 
                    self.light_direction[1] * 100, 
                    self.light_direction[2] * 100, 0.0]
        glLightfv(GL_LIGHT0, GL_POSITION, light_pos)
        
        # Cor ambiente
        glLightfv(GL_LIGHT0, GL_AMBIENT, list(self.ambient_color) + [1.0])
        glLightfv(GL_LIGHT0, GL_DIFFUSE, [0.8, 0.8, 0.7, 1.0])
    
    def _get_view_matrix(self):
        """Obtém matriz de visualização (placeholder)"""
        # Em implementação completa, obteria da câmera
        return np.eye(4, dtype=np.float32)
    
    def _get_projection_matrix(self):
        """Obtém matriz de projeção (placeholder)"""
        # Em implementação completa, obteria da configuração de viewport
        return np.eye(4, dtype=np.float32)
    
    def draw_mesh(self, mesh_name: str, 
                  transform_pos: Pos3 = None,
                  transform_rot: Pos3 = None,
                  transform_scale: Pos3 = None,
                  color: tuple = None,
                  alpha: float = 1.0):
        """Desenha uma mesh com transformação"""
        
        if transform_pos is None:
            transform_pos = Pos3(0, 0, 0)
        if transform_rot is None:
            transform_rot = Pos3(0, 0, 0)
        if transform_scale is None:
            transform_scale = Pos3(1, 1, 1)
        if color is None:
            color = Colors.WHITE.as_tuple()
        
        # Aplicar transformação
        if self.shader_support:
            # Criar matriz de transformação
            transform_matrix = self._create_transform_matrix(
                transform_pos, transform_rot, transform_scale)
            
            # Configurar uniformes do shader
            self.gl_utils.set_uniform('uModel', transform_matrix.flatten())
            self.gl_utils.set_uniform('uAlbedo', color)
            self.gl_utils.set_uniform('uAlpha', alpha)
            
        else:
            # Pipeline fixo
            glPushMatrix()
            
            # Aplicar transformações
            glTranslatef(transform_pos.x, transform_pos.y, transform_pos.z)
            
            if transform_rot.z != 0:
                glRotatef(transform_rot.z, 0, 0, 1)
            if transform_rot.y != 0:
                glRotatef(transform_rot.y, 0, 1, 0)
            if transform_rot.x != 0:
                glRotatef(transform_rot.x, 1, 0, 0)
            
            glScalef(transform_scale.x, transform_scale.y, transform_scale.z)
            
            # Definir material
            glColor4f(*color, alpha)
            if alpha < 1.0:
                glEnable(GL_BLEND)
                glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        
        # Desenhar mesh
        success = self.gl_utils.draw_mesh(mesh_name, color=color, alpha=alpha)
        
        if not self.shader_support:
            glPopMatrix()
            if alpha < 1.0:
                glDisable(GL_BLEND)
        
        return success
    
    def _create_transform_matrix(self, pos: Pos3, rot: Pos3, scale: Pos3):
        """Cria matriz de transformação 4x4"""
        # Matriz identidade
        matrix = np.eye(4, dtype=np.float32)
        
        # Escala
        matrix[0, 0] = scale.x
        matrix[1, 1] = scale.y
        matrix[2, 2] = scale.z
        
        # Rotação (ordem ZYX)
        if rot.x != 0 or rot.y != 0 or rot.z != 0:
            rx = math.radians(rot.x)
            ry = math.radians(rot.y)
            rz = math.radians(rot.z)
            
            # Matriz de rotação X
            if rx != 0:
                cos_x, sin_x = math.cos(rx), math.sin(rx)
                rot_x = np.array([
                    [1, 0, 0, 0],
                    [0, cos_x, -sin_x, 0],
                    [0, sin_x, cos_x, 0],
                    [0, 0, 0, 1]
                ], dtype=np.float32)
                matrix = matrix @ rot_x
            
            # Matriz de rotação Y
            if ry != 0:
                cos_y, sin_y = math.cos(ry), math.sin(ry)
                rot_y = np.array([
                    [cos_y, 0, sin_y, 0],
                    [0, 1, 0, 0],
                    [-sin_y, 0, cos_y, 0],
                    [0, 0, 0, 1]
                ], dtype=np.float32)
                matrix = matrix @ rot_y
            
            # Matriz de rotação Z
            if rz != 0:
                cos_z, sin_z = math.cos(rz), math.sin(rz)
                rot_z = np.array([
                    [cos_z, -sin_z, 0, 0],
                    [sin_z, cos_z, 0, 0],
                    [0, 0, 1, 0],
                    [0, 0, 0, 1]
                ], dtype=np.float32)
                matrix = matrix @ rot_z
        
        # Translação
        matrix[0, 3] = pos.x
        matrix[1, 3] = pos.y
        matrix[2, 3] = pos.z
        
        return matrix
    
    def draw_instanced(self, mesh_name: str, transforms: list, colors: list = None):
        """Desenha múltiplas instâncias de uma mesh (otimizado)"""
        if not transforms:
            return
        
        if len(transforms) > self.max_instances:
            # Dividir em lotes se for muitas instâncias
            for i in range(0, len(transforms), self.max_instances):
                batch_transforms = transforms[i:i+self.max_instances]
                batch_colors = colors[i:i+self.max_instances] if colors else None
                self._draw_instanced_batch(mesh_name, batch_transforms, batch_colors)
        else:
            self._draw_instanced_batch(mesh_name, transforms, colors)
    
    def _draw_instanced_batch(self, mesh_name: str, transforms: list, colors: list = None):
        """Desenha um lote de instâncias"""
        # Por simplicidade, fazer loop manual (instancing real seria mais complexo)
        for i, transform in enumerate(transforms):
            if isinstance(transform, Transform3D):
                pos = transform.position
                rot = transform.rotation
                scale = transform.scale
            else:
                # Assumir que é uma tupla/lista (x, y, z)
                pos = Pos3(*transform[:3])
                rot = Pos3(*(transform[3:6] if len(transform) > 3 else [0, 0, 0]))
                scale = Pos3(*(transform[6:9] if len(transform) > 6 else [1, 1, 1]))
            
            color = colors[i] if colors and i < len(colors) else Colors.WHITE.as_tuple()
            
            self.draw_mesh(mesh_name, pos, rot, scale, color)
    
    def set_light_direction(self, direction: tuple):
        """Define direção da luz"""
        self.light_direction = direction
    
    def set_ambient_color(self, color: tuple):
        """Define cor ambiente"""
        self.ambient_color = color
    
    def is_in_frustum(self, position: Pos3, radius: float = 1.0) -> bool:
        """Verificação simples de frustum culling"""
        # Implementação básica - pode ser melhorada
        if self.current_camera:
            return self.current_camera.is_point_in_view(position.x, position.y, position.z, radius)
        return True
    
    def render_debug_info(self, camera):
        """Renderiza informações de debug"""
        if not self.shader_support:
            return
        
        # Usar shader unlit para debug
        if self.gl_utils.use_shader('unlit'):
            # Desenhar eixos de coordenadas
            self._draw_coordinate_axes()
            
            # Voltar para shader básico
            self.gl_utils.use_shader('basic')
    
    def _draw_coordinate_axes(self):
        """Desenha eixos de coordenadas para debug"""
        # Eixo X (vermelho)
        self.gl_utils.set_uniform('uColor', (1.0, 0.0, 0.0))
        self.draw_mesh('cube', 
                      transform_pos=Pos3(5, 0, 0),
                      transform_scale=Pos3(10, 0.1, 0.1))
        
        # Eixo Y (verde) 
        self.gl_utils.set_uniform('uColor', (0.0, 1.0, 0.0))
        self.draw_mesh('cube',
                      transform_pos=Pos3(0, 5, 0),
                      transform_scale=Pos3(0.1, 10, 0.1))
        
        # Eixo Z (azul)
        self.gl_utils.set_uniform('uColor', (0.0, 0.0, 1.0))
        self.draw_mesh('cube',
                      transform_pos=Pos3(0, 0, 5),
                      transform_scale=Pos3(0.1, 0.1, 10))
    
    def get_performance_info(self) -> dict:
        """Retorna informações de performance"""
        return {
            'shader_support': self.shader_support,
            'max_instances': self.max_instances,
            'primitives_available': len(self.gl_utils.primitive_meshes)
        }