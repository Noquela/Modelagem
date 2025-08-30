"""
Simple OBJ loader for loading 3D models into OpenGL display lists
"""
import os
from OpenGL.GL import *

class OBJLoader:
    def __init__(self):
        self.models = {}  # Cache de modelos carregados
        
    def load_obj(self, filepath):
        """Carrega um arquivo OBJ e retorna display list"""
        if not os.path.exists(filepath):
            print(f"Arquivo não encontrado: {filepath}")
            return None
            
        if filepath in self.models:
            return self.models[filepath]
            
        vertices = []
        normals = []
        faces = []
        
        try:
            with open(filepath, 'r') as file:
                for line in file:
                    parts = line.strip().split()
                    if not parts:
                        continue
                        
                    if parts[0] == 'v':  # Vértice
                        vertices.append([float(parts[1]), float(parts[2]), float(parts[3])])
                    elif parts[0] == 'vn':  # Normal
                        normals.append([float(parts[1]), float(parts[2]), float(parts[3])])
                    elif parts[0] == 'f':  # Face
                        face = []
                        for i in range(1, len(parts)):
                            vertex_data = parts[i].split('/')
                            # OBJ usa índices baseados em 1, OpenGL usa 0
                            vertex_index = int(vertex_data[0]) - 1
                            normal_index = int(vertex_data[2]) - 1 if len(vertex_data) > 2 and vertex_data[2] else vertex_index
                            face.append((vertex_index, normal_index))
                        faces.append(face)
        except Exception as e:
            print(f"Erro ao carregar {filepath}: {e}")
            return None
        
        # Criar display list
        display_list = glGenLists(1)
        glNewList(display_list, GL_COMPILE)
        
        glBegin(GL_TRIANGLES)
        for face in faces:
            for vertex_index, normal_index in face:
                if normal_index < len(normals):
                    glNormal3fv(normals[normal_index])
                if vertex_index < len(vertices):
                    glVertex3fv(vertices[vertex_index])
        glEnd()
        
        glEndList()
        
        self.models[filepath] = display_list
        print(f"Modelo carregado: {filepath} ({len(vertices)} vértices, {len(faces)} faces)")
        return display_list
    
    def render_model(self, display_list):
        """Renderiza um modelo usando display list"""
        if display_list:
            glCallList(display_list)
    
    def cleanup(self):
        """Limpa todos os display lists"""
        for display_list in self.models.values():
            glDeleteLists(display_list, 1)
        self.models.clear()