"""
Core 3D Engine usando ModernGL e Pygame
Gerencia contexto OpenGL, shaders e renderização básica
"""
import pygame
import moderngl
import numpy as np
from typing import Tuple, Optional, Dict, Any
from ..utils.config import RENDER_CONFIG
from ..utils.math_helpers import create_perspective_matrix


class Engine3D:
    def __init__(self, width: int = None, height: int = None, title: str = "Traffic Simulator 3D"):
        """Inicializa o engine 3D."""
        self.width = width or RENDER_CONFIG['window_width']
        self.height = height or RENDER_CONFIG['window_height']
        self.title = title
        
        # Inicializar Pygame
        pygame.init()
        pygame.display.set_mode((self.width, self.height), pygame.OPENGL | pygame.DOUBLEBUF)
        pygame.display.set_caption(self.title)
        
        # Criar contexto ModernGL
        self.ctx = moderngl.create_context()
        self.ctx.enable(moderngl.DEPTH_TEST)
        self.ctx.enable(moderngl.CULL_FACE)
        
        # Configurar MSAA se disponível
        if RENDER_CONFIG['msaa_samples'] > 1:
            self.ctx.enable(moderngl.BLEND)
        
        # Habilitar depth testing
        self.ctx.enable(moderngl.DEPTH_TEST)
            
        # Shaders básicos
        self.shaders: Dict[str, moderngl.Program] = {}
        self._init_shaders()
        
        # Matrizes de projeção e view
        self.projection_matrix = create_perspective_matrix(
            RENDER_CONFIG['fov'],
            self.width / self.height,
            RENDER_CONFIG['near_plane'],
            RENDER_CONFIG['far_plane']
        )
        
        self.view_matrix = np.eye(4, dtype=np.float32)
        
        # Clock para controle de FPS
        self.clock = pygame.time.Clock()
        self.running = True
        self.frame_count = 0
        self.fps = 0.0
        
        # Performance tracking
        self.render_time = 0.0
        self.vertices_rendered = 0
        self.draw_calls = 0
        
    def _init_shaders(self):
        """Inicializa shaders básicos."""
        # Shader básico para objetos sólidos
        vertex_shader = """
        #version 330 core
        
        layout (location = 0) in vec3 position;
        layout (location = 1) in vec3 normal;
        layout (location = 2) in vec2 texCoord;
        layout (location = 3) in vec3 color;
        
        uniform mat4 model;
        uniform mat4 view;
        uniform mat4 projection;
        uniform mat3 normalMatrix;
        
        out vec3 fragPos;
        out vec3 fragNormal;
        out vec2 fragTexCoord;
        out vec3 fragColor;
        
        void main() {
            fragPos = vec3(model * vec4(position, 1.0));
            fragNormal = normalize(normalMatrix * normal);
            fragTexCoord = texCoord;
            fragColor = color;
            
            gl_Position = projection * view * vec4(fragPos, 1.0);
        }
        """
        
        fragment_shader = """
        #version 330 core
        
        in vec3 fragPos;
        in vec3 fragNormal;
        in vec2 fragTexCoord;
        in vec3 fragColor;
        
        out vec4 FragColor;
        
        uniform vec3 lightPos;
        uniform vec3 lightColor;
        uniform vec3 viewPos;
        uniform float lightIntensity;
        uniform bool useTexture;
        uniform sampler2D textureSampler;
        
        void main() {
            // Ambient
            float ambientStrength = 0.3;
            vec3 ambient = ambientStrength * lightColor;
            
            // Diffuse
            vec3 norm = normalize(fragNormal);
            vec3 lightDir = normalize(lightPos - fragPos);
            float diff = max(dot(norm, lightDir), 0.0);
            vec3 diffuse = diff * lightColor * lightIntensity;
            
            // Specular
            float specularStrength = 0.5;
            vec3 viewDir = normalize(viewPos - fragPos);
            vec3 reflectDir = reflect(-lightDir, norm);
            float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
            vec3 specular = specularStrength * spec * lightColor;
            
            vec3 baseColor = fragColor;
            if (useTexture) {
                baseColor *= texture(textureSampler, fragTexCoord).rgb;
            }
            
            vec3 result = (ambient + diffuse + specular) * baseColor;
            FragColor = vec4(result, 1.0);
        }
        """
        
        self.shaders['basic'] = self.ctx.program(
            vertex_shader=vertex_shader,
            fragment_shader=fragment_shader
        )
        
        # Shader para instanced rendering (múltiplos carros)
        instanced_vertex = """
        #version 330 core
        
        layout (location = 0) in vec3 position;
        layout (location = 1) in vec3 normal;
        layout (location = 2) in vec2 texCoord;
        
        // Instanced attributes
        layout (location = 3) in mat4 instanceModel;
        layout (location = 7) in vec3 instanceColor;
        
        uniform mat4 view;
        uniform mat4 projection;
        
        out vec3 fragPos;
        out vec3 fragNormal;
        out vec2 fragTexCoord;
        out vec3 fragColor;
        
        void main() {
            mat3 normalMatrix = mat3(transpose(inverse(instanceModel)));
            
            fragPos = vec3(instanceModel * vec4(position, 1.0));
            fragNormal = normalize(normalMatrix * normal);
            fragTexCoord = texCoord;
            fragColor = instanceColor;
            
            gl_Position = projection * view * vec4(fragPos, 1.0);
        }
        """
        
        self.shaders['instanced'] = self.ctx.program(
            vertex_shader=instanced_vertex,
            fragment_shader=fragment_shader
        )
        
        # Shader simples para UI/overlay
        ui_vertex = """
        #version 330 core
        
        layout (location = 0) in vec2 position;
        layout (location = 1) in vec2 texCoord;
        
        uniform mat4 projection;
        
        out vec2 fragTexCoord;
        
        void main() {
            fragTexCoord = texCoord;
            gl_Position = projection * vec4(position, 0.0, 1.0);
        }
        """
        
        ui_fragment = """
        #version 330 core
        
        in vec2 fragTexCoord;
        out vec4 FragColor;
        
        uniform vec4 color;
        uniform bool useTexture;
        uniform sampler2D textureSampler;
        
        void main() {
            if (useTexture) {
                FragColor = texture(textureSampler, fragTexCoord) * color;
            } else {
                FragColor = color;
            }
        }
        """
        
        self.shaders['ui'] = self.ctx.program(
            vertex_shader=ui_vertex,
            fragment_shader=ui_fragment
        )
    
    def create_buffer(self, data: np.ndarray, usage: str = 'static') -> moderngl.Buffer:
        """Cria buffer OpenGL a partir de dados numpy."""
        usage_flags = {
            'static': moderngl.STATIC,
            'dynamic': moderngl.DYNAMIC,
            'stream': moderngl.STREAM
        }
        return self.ctx.buffer(data.astype(np.float32).tobytes())
    
    def create_vertex_array(self, vertex_buffer: moderngl.Buffer, 
                           index_buffer: Optional[moderngl.Buffer] = None,
                           format_string: str = "3f 3f 2f 3f") -> moderngl.VertexArray:
        """
        Cria Vertex Array Object.
        format_string: formato dos vértices (posição, normal, texcoord, cor)
        """
        if index_buffer:
            return self.ctx.vertex_array(self.shaders['basic'], [(vertex_buffer, format_string)], index_buffer)
        else:
            return self.ctx.vertex_array(self.shaders['basic'], [(vertex_buffer, format_string)])
    
    def create_texture(self, width: int, height: int, data: Optional[bytes] = None) -> moderngl.Texture:
        """Cria textura OpenGL."""
        texture = self.ctx.texture((width, height), 3)  # RGB
        if data:
            texture.write(data)
        return texture
    
    def clear(self, color: Tuple[float, float, float, float] = (0.529, 0.808, 0.922, 1.0)):
        """Limpa buffers de cor e profundidade."""
        self.ctx.clear(*color)
        self.draw_calls = 0
        self.vertices_rendered = 0
    
    def set_view_matrix(self, view_matrix: np.ndarray):
        """Define matriz de view (câmera)."""
        self.view_matrix = view_matrix.astype(np.float32)
    
    def set_projection_matrix(self, projection_matrix: np.ndarray):
        """Define matriz de projeção."""
        self.projection_matrix = projection_matrix.astype(np.float32)
    
    def render_object(self, vao: moderngl.VertexArray, model_matrix: np.ndarray,
                     shader_name: str = 'basic', uniforms: Dict[str, Any] = None):
        """Renderiza um objeto usando shader especificado."""
        shader = self.shaders[shader_name]
        
        # Configurar matrizes
        if 'model' in shader:
            shader['model'].write(model_matrix.astype(np.float32).tobytes())
        if 'view' in shader:
            shader['view'].write(self.view_matrix.tobytes())
        if 'projection' in shader:
            shader['projection'].write(self.projection_matrix.tobytes())
        
        # Normal matrix para iluminação correta
        if 'normalMatrix' in shader:
            normal_matrix = np.linalg.inv(model_matrix[:3, :3]).T
            shader['normalMatrix'].write(normal_matrix.astype(np.float32).tobytes())
        
        # Uniforms customizados
        if uniforms:
            for name, value in uniforms.items():
                if name in shader:
                    if isinstance(value, (int, float)):
                        shader[name].value = value
                    elif isinstance(value, (tuple, list, np.ndarray)):
                        shader[name].write(np.array(value, dtype=np.float32).tobytes())
        
        # Renderizar
        vao.render()
        self.draw_calls += 1
    
    def render_instanced(self, vao: moderngl.VertexArray, instance_count: int,
                        uniforms: Dict[str, Any] = None):
        """Renderiza múltiplas instâncias de um objeto."""
        shader = self.shaders['instanced']
        
        # Configurar matrizes
        if 'view' in shader:
            shader['view'].write(self.view_matrix.tobytes())
        if 'projection' in shader:
            shader['projection'].write(self.projection_matrix.tobytes())
        
        # Uniforms customizados
        if uniforms:
            for name, value in uniforms.items():
                if name in shader:
                    if isinstance(value, (int, float)):
                        shader[name].value = value
                    elif isinstance(value, (tuple, list, np.ndarray)):
                        shader[name].write(np.array(value, dtype=np.float32).tobytes())
        
        # Renderizar instâncias
        vao.render(instances=instance_count)
        self.draw_calls += 1
        self.vertices_rendered += instance_count
    
    def present(self):
        """Apresenta frame renderizado."""
        pygame.display.flip()
        
        # Atualizar estatísticas
        self.frame_count += 1
        self.fps = self.clock.get_fps()
        
        # Controlar FPS
        self.clock.tick(RENDER_CONFIG['target_fps'])
    
    def handle_events(self):
        """Processa eventos do Pygame."""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
                return False
            elif event.type == pygame.VIDEORESIZE:
                self.width, self.height = event.size
                self.ctx.viewport = (0, 0, self.width, self.height)
                # Atualizar matriz de projeção
                self.projection_matrix = create_perspective_matrix(
                    RENDER_CONFIG['fov'],
                    self.width / self.height,
                    RENDER_CONFIG['near_plane'],
                    RENDER_CONFIG['far_plane']
                )
        return True
    
    def get_render_stats(self) -> Dict[str, Any]:
        """Retorna estatísticas de renderização."""
        return {
            'fps': self.fps,
            'frame_count': self.frame_count,
            'draw_calls': self.draw_calls,
            'vertices_rendered': self.vertices_rendered,
            'render_time': self.render_time,
            'resolution': (self.width, self.height),
        }
    
    def resize(self, width: int, height: int):
        """Redimensiona viewport."""
        self.width = width
        self.height = height
        self.ctx.viewport = (0, 0, width, height)
        
        # Atualizar matriz de projeção
        self.projection_matrix = create_perspective_matrix(
            RENDER_CONFIG['fov'],
            width / height,
            RENDER_CONFIG['near_plane'],
            RENDER_CONFIG['far_plane']
        )
    
    def cleanup(self):
        """Limpa recursos."""
        pygame.quit()
    
    def __enter__(self):
        """Context manager entry."""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.cleanup()