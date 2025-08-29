"""
Utilitários OpenGL - Shaders, VAO/VBO, Texturas, FBO
===================================================

Sistema moderno de rendering com:
- Carregamento e compilação de shaders GLSL
- Gestão de VAO/VBO para geometria
- Sistema de texturas
- Fallback para pipeline fixo se shaders falharem
"""

import os
from OpenGL.GL import *
from OpenGL.GL.shaders import compileProgram, compileShader
import numpy as np

class GLUtils:
    """Utilitários para operações OpenGL modernas"""
    
    def __init__(self):
        self.shaders = {}
        self.vaos = {}
        self.vbos = {}
        self.textures = {}
        self.current_shader = None
        self.shader_support = False
        
        # Geometrias primitivas pré-computadas
        self.primitive_meshes = {}
        
        # Cache de matrizes para instancing
        self.instance_matrices = []
        self.max_instances = 1000
        
        print("GLUtils inicializado")
    
    def init_shaders(self):
        """Inicializa sistema de shaders com fallback"""
        try:
            # Verificar suporte a shaders
            if not self._check_shader_support():
                print("Shaders não suportados, usando pipeline fixo")
                return False
            
            # Carregar shaders básicos
            shader_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'shaders')
            
            success = True
            success &= self._load_shader('basic', 
                                       os.path.join(shader_dir, 'basic.vert'),
                                       os.path.join(shader_dir, 'basic.frag'))
            
            success &= self._load_shader('unlit',
                                       os.path.join(shader_dir, 'unlit.vert'),
                                       os.path.join(shader_dir, 'unlit.frag'))
            
            if success:
                self.shader_support = True
                print("Shaders carregados com sucesso")
            else:
                print("Falha ao carregar shaders, usando pipeline fixo")
                
            # Criar geometrias primitivas
            self._create_primitive_meshes()
            
            return success
            
        except Exception as e:
            print(f"Erro ao inicializar shaders: {e}")
            return False
    
    def _check_shader_support(self):
        """Verifica se shaders são suportados"""
        try:
            version = glGetString(GL_VERSION).decode('utf-8')
            major, minor = [int(x) for x in version.split()[0].split('.')[:2]]
            
            # Precisamos de pelo menos OpenGL 2.0 para shaders básicos
            return major >= 2
            
        except:
            return False
    
    def _load_shader(self, name, vertex_path, fragment_path):
        """Carrega e compila um programa de shader"""
        try:
            # Ler código dos arquivos
            if os.path.exists(vertex_path) and os.path.exists(fragment_path):
                with open(vertex_path, 'r') as f:
                    vertex_code = f.read()
                with open(fragment_path, 'r') as f:
                    fragment_code = f.read()
            else:
                # Usar shaders padrão embutidos
                vertex_code, fragment_code = self._get_builtin_shader(name)
            
            # Compilar shaders
            vertex_shader = compileShader(vertex_code, GL_VERTEX_SHADER)
            fragment_shader = compileShader(fragment_code, GL_FRAGMENT_SHADER)
            
            # Criar programa
            program = compileProgram(vertex_shader, fragment_shader)
            
            # Armazenar programa e obter localizações de uniformes
            self.shaders[name] = {
                'program': program,
                'uniforms': self._get_uniform_locations(program)
            }
            
            return True
            
        except Exception as e:
            print(f"Erro ao carregar shader '{name}': {e}")
            return False
    
    def _get_builtin_shader(self, name):
        """Retorna shaders padrão embutidos"""
        if name == 'basic':
            vertex = """
            #version 330 core
            layout (location = 0) in vec3 aPos;
            layout (location = 1) in vec3 aNormal;
            layout (location = 2) in mat4 iModel;
            
            uniform mat4 uView;
            uniform mat4 uProj;
            uniform bool uInstanced;
            uniform mat4 uModel;
            
            out vec3 vNormal;
            out vec3 vWorldPos;
            
            void main() {
                mat4 M = uInstanced ? iModel : uModel;
                vec4 worldPos = M * vec4(aPos, 1.0);
                vWorldPos = worldPos.xyz;
                vNormal = mat3(transpose(inverse(M))) * aNormal;
                gl_Position = uProj * uView * worldPos;
            }
            """
            
            fragment = """
            #version 330 core
            in vec3 vNormal;
            in vec3 vWorldPos;
            out vec4 FragColor;
            
            uniform vec3 uLightDir;
            uniform vec3 uAlbedo;
            uniform vec3 uAmbient;
            uniform float uAlpha;
            
            void main() {
                vec3 normal = normalize(vNormal);
                float ndl = max(dot(normal, -normalize(uLightDir)), 0.0);
                vec3 color = uAmbient * uAlbedo + ndl * uAlbedo;
                FragColor = vec4(color, uAlpha);
            }
            """
            
        elif name == 'unlit':
            vertex = """
            #version 330 core
            layout (location = 0) in vec3 aPos;
            layout (location = 2) in mat4 iModel;
            
            uniform mat4 uView;
            uniform mat4 uProj;
            uniform bool uInstanced;
            uniform mat4 uModel;
            
            void main() {
                mat4 M = uInstanced ? iModel : uModel;
                gl_Position = uProj * uView * M * vec4(aPos, 1.0);
            }
            """
            
            fragment = """
            #version 330 core
            out vec4 FragColor;
            
            uniform vec3 uColor;
            uniform float uAlpha;
            
            void main() {
                FragColor = vec4(uColor, uAlpha);
            }
            """
        
        else:
            raise ValueError(f"Shader desconhecido: {name}")
        
        return vertex, fragment
    
    def _get_uniform_locations(self, program):
        """Obtém localizações de todos os uniformes de um shader"""
        uniforms = {}
        
        # Lista de uniformes comuns
        common_uniforms = [
            'uView', 'uProj', 'uModel', 'uInstanced',
            'uLightDir', 'uAlbedo', 'uAmbient', 'uColor', 'uAlpha'
        ]
        
        for uniform_name in common_uniforms:
            location = glGetUniformLocation(program, uniform_name)
            if location != -1:
                uniforms[uniform_name] = location
        
        return uniforms
    
    def use_shader(self, name):
        """Ativa um shader específico"""
        if not self.shader_support or name not in self.shaders:
            # Desativar shaders e usar pipeline fixo
            glUseProgram(0)
            self.current_shader = None
            return False
        
        program = self.shaders[name]['program']
        glUseProgram(program)
        self.current_shader = name
        return True
    
    def set_uniform(self, name, value):
        """Define valor de um uniform no shader atual"""
        if not self.current_shader or self.current_shader not in self.shaders:
            return False
        
        uniforms = self.shaders[self.current_shader]['uniforms']
        
        if name not in uniforms:
            return False
        
        location = uniforms[name]
        
        # Definir uniform baseado no tipo
        if isinstance(value, bool):
            glUniform1i(location, 1 if value else 0)
        elif isinstance(value, int):
            glUniform1i(location, value)
        elif isinstance(value, float):
            glUniform1f(location, value)
        elif isinstance(value, (list, tuple)):
            if len(value) == 3:
                glUniform3f(location, *value)
            elif len(value) == 4:
                glUniform4f(location, *value)
            elif len(value) == 16:  # Matriz 4x4
                glUniformMatrix4fv(location, 1, GL_FALSE, value)
        
        return True
    
    def _create_primitive_meshes(self):
        """Cria meshes primitivos (cubo, esfera, etc.)"""
        # Cubo unitário
        self._create_cube_mesh()
        
        # Cilindro
        self._create_cylinder_mesh()
        
        # Plano
        self._create_plane_mesh()
        
        print(f"Criadas {len(self.primitive_meshes)} geometrias primitivas")
    
    def _create_cube_mesh(self):
        """Cria mesh de cubo unitário com normais"""
        # Vértices do cubo (posição + normal)
        vertices = np.array([
            # Face frontal
            -0.5, -0.5,  0.5,   0.0,  0.0,  1.0,
             0.5, -0.5,  0.5,   0.0,  0.0,  1.0,
             0.5,  0.5,  0.5,   0.0,  0.0,  1.0,
            -0.5,  0.5,  0.5,   0.0,  0.0,  1.0,
            
            # Face traseira
            -0.5, -0.5, -0.5,   0.0,  0.0, -1.0,
            -0.5,  0.5, -0.5,   0.0,  0.0, -1.0,
             0.5,  0.5, -0.5,   0.0,  0.0, -1.0,
             0.5, -0.5, -0.5,   0.0,  0.0, -1.0,
            
            # Face esquerda
            -0.5,  0.5,  0.5,  -1.0,  0.0,  0.0,
            -0.5,  0.5, -0.5,  -1.0,  0.0,  0.0,
            -0.5, -0.5, -0.5,  -1.0,  0.0,  0.0,
            -0.5, -0.5,  0.5,  -1.0,  0.0,  0.0,
            
            # Face direita
             0.5,  0.5,  0.5,   1.0,  0.0,  0.0,
             0.5, -0.5,  0.5,   1.0,  0.0,  0.0,
             0.5, -0.5, -0.5,   1.0,  0.0,  0.0,
             0.5,  0.5, -0.5,   1.0,  0.0,  0.0,
            
            # Face inferior
            -0.5, -0.5, -0.5,   0.0, -1.0,  0.0,
             0.5, -0.5, -0.5,   0.0, -1.0,  0.0,
             0.5, -0.5,  0.5,   0.0, -1.0,  0.0,
            -0.5, -0.5,  0.5,   0.0, -1.0,  0.0,
            
            # Face superior
            -0.5,  0.5, -0.5,   0.0,  1.0,  0.0,
            -0.5,  0.5,  0.5,   0.0,  1.0,  0.0,
             0.5,  0.5,  0.5,   0.0,  1.0,  0.0,
             0.5,  0.5, -0.5,   0.0,  1.0,  0.0
        ], dtype=np.float32)
        
        # Índices
        indices = np.array([
             0,  1,  2,   2,  3,  0,   # Frontal
             4,  5,  6,   6,  7,  4,   # Traseira
             8,  9, 10,  10, 11,  8,   # Esquerda
            12, 13, 14,  14, 15, 12,   # Direita
            16, 17, 18,  18, 19, 16,   # Inferior
            20, 21, 22,  22, 23, 20    # Superior
        ], dtype=np.uint32)
        
        self._create_mesh('cube', vertices, indices)
    
    def _create_cylinder_mesh(self, segments=16):
        """Cria mesh de cilindro"""
        vertices = []
        indices = []
        
        # Vértices do cilindro
        for i in range(segments):
            angle = 2 * np.pi * i / segments
            x = np.cos(angle)
            y = np.sin(angle)
            
            # Vértice inferior
            vertices.extend([x, y, -0.5, x, y, 0.0])
            # Vértice superior
            vertices.extend([x, y, 0.5, x, y, 0.0])
        
        # Centro inferior e superior
        vertices.extend([0.0, 0.0, -0.5, 0.0, 0.0, -1.0])  # Centro inferior
        vertices.extend([0.0, 0.0, 0.5, 0.0, 0.0, 1.0])    # Centro superior
        
        bottom_center = segments * 2
        top_center = segments * 2 + 1
        
        # Índices das faces laterais
        for i in range(segments):
            next_i = (i + 1) % segments
            
            # Face lateral (2 triângulos)
            indices.extend([
                i * 2, i * 2 + 1, next_i * 2 + 1,
                next_i * 2 + 1, next_i * 2, i * 2
            ])
            
            # Face inferior
            indices.extend([bottom_center, next_i * 2, i * 2])
            
            # Face superior
            indices.extend([top_center, i * 2 + 1, next_i * 2 + 1])
        
        vertices = np.array(vertices, dtype=np.float32)
        indices = np.array(indices, dtype=np.uint32)
        
        self._create_mesh('cylinder', vertices, indices)
    
    def _create_plane_mesh(self):
        """Cria mesh de plano unitário"""
        vertices = np.array([
            -0.5, -0.5, 0.0,   0.0, 0.0, 1.0,
             0.5, -0.5, 0.0,   0.0, 0.0, 1.0,
             0.5,  0.5, 0.0,   0.0, 0.0, 1.0,
            -0.5,  0.5, 0.0,   0.0, 0.0, 1.0
        ], dtype=np.float32)
        
        indices = np.array([
            0, 1, 2,
            2, 3, 0
        ], dtype=np.uint32)
        
        self._create_mesh('plane', vertices, indices)
    
    def _create_mesh(self, name, vertices, indices):
        """Cria VAO/VBO para uma mesh"""
        # Gerar VAO
        vao = glGenVertexArrays(1)
        glBindVertexArray(vao)
        
        # Buffer de vértices
        vbo = glGenBuffers(1)
        glBindBuffer(GL_ARRAY_BUFFER, vbo)
        glBufferData(GL_ARRAY_BUFFER, vertices.nbytes, vertices, GL_STATIC_DRAW)
        
        # Buffer de índices
        ebo = glGenBuffers(1)
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo)
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.nbytes, indices, GL_STATIC_DRAW)
        
        # Configurar atributos de vértice
        stride = 6 * 4  # 6 floats por vértice (pos + normal)
        
        # Posição (location 0)
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, stride, ctypes.c_void_p(0))
        glEnableVertexAttribArray(0)
        
        # Normal (location 1)
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, stride, ctypes.c_void_p(12))
        glEnableVertexAttribArray(1)
        
        # Desligar VAO
        glBindVertexArray(0)
        
        # Armazenar mesh
        self.primitive_meshes[name] = {
            'vao': vao,
            'vbo': vbo,
            'ebo': ebo,
            'count': len(indices)
        }
    
    def draw_mesh(self, name, transform_matrix=None, color=(1.0, 1.0, 1.0), alpha=1.0):
        """Desenha uma mesh primitiva"""
        if name not in self.primitive_meshes:
            return False
        
        mesh = self.primitive_meshes[name]
        
        if self.shader_support and self.current_shader:
            # Usar shader moderno
            if transform_matrix is not None:
                self.set_uniform('uModel', transform_matrix)
            self.set_uniform('uAlbedo', color)
            self.set_uniform('uAlpha', alpha)
            self.set_uniform('uInstanced', False)
        else:
            # Pipeline fixo
            if transform_matrix is not None:
                glPushMatrix()
                glMultMatrixf(transform_matrix)
            
            glColor4f(*color, alpha)
        
        # Desenhar mesh
        glBindVertexArray(mesh['vao'])
        glDrawElements(GL_TRIANGLES, mesh['count'], GL_UNSIGNED_INT, None)
        glBindVertexArray(0)
        
        if not (self.shader_support and self.current_shader):
            if transform_matrix is not None:
                glPopMatrix()
        
        return True
    
    def cleanup(self):
        """Limpeza de recursos OpenGL"""
        try:
            # Limpar meshes
            for mesh in self.primitive_meshes.values():
                if glIsVertexArray(mesh['vao']):
                    glDeleteVertexArrays(1, [mesh['vao']])
                if glIsBuffer(mesh['vbo']):
                    glDeleteBuffers(1, [mesh['vbo']])
                if glIsBuffer(mesh['ebo']):
                    glDeleteBuffers(1, [mesh['ebo']])
            
            # Limpar shaders
            for shader_info in self.shaders.values():
                if glIsProgram(shader_info['program']):
                    glDeleteProgram(shader_info['program'])
            
            # Limpar texturas
            for texture_id in self.textures.values():
                if glIsTexture(texture_id):
                    glDeleteTextures([texture_id])
            
            print("GLUtils: recursos limpos")
            
        except Exception as e:
            print(f"Erro ao limpar GLUtils: {e}")

import ctypes