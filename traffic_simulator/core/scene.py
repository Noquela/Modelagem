"""
Sistema de gerenciamento de cena 3D
Organiza objetos, iluminação e renderização
"""
import numpy as np
import moderngl
from typing import List, Dict, Any, Optional, Tuple
from ..utils.config import SCENE_CONFIG, RENDER_CONFIG
from ..utils.math_helpers import (
    create_translation_matrix, 
    create_scale_matrix, 
    create_road_lines
)


class SceneObject:
    """Representa um objeto na cena 3D."""
    
    def __init__(self, name: str, vertices: np.ndarray, indices: Optional[np.ndarray] = None,
                 colors: Optional[np.ndarray] = None, normals: Optional[np.ndarray] = None):
        self.name = name
        self.vertices = vertices.astype(np.float32)
        self.indices = indices.astype(np.uint32) if indices is not None else None
        self.colors = colors.astype(np.float32) if colors is not None else None
        self.normals = normals.astype(np.float32) if normals is not None else None
        
        # Transformações
        self.position = np.array([0.0, 0.0, 0.0], dtype=np.float32)
        self.rotation = np.array([0.0, 0.0, 0.0], dtype=np.float32)
        self.scale = np.array([1.0, 1.0, 1.0], dtype=np.float32)
        
        # Estados
        self.visible = True
        self.dirty = True  # Precisa atualizar buffers
        
        # OpenGL objects (criados quando necessário)
        self.vao: Optional[moderngl.VertexArray] = None
        self.vertex_buffer: Optional[moderngl.Buffer] = None
        self.index_buffer: Optional[moderngl.Buffer] = None
        
    def get_model_matrix(self) -> np.ndarray:
        """Retorna matriz modelo do objeto."""
        from ..utils.math_helpers import create_rotation_matrix
        
        translation = create_translation_matrix(*self.position)
        rotation = create_rotation_matrix(*self.rotation)
        scale = create_scale_matrix(*self.scale)
        
        return translation @ rotation @ scale
    
    def set_position(self, x: float, y: float, z: float):
        """Define posição do objeto."""
        self.position = np.array([x, y, z], dtype=np.float32)
    
    def set_rotation(self, x: float, y: float, z: float):
        """Define rotação do objeto (radianos)."""
        self.rotation = np.array([x, y, z], dtype=np.float32)
    
    def set_scale(self, x: float, y: float, z: float):
        """Define escala do objeto."""
        self.scale = np.array([x, y, z], dtype=np.float32)


class Scene3D:
    """Gerenciador de cena 3D."""
    
    def __init__(self, engine_ctx: moderngl.Context):
        self.ctx = engine_ctx
        self.objects: Dict[str, SceneObject] = {}
        self.lights: List[Dict[str, Any]] = []
        
        # Configurações de iluminação
        self.ambient_light = np.array([0.3, 0.3, 0.3], dtype=np.float32)
        self.main_light = {
            'position': np.array([10.0, 20.0, 10.0], dtype=np.float32),
            'color': np.array([1.0, 1.0, 0.9], dtype=np.float32),
            'intensity': 0.8
        }
        
        # Estatísticas
        self.objects_rendered = 0
        self.vertices_rendered = 0
        
        # Criar geometria da cena
        self._create_scene_geometry()
    
    def _create_scene_geometry(self):
        """Cria geometria básica da cena (ruas, grama, etc)."""
        world_size = SCENE_CONFIG['world_size']
        main_road_width = SCENE_CONFIG['main_road_width']
        cross_road_width = SCENE_CONFIG['cross_road_width']
        
        # === GRAMA (chão) ===
        grass_vertices = [
            [-world_size/2, 0, -world_size/2, 0, 1, 0, 0, 0, *SCENE_CONFIG['grass_color']],
            [world_size/2,  0, -world_size/2, 0, 1, 0, 1, 0, *SCENE_CONFIG['grass_color']],
            [world_size/2,  0,  world_size/2, 0, 1, 0, 1, 1, *SCENE_CONFIG['grass_color']],
            [-world_size/2, 0,  world_size/2, 0, 1, 0, 0, 1, *SCENE_CONFIG['grass_color']],
        ]
        
        grass_vertices_array = np.array(grass_vertices, dtype=np.float32)
        grass_indices = np.array([0, 1, 2, 0, 2, 3], dtype=np.uint32)
        
        # Temporariamente comentado para evitar spam de VAO warnings
        # print(f"Debug: Grass vertices shape: {grass_vertices_array.shape}")
        
        self.add_object('grass', grass_vertices_array, grass_indices)
        
        # === RUA HORIZONTAL (principal, duas mãos) ===
        road_y = 0.01  # Ligeiramente acima da grama
        
        horizontal_road_vertices = np.array([
            [-world_size/2, road_y, -main_road_width/2, 0, 1, 0, 0, 0, *SCENE_CONFIG['road_color']],
            [world_size/2,  road_y, -main_road_width/2, 0, 1, 0, 1, 0, *SCENE_CONFIG['road_color']],
            [world_size/2,  road_y,  main_road_width/2, 0, 1, 0, 1, 1, *SCENE_CONFIG['road_color']],
            [-world_size/2, road_y,  main_road_width/2, 0, 1, 0, 0, 1, *SCENE_CONFIG['road_color']],
        ], dtype=np.float32)
        
        road_indices = np.array([0, 1, 2, 0, 2, 3], dtype=np.uint32)
        
        self.add_object('horizontal_road', horizontal_road_vertices, road_indices)
        
        # === RUA VERTICAL (mão única) ===
        vertical_road_vertices = np.array([
            [-cross_road_width/2, road_y, -world_size/2, 0, 1, 0, 0, 0, *SCENE_CONFIG['road_color']],
            [cross_road_width/2,  road_y, -world_size/2, 0, 1, 0, 1, 0, *SCENE_CONFIG['road_color']],
            [cross_road_width/2,  road_y,  world_size/2, 0, 1, 0, 1, 1, *SCENE_CONFIG['road_color']],
            [-cross_road_width/2, road_y,  world_size/2, 0, 1, 0, 0, 1, *SCENE_CONFIG['road_color']],
        ], dtype=np.float32)
        
        self.add_object('vertical_road', vertical_road_vertices, road_indices)
        
        # === LINHAS DA ESTRADA ===
        self._create_road_lines()
    
    def _create_road_lines(self):
        """Cria linhas centrais das estradas."""
        line_y = 0.02  # Acima da estrada
        line_width = 0.2
        line_spacing = 4.0
        world_size = SCENE_CONFIG['world_size']
        
        # Linhas horizontais (centro da rua principal)
        line_count = int(world_size / line_spacing)
        line_vertices = []
        line_indices = []
        
        vertex_offset = 0
        for i in range(line_count):
            x_start = -world_size/2 + i * line_spacing
            x_end = x_start + line_spacing * 0.6  # 60% linha, 40% espaço
            
            # Pular área da intersecção
            if -4 <= x_start <= 4 or -4 <= x_end <= 4:
                continue
            
            vertices = np.array([
                [x_start, line_y, -line_width/2, 0, 1, 0, 0, 0, *SCENE_CONFIG['line_color']],
                [x_end,   line_y, -line_width/2, 0, 1, 0, 1, 0, *SCENE_CONFIG['line_color']],
                [x_end,   line_y,  line_width/2, 0, 1, 0, 1, 1, *SCENE_CONFIG['line_color']],
                [x_start, line_y,  line_width/2, 0, 1, 0, 0, 1, *SCENE_CONFIG['line_color']],
            ], dtype=np.float32)
            
            indices = np.array([0, 1, 2, 0, 2, 3], dtype=np.uint32) + vertex_offset
            
            line_vertices.append(vertices)
            line_indices.append(indices)
            vertex_offset += 4
        
        if line_vertices:
            all_line_vertices = np.vstack(line_vertices)
            all_line_indices = np.concatenate(line_indices)
            self.add_object('road_lines', all_line_vertices, all_line_indices)
    
    def add_object(self, name: str, vertices: np.ndarray, 
                   indices: Optional[np.ndarray] = None, 
                   colors: Optional[np.ndarray] = None,
                   normals: Optional[np.ndarray] = None) -> SceneObject:
        """Adiciona objeto à cena."""
        obj = SceneObject(name, vertices, indices, colors, normals)
        self.objects[name] = obj
        return obj
    
    def remove_object(self, name: str):
        """Remove objeto da cena."""
        if name in self.objects:
            obj = self.objects[name]
            # Limpar recursos OpenGL
            if obj.vao:
                obj.vao.release()
            if obj.vertex_buffer:
                obj.vertex_buffer.release()
            if obj.index_buffer:
                obj.index_buffer.release()
            del self.objects[name]
    
    def get_object(self, name: str) -> Optional[SceneObject]:
        """Retorna objeto por nome."""
        return self.objects.get(name)
    
    def _ensure_object_buffers(self, obj: SceneObject, shader: moderngl.Program):
        """Garante que buffers OpenGL do objeto estejam criados."""
        if obj.vao is None or obj.dirty:
            # Preparar dados de vértices
            # Formato: posição (3f) + normal (3f) + texcoord (2f) + cor (3f)
            vertex_data = obj.vertices
            
            # Criar buffer de vértices
            if obj.vertex_buffer:
                obj.vertex_buffer.release()
            obj.vertex_buffer = self.ctx.buffer(vertex_data.tobytes())
            
            # Criar buffer de índices se necessário
            if obj.indices is not None:
                if obj.index_buffer:
                    obj.index_buffer.release()
                obj.index_buffer = self.ctx.buffer(obj.indices.tobytes())
            
            # Criar VAO
            if obj.vao:
                obj.vao.release()
            
            vertex_format = "3f 3f 2f 3f"  # pos, normal, texcoord, color
            try:
                if obj.indices is not None:
                    obj.vao = self.ctx.vertex_array(
                        shader, 
                        [(obj.vertex_buffer, vertex_format)],
                        obj.index_buffer
                    )
                else:
                    obj.vao = self.ctx.vertex_array(
                        shader,
                        [(obj.vertex_buffer, vertex_format)]
                    )
            except Exception as e:
                # Silenciar warnings de VAO para não spammar console
                # print(f"Warning: Failed to create VAO for {obj.name}: {e}")
                obj.vao = None  # Mark as failed
            
            obj.dirty = False
    
    def render(self, engine, view_matrix: np.ndarray, projection_matrix: np.ndarray,
               camera_pos: np.ndarray, frustum_culling: bool = True):
        """Renderiza todos os objetos da cena."""
        self.objects_rendered = 0
        self.vertices_rendered = 0
        
        # Usar shader básico
        shader = engine.shaders['basic']
        
        # Configurar matrizes globais
        if 'view' in shader:
            shader['view'].write(view_matrix.astype(np.float32).tobytes())
        if 'projection' in shader:
            shader['projection'].write(projection_matrix.astype(np.float32).tobytes())
        
        # Configurar iluminação
        if 'lightPos' in shader:
            shader['lightPos'].write(self.main_light['position'].tobytes())
        if 'lightColor' in shader:
            shader['lightColor'].write(self.main_light['color'].tobytes())
        if 'lightIntensity' in shader:
            shader['lightIntensity'].value = self.main_light['intensity']
        if 'viewPos' in shader:
            shader['viewPos'].write(camera_pos.astype(np.float32).tobytes())
        if 'useTexture' in shader:
            shader['useTexture'].value = False
        
        # Renderizar objetos
        for obj in self.objects.values():
            if not obj.visible:
                continue
            
            # Frustum culling opcional
            if frustum_culling and RENDER_CONFIG['enable_frustum_culling']:
                # Implementação simples - verificar se está muito longe
                obj_distance = np.linalg.norm(obj.position - camera_pos)
                if obj_distance > RENDER_CONFIG['far_plane']:
                    continue
            
            # Garantir buffers
            self._ensure_object_buffers(obj, shader)
            
            # Matriz modelo
            model_matrix = obj.get_model_matrix()
            if 'model' in shader:
                shader['model'].write(model_matrix.tobytes())
            
            # Matriz normal para iluminação
            if 'normalMatrix' in shader:
                normal_matrix = np.linalg.inv(model_matrix[:3, :3]).T
                shader['normalMatrix'].write(normal_matrix.astype(np.float32).tobytes())
            
            # Renderizar apenas se VAO foi criado com sucesso
            if obj.vao is not None:
                obj.vao.render()
                self.objects_rendered += 1
            
            # Contar vértices (aproximado)
            if obj.indices is not None:
                self.vertices_rendered += len(obj.indices)
            else:
                self.vertices_rendered += len(obj.vertices)
    
    def add_light(self, position: np.ndarray, color: np.ndarray, intensity: float = 1.0):
        """Adiciona luz à cena."""
        light = {
            'position': position.astype(np.float32),
            'color': color.astype(np.float32),
            'intensity': intensity
        }
        self.lights.append(light)
        return len(self.lights) - 1  # Retorna índice da luz
    
    def remove_light(self, index: int):
        """Remove luz da cena."""
        if 0 <= index < len(self.lights):
            del self.lights[index]
    
    def set_main_light(self, position: np.ndarray, color: np.ndarray, intensity: float):
        """Define luz principal da cena."""
        self.main_light = {
            'position': position.astype(np.float32),
            'color': color.astype(np.float32),
            'intensity': intensity
        }
    
    def get_render_stats(self) -> Dict[str, Any]:
        """Retorna estatísticas de renderização."""
        return {
            'objects_count': len(self.objects),
            'objects_rendered': self.objects_rendered,
            'vertices_rendered': self.vertices_rendered,
            'lights_count': len(self.lights) + 1,  # +1 para luz principal
        }
    
    def cleanup(self):
        """Limpa recursos da cena."""
        for obj in self.objects.values():
            if obj.vao:
                obj.vao.release()
            if obj.vertex_buffer:
                obj.vertex_buffer.release()
            if obj.index_buffer:
                obj.index_buffer.release()
        
        self.objects.clear()
        self.lights.clear()