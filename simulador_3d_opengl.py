#!/usr/bin/env python3
"""
Simulador 3D de Tráfego com Pygame + PyOpenGL
============================================

Um simulador completo de cruzamento de tráfego em 3D usando Pygame e PyOpenGL com:
- Representação 3D completa com perspectiva e câmera orbitante
- Sistema avançado de semáforos com indicadores visuais 3D
- Lógica realística de filas e distância de segurança
- Interface 2D sobreposta com estatísticas em tempo real
- Visualização de barras de tempo e gráficos dos semáforos
- Travessias de pedestres em 3D com botões de solicitação

Controles:
    P - Pausar/Retomar simulação
    R - Reiniciar cruzamento
    1-5 - Ajustar taxa de spawn de carros (1=baixa, 5=alta)
    8-9 - Ajustar taxa de spawn de pedestres
    W/S - Zoom in/out da câmera
    A/D - Rotacionar câmera horizontalmente
    Q/E - Mover câmera para cima/baixo
    Mouse - Controle livre da câmera (clique e arraste)
    ESC - Sair

Requisitos:
    pip install pygame PyOpenGL PyOpenGL_accelerate

Autor: Sistema de Simulação de Tráfego 3D
"""

import pygame
import sys
import math
import random
import time
from dataclasses import dataclass
from typing import List, Tuple, Dict, Optional
from enum import Enum

# Importações OpenGL
from OpenGL.GL import *
from OpenGL.GLU import *

# Configurações globais
LARGURA_TELA = 1200
ALTURA_TELA = 800
FPS = 60

# Cores (RGB normalized para OpenGL)
PRETO = (0.0, 0.0, 0.0)
BRANCO = (1.0, 1.0, 1.0)
CINZA = (0.5, 0.5, 0.5)
CINZA_CLARO = (0.8, 0.8, 0.8)
CINZA_ESCURO = (0.3, 0.3, 0.3)
VERDE = (0.0, 1.0, 0.0)
AMARELO = (1.0, 1.0, 0.0)
VERMELHO = (1.0, 0.0, 0.0)
AZUL = (0.0, 0.0, 1.0)
AZUL_CLARO = (0.6, 0.8, 1.0)
LARANJA = (1.0, 0.6, 0.0)
ROXO = (0.8, 0.0, 0.8)
MARROM = (0.6, 0.4, 0.2)
VERDE_ESCURO = (0.0, 0.6, 0.0)

# Configurações 3D
TAMANHO_CRUZAMENTO = 20.0
LARGURA_FAIXA = 3.5
COMPRIMENTO_ESTRADA = 50.0
ALTURA_ESTRADA = 0.2
ALTURA_CALCADA = 0.4
LARGURA_CALCADA = 2.0

# Configurações de objetos
TAMANHO_CARRO = (2.0, 1.0, 0.8)
TAMANHO_PEDESTRE = (0.3, 0.3, 1.6)
ALTURA_SEMAFORO = 4.0
DISTANCIA_SEGURANCA = 3.0

class EstadoSemaforo(Enum):
    VERMELHO = "vermelho"
    AMARELO = "amarelo"
    VERDE = "verde"

class DirecaoVeiculo(Enum):
    NORTE = "norte"
    SUL = "sul"
    LESTE = "leste"
    OESTE = "oeste"

@dataclass
class Posicao3D:
    x: float
    y: float
    z: float

@dataclass
class Rotacao3D:
    x: float = 0.0
    y: float = 0.0
    z: float = 0.0

class Camera3D:
    """Sistema de câmera 3D com controles orbitantes"""
    
    def __init__(self):
        self.distancia = 30.0
        self.angulo_horizontal = 45.0
        self.angulo_vertical = -30.0
        self.alvo = Posicao3D(0, 0, 0)
        
        # Controles de mouse
        self.mouse_ativo = False
        self.ultimo_mouse_x = 0
        self.ultimo_mouse_y = 0
        
        # Limites
        self.distancia_min = 10.0
        self.distancia_max = 60.0
        self.angulo_vertical_min = -80.0
        self.angulo_vertical_max = 10.0
    
    def atualizar_mouse(self, pos_x, pos_y, clicado):
        """Atualiza câmera baseado no movimento do mouse"""
        if clicado:
            if self.mouse_ativo:
                delta_x = pos_x - self.ultimo_mouse_x
                delta_y = pos_y - self.ultimo_mouse_y
                
                self.angulo_horizontal += delta_x * 0.3
                self.angulo_vertical -= delta_y * 0.3
                
                # Aplicar limites
                self.angulo_vertical = max(self.angulo_vertical_min, 
                                         min(self.angulo_vertical_max, self.angulo_vertical))
            
            self.mouse_ativo = True
            self.ultimo_mouse_x = pos_x
            self.ultimo_mouse_y = pos_y
        else:
            self.mouse_ativo = False
    
    def zoom(self, delta):
        """Ajusta o zoom da câmera"""
        self.distancia += delta
        self.distancia = max(self.distancia_min, min(self.distancia_max, self.distancia))
    
    def rotacionar(self, delta_horizontal, delta_vertical):
        """Rotaciona a câmera"""
        self.angulo_horizontal += delta_horizontal
        self.angulo_vertical += delta_vertical
        self.angulo_vertical = max(self.angulo_vertical_min, 
                                 min(self.angulo_vertical_max, self.angulo_vertical))
    
    def aplicar_transformacao(self):
        """Aplica a transformação da câmera ao OpenGL"""
        glLoadIdentity()
        
        # Calcular posição da câmera em coordenadas esféricas
        rad_h = math.radians(self.angulo_horizontal)
        rad_v = math.radians(self.angulo_vertical)
        
        cam_x = self.alvo.x + self.distancia * math.cos(rad_v) * math.sin(rad_h)
        cam_y = self.alvo.y + self.distancia * math.cos(rad_v) * math.cos(rad_h)
        cam_z = self.alvo.z + self.distancia * math.sin(rad_v)
        
        gluLookAt(cam_x, cam_y, cam_z,      # posição da câmera
                 self.alvo.x, self.alvo.y, self.alvo.z,  # ponto alvo
                 0, 0, 1)                   # vetor up

class Utils3D:
    """Utilitários para desenho 3D"""
    
    @staticmethod
    def desenhar_cubo(largura, profundidade, altura, cor):
        """Desenha um cubo/caixa 3D centrado na origem"""
        w, d, h = largura/2, profundidade/2, altura/2
        
        glColor3f(*cor)
        glBegin(GL_QUADS)
        
        # Face frontal
        glVertex3f(-w, -d, -h)
        glVertex3f(w, -d, -h)
        glVertex3f(w, -d, h)
        glVertex3f(-w, -d, h)
        
        # Face traseira
        glVertex3f(-w, d, -h)
        glVertex3f(-w, d, h)
        glVertex3f(w, d, h)
        glVertex3f(w, d, -h)
        
        # Face esquerda
        glVertex3f(-w, -d, -h)
        glVertex3f(-w, -d, h)
        glVertex3f(-w, d, h)
        glVertex3f(-w, d, -h)
        
        # Face direita
        glVertex3f(w, -d, -h)
        glVertex3f(w, d, -h)
        glVertex3f(w, d, h)
        glVertex3f(w, -d, h)
        
        # Face inferior
        glVertex3f(-w, -d, -h)
        glVertex3f(-w, d, -h)
        glVertex3f(w, d, -h)
        glVertex3f(w, -d, -h)
        
        # Face superior
        glVertex3f(-w, -d, h)
        glVertex3f(w, -d, h)
        glVertex3f(w, d, h)
        glVertex3f(-w, d, h)
        
        glEnd()
        
        # Contorno
        glColor3f(0, 0, 0)
        glLineWidth(1)
        glBegin(GL_LINES)
        
        # Arestas da base
        glVertex3f(-w, -d, -h); glVertex3f(w, -d, -h)
        glVertex3f(w, -d, -h); glVertex3f(w, d, -h)
        glVertex3f(w, d, -h); glVertex3f(-w, d, -h)
        glVertex3f(-w, d, -h); glVertex3f(-w, -d, -h)
        
        # Arestas do topo
        glVertex3f(-w, -d, h); glVertex3f(w, -d, h)
        glVertex3f(w, -d, h); glVertex3f(w, d, h)
        glVertex3f(w, d, h); glVertex3f(-w, d, h)
        glVertex3f(-w, d, h); glVertex3f(-w, -d, h)
        
        # Arestas verticais
        glVertex3f(-w, -d, -h); glVertex3f(-w, -d, h)
        glVertex3f(w, -d, -h); glVertex3f(w, -d, h)
        glVertex3f(w, d, -h); glVertex3f(w, d, h)
        glVertex3f(-w, d, -h); glVertex3f(-w, d, h)
        
        glEnd()
    
    @staticmethod
    def desenhar_cilindro(raio, altura, cor, segmentos=16):
        """Desenha um cilindro 3D"""
        glColor3f(*cor)
        
        # Tampa inferior
        glBegin(GL_TRIANGLE_FAN)
        glVertex3f(0, 0, 0)
        for i in range(segmentos + 1):
            angulo = 2 * math.pi * i / segmentos
            x = raio * math.cos(angulo)
            y = raio * math.sin(angulo)
            glVertex3f(x, y, 0)
        glEnd()
        
        # Tampa superior
        glBegin(GL_TRIANGLE_FAN)
        glVertex3f(0, 0, altura)
        for i in range(segmentos + 1):
            angulo = 2 * math.pi * i / segmentos
            x = raio * math.cos(angulo)
            y = raio * math.sin(angulo)
            glVertex3f(x, y, altura)
        glEnd()
        
        # Lateral
        glBegin(GL_QUAD_STRIP)
        for i in range(segmentos + 1):
            angulo = 2 * math.pi * i / segmentos
            x = raio * math.cos(angulo)
            y = raio * math.sin(angulo)
            glVertex3f(x, y, 0)
            glVertex3f(x, y, altura)
        glEnd()
    
    @staticmethod
    def desenhar_barra_3d(largura, altura, profundidade, preenchimento, cor_fundo, cor_preenchimento):
        """Desenha uma barra 3D com preenchimento percentual"""
        # Fundo da barra
        glPushMatrix()
        Utils3D.desenhar_cubo(largura, profundidade, altura, cor_fundo)
        
        # Preenchimento
        if preenchimento > 0:
            glTranslatef(-(largura * (1 - preenchimento)) / 2, 0, 0.01)
            Utils3D.desenhar_cubo(largura * preenchimento, profundidade * 0.8, altura * 1.1, cor_preenchimento)
        
        glPopMatrix()

class SemaforoVeicular:
    """Controla os semáforos para veículos com visualização 3D"""
    
    def __init__(self, posicao: Posicao3D, direcao: DirecaoVeiculo):
        self.posicao = posicao
        self.direcao = direcao
        self.estado = EstadoSemaforo.VERMELHO
        self.tempo_restante = 0
        
        # Tempos configuráveis (em segundos)
        self.tempo_verde = 15.0
        self.tempo_amarelo = 3.0
        self.tempo_vermelho = 18.0
        
        self.tempo_total_ciclo = self.tempo_verde + self.tempo_amarelo + self.tempo_vermelho
        self.iniciar_ciclo()
    
    def iniciar_ciclo(self):
        """Inicia o ciclo do semáforo"""
        self.estado = EstadoSemaforo.VERMELHO
        self.tempo_restante = self.tempo_vermelho
    
    def atualizar(self, dt: float):
        """Atualiza o estado do semáforo baseado no tempo decorrido"""
        self.tempo_restante -= dt
        
        if self.tempo_restante <= 0:
            if self.estado == EstadoSemaforo.VERMELHO:
                self.estado = EstadoSemaforo.VERDE
                self.tempo_restante = self.tempo_verde
            elif self.estado == EstadoSemaforo.VERDE:
                self.estado = EstadoSemaforo.AMARELO
                self.tempo_restante = self.tempo_amarelo
            elif self.estado == EstadoSemaforo.AMARELO:
                self.estado = EstadoSemaforo.VERMELHO
                self.tempo_restante = self.tempo_vermelho
    
    def get_porcentagem_tempo(self) -> float:
        """Retorna a porcentagem do tempo restante no estado atual"""
        if self.estado == EstadoSemaforo.VERMELHO:
            return self.tempo_restante / self.tempo_vermelho
        elif self.estado == EstadoSemaforo.VERDE:
            return self.tempo_restante / self.tempo_verde
        else:  # AMARELO
            return self.tempo_restante / self.tempo_amarelo
    
    def pode_passar(self) -> bool:
        return self.estado == EstadoSemaforo.VERDE
    
    def deve_parar(self) -> bool:
        return self.estado == EstadoSemaforo.VERMELHO
    
    def deve_decidir(self) -> bool:
        return self.estado == EstadoSemaforo.AMARELO
    
    def desenhar(self):
        """Desenha o semáforo em 3D com indicador de tempo"""
        glPushMatrix()
        glTranslatef(self.posicao.x, self.posicao.y, self.posicao.z)
        
        # Poste do semáforo
        Utils3D.desenhar_cubo(0.2, 0.2, ALTURA_SEMAFORO, CINZA_ESCURO)
        
        # Caixa do semáforo
        glTranslatef(0, 0, ALTURA_SEMAFORO/2)
        Utils3D.desenhar_cubo(0.8, 0.6, 1.5, CINZA)
        
        # Luzes do semáforo
        glTranslatef(0, -0.35, 0)
        
        # Luz vermelha
        cor_vermelha = VERMELHO if self.estado == EstadoSemaforo.VERMELHO else CINZA_ESCURO
        glPushMatrix()
        glTranslatef(0, 0, 0.4)
        Utils3D.desenhar_cilindro(0.15, 0.1, cor_vermelha)
        glPopMatrix()
        
        # Luz amarela
        cor_amarela = AMARELO if self.estado == EstadoSemaforo.AMARELO else CINZA_ESCURO
        glPushMatrix()
        glTranslatef(0, 0, 0)
        Utils3D.desenhar_cilindro(0.15, 0.1, cor_amarela)
        glPopMatrix()
        
        # Luz verde
        cor_verde = VERDE if self.estado == EstadoSemaforo.VERDE else CINZA_ESCURO
        glPushMatrix()
        glTranslatef(0, 0, -0.4)
        Utils3D.desenhar_cilindro(0.15, 0.1, cor_verde)
        glPopMatrix()
        
        # Indicador de tempo (barra 3D)
        self._desenhar_indicador_tempo()
        
        glPopMatrix()
    
    def _desenhar_indicador_tempo(self):
        """Desenha o indicador visual do tempo restante"""
        # Posiciona acima do semáforo
        glTranslatef(0, 0, 1.2)
        
        # Determina cor baseada no estado
        if self.estado == EstadoSemaforo.VERMELHO:
            cor = VERMELHO
        elif self.estado == EstadoSemaforo.AMARELO:
            cor = AMARELO
        else:
            cor = VERDE
        
        # Barra de tempo
        porcentagem = self.get_porcentagem_tempo()
        Utils3D.desenhar_barra_3d(2.0, 0.3, 0.2, porcentagem, CINZA_ESCURO, cor)

class SemaforoPedestre:
    """Controla semáforos para pedestres com visualização 3D"""
    
    def __init__(self, posicao: Posicao3D, direcao: str):
        self.posicao = posicao
        self.direcao = direcao
        self.estado = EstadoSemaforo.VERMELHO
        self.tempo_restante = 0
        self.botao_pressionado = False
        self.tempo_travessia = 12.0
    
    def pressionar_botao(self):
        if self.estado == EstadoSemaforo.VERMELHO:
            self.botao_pressionado = True
    
    def ativar_travessia(self):
        if self.botao_pressionado:
            self.estado = EstadoSemaforo.VERDE
            self.tempo_restante = self.tempo_travessia
            self.botao_pressionado = False
    
    def atualizar(self, dt: float):
        if self.estado == EstadoSemaforo.VERDE:
            self.tempo_restante -= dt
            if self.tempo_restante <= 0:
                self.estado = EstadoSemaforo.VERMELHO
    
    def pode_atravessar(self) -> bool:
        return self.estado == EstadoSemaforo.VERDE
    
    def desenhar(self):
        """Desenha o semáforo de pedestre em 3D"""
        glPushMatrix()
        glTranslatef(self.posicao.x, self.posicao.y, self.posicao.z)
        
        # Poste
        Utils3D.desenhar_cubo(0.1, 0.1, 2.5, CINZA_ESCURO)
        
        # Caixa do semáforo
        glTranslatef(0, 0, 1.8)
        Utils3D.desenhar_cubo(0.4, 0.3, 0.6, CINZA)
        
        # Luz
        cor_luz = VERDE if self.pode_atravessar() else VERMELHO
        glTranslatef(0, -0.2, 0)
        Utils3D.desenhar_cilindro(0.1, 0.1, cor_luz)
        
        # Botão
        glTranslatef(0, 0, -0.5)
        cor_botao = AMARELO if self.botao_pressionado else CINZA_CLARO
        Utils3D.desenhar_cilindro(0.05, 0.05, cor_botao)
        
        glPopMatrix()

class Carro:
    """Representa um carro no simulador com comportamento 3D"""
    
    def __init__(self, posicao: Posicao3D, direcao: DirecaoVeiculo, faixa_id: int):
        self.posicao = posicao
        self.posicao_inicial = Posicao3D(posicao.x, posicao.y, posicao.z)
        self.direcao = direcao
        self.faixa_id = faixa_id
        self.velocidade = random.uniform(8, 12)  # unidades por segundo
        self.velocidade_max = self.velocidade
        self.cor = random.choice([AZUL, VERDE, VERMELHO, LARANJA, ROXO])
        self.esperando = False
        self.tempo_espera = 0
        self.completou_travessia = False
        self.rotacao = Rotacao3D()
        
        # Define rotação baseada na direção
        if self.direcao == DirecaoVeiculo.NORTE:
            self.rotacao.z = 0
        elif self.direcao == DirecaoVeiculo.SUL:
            self.rotacao.z = 180
        elif self.direcao == DirecaoVeiculo.LESTE:
            self.rotacao.z = -90
        else:  # OESTE
            self.rotacao.z = 90
        
        # Comportamento
        self.distancia_frenagem = 8.0
        self.aceleracao = 5.0
        self.desaceleracao = 10.0
    
    def atualizar(self, dt: float, semaforo: SemaforoVeicular, carro_frente: Optional['Carro'] = None):
        """Atualiza a posição e comportamento do carro"""
        if self.completou_travessia:
            return
        
        distancia_semaforo = self._calcular_distancia_semaforo(semaforo)
        deve_parar = self._deve_parar_semaforo(semaforo, distancia_semaforo)
        deve_parar_carro = self._deve_parar_carro(carro_frente)
        
        # Lógica de parada
        if deve_parar or deve_parar_carro:
            if not self.esperando:
                self.esperando = True
                self.tempo_espera = 0
            self.tempo_espera += dt
            self.velocidade = max(0, self.velocidade - self.desaceleracao * dt)
        else:
            if self.esperando:
                self.esperando = False
            self.velocidade = min(self.velocidade_max, self.velocidade + self.aceleracao * dt)
        
        # Movimento
        self._mover(dt)
        
        # Verificar se completou a travessia
        self._verificar_travessia_completa()
    
    def _calcular_distancia_semaforo(self, semaforo: SemaforoVeicular) -> float:
        """Calcula a distância até o semáforo"""
        if self.direcao == DirecaoVeiculo.NORTE:
            return self.posicao.y - (TAMANHO_CRUZAMENTO/2)
        elif self.direcao == DirecaoVeiculo.SUL:
            return -(TAMANHO_CRUZAMENTO/2) - self.posicao.y
        elif self.direcao == DirecaoVeiculo.LESTE:
            return self.posicao.x - (TAMANHO_CRUZAMENTO/2)
        else:  # OESTE
            return -(TAMANHO_CRUZAMENTO/2) - self.posicao.x
    
    def _deve_parar_semaforo(self, semaforo: SemaforoVeicular, distancia: float) -> bool:
        """Verifica se deve parar devido ao semáforo"""
        if distancia < 0:  # Já passou do semáforo
            return False
        
        if semaforo.deve_parar():
            return distancia < 10
        
        if semaforo.deve_decidir():
            tempo_para_chegar = distancia / max(self.velocidade, 0.1)
            return tempo_para_chegar > semaforo.tempo_restante or distancia > 6
        
        return False
    
    def _deve_parar_carro(self, carro_frente: Optional['Carro']) -> bool:
        """Verifica se deve parar devido a outro carro"""
        if not carro_frente:
            return False
        
        distancia = self._calcular_distancia_carro(carro_frente)
        return distancia < DISTANCIA_SEGURANCA
    
    def _calcular_distancia_carro(self, outro_carro: 'Carro') -> float:
        """Calcula distância até outro carro"""
        if self.direcao == DirecaoVeiculo.NORTE:
            return outro_carro.posicao.y - self.posicao.y
        elif self.direcao == DirecaoVeiculo.SUL:
            return self.posicao.y - outro_carro.posicao.y
        elif self.direcao == DirecaoVeiculo.LESTE:
            return outro_carro.posicao.x - self.posicao.x
        else:  # OESTE
            return self.posicao.x - outro_carro.posicao.x
    
    def _mover(self, dt: float):
        """Move o carro na direção apropriada"""
        distancia = self.velocidade * dt
        
        if self.direcao == DirecaoVeiculo.NORTE:
            self.posicao.y += distancia
        elif self.direcao == DirecaoVeiculo.SUL:
            self.posicao.y -= distancia
        elif self.direcao == DirecaoVeiculo.LESTE:
            self.posicao.x += distancia
        else:  # OESTE
            self.posicao.x -= distancia
    
    def _verificar_travessia_completa(self):
        """Verifica se o carro completou a travessia"""
        margem = COMPRIMENTO_ESTRADA * 1.2
        if (abs(self.posicao.x) > margem or abs(self.posicao.y) > margem):
            self.completou_travessia = True
    
    def desenhar(self):
        """Desenha o carro em 3D"""
        if self.completou_travessia:
            return
        
        glPushMatrix()
        glTranslatef(self.posicao.x, self.posicao.y, self.posicao.z)
        glRotatef(self.rotacao.z, 0, 0, 1)
        
        Utils3D.desenhar_cubo(TAMANHO_CARRO[0], TAMANHO_CARRO[1], TAMANHO_CARRO[2], self.cor)
        
        glPopMatrix()

class Pedestre:
    """Representa um pedestre no simulador com comportamento 3D"""
    
    def __init__(self, posicao_inicial: Posicao3D, posicao_destino: Posicao3D, direcao_travessia: str):
        self.posicao = posicao_inicial
        self.posicao_inicial = posicao_inicial
        self.posicao_destino = posicao_destino
        self.direcao_travessia = direcao_travessia
        self.velocidade = random.uniform(1.5, 2.5)
        self.cor = random.choice([AZUL, VERDE, VERMELHO, ROXO, LARANJA])
        self.esperando = True
        self.atravessando = False
        self.tempo_espera = 0
        self.completou_travessia = False
    
    def atualizar(self, dt: float, semaforo_pedestre: SemaforoPedestre):
        """Atualiza o comportamento do pedestre"""
        if self.completou_travessia:
            return
        
        if self.esperando:
            # Pressiona o botão ocasionalmente
            if random.random() < 0.005:  # 0.5% chance por frame
                semaforo_pedestre.pressionar_botao()
            
            self.tempo_espera += dt
            
            # Começa a atravessar se o sinal estiver verde
            if semaforo_pedestre.pode_atravessar():
                self.esperando = False
                self.atravessando = True
        
        elif self.atravessando:
            # Move em direção ao destino
            dx = self.posicao_destino.x - self.posicao.x
            dy = self.posicao_destino.y - self.posicao.y
            distancia = math.sqrt(dx**2 + dy**2)
            
            if distancia < 0.5:
                self.completou_travessia = True
            else:
                # Normaliza a direção e move
                dx_norm = dx / distancia
                dy_norm = dy / distancia
                movimento = self.velocidade * dt
                
                self.posicao.x += dx_norm * movimento
                self.posicao.y += dy_norm * movimento
    
    def desenhar(self):
        """Desenha o pedestre em 3D"""
        if self.completou_travessia:
            return
        
        glPushMatrix()
        glTranslatef(self.posicao.x, self.posicao.y, self.posicao.z)
        
        Utils3D.desenhar_cubo(TAMANHO_PEDESTRE[0], TAMANHO_PEDESTRE[1], TAMANHO_PEDESTRE[2], self.cor)
        
        glPopMatrix()

class Faixa:
    """Gerencia uma faixa de trânsito com seus carros em 3D"""
    
    def __init__(self, direcao: DirecaoVeiculo, posicao_spawn: Posicao3D, faixa_id: int):
        self.direcao = direcao
        self.posicao_spawn = posicao_spawn
        self.faixa_id = faixa_id
        self.carros: List[Carro] = []
        self.semaforo = SemaforoVeicular(self._get_posicao_semaforo(), direcao)
        
        # Estatísticas
        self.carros_passaram = 0
        self.carros_esperando = 0
        self.tempo_espera_total = 0
        self.max_fila = 0
    
    def _get_posicao_semaforo(self) -> Posicao3D:
        """Calcula a posição do semáforo para esta faixa"""
        offset = TAMANHO_CRUZAMENTO/2 + 2
        
        if self.direcao == DirecaoVeiculo.NORTE:
            x = -LARGURA_FAIXA if self.faixa_id == 0 else 0
            return Posicao3D(x, -offset, 0)
        elif self.direcao == DirecaoVeiculo.SUL:
            x = LARGURA_FAIXA if self.faixa_id == 0 else 0
            return Posicao3D(x, offset, 0)
        elif self.direcao == DirecaoVeiculo.LESTE:
            y = -LARGURA_FAIXA if self.faixa_id == 0 else 0
            return Posicao3D(-offset, y, 0)
        else:  # OESTE
            y = LARGURA_FAIXA if self.faixa_id == 0 else 0
            return Posicao3D(offset, y, 0)
    
    def spawnar_carro(self):
        """Cria um novo carro na faixa se houver espaço"""
        if not self.carros or self._distancia_ultimo_carro() > DISTANCIA_SEGURANCA * 1.5:
            carro = Carro(
                Posicao3D(self.posicao_spawn.x, self.posicao_spawn.y, ALTURA_ESTRADA + TAMANHO_CARRO[2]/2),
                self.direcao,
                self.faixa_id
            )
            self.carros.append(carro)
    
    def _distancia_ultimo_carro(self) -> float:
        """Calcula a distância do spawn até o último carro"""
        if not self.carros:
            return float('inf')
        
        ultimo = self.carros[-1]
        if self.direcao == DirecaoVeiculo.NORTE:
            return ultimo.posicao.y - self.posicao_spawn.y
        elif self.direcao == DirecaoVeiculo.SUL:
            return self.posicao_spawn.y - ultimo.posicao.y
        elif self.direcao == DirecaoVeiculo.LESTE:
            return ultimo.posicao.x - self.posicao_spawn.x
        else:  # OESTE
            return self.posicao_spawn.x - ultimo.posicao.x
    
    def atualizar(self, dt: float):
        """Atualiza todos os carros na faixa"""
        self.semaforo.atualizar(dt)
        
        # Atualiza carros (do último para o primeiro)
        for i in range(len(self.carros) - 1, -1, -1):
            carro = self.carros[i]
            carro_frente = self.carros[i - 1] if i > 0 else None
            
            carro.atualizar(dt, self.semaforo, carro_frente)
            
            # Remove carros que completaram a travessia
            if carro.completou_travessia:
                if carro.tempo_espera > 0:
                    self.tempo_espera_total += carro.tempo_espera
                self.carros_passaram += 1
                self.carros.pop(i)
        
        # Atualiza estatísticas
        self.carros_esperando = sum(1 for c in self.carros if c.esperando)
        self.max_fila = max(self.max_fila, len(self.carros))
    
    def desenhar(self):
        """Desenha todos os elementos da faixa"""
        # Desenha carros
        for carro in self.carros:
            carro.desenhar()
        
        # Desenha semáforo
        self.semaforo.desenhar()

class Cruzamento:
    """Gerencia todo o sistema de cruzamento em 3D"""
    
    def __init__(self):
        # Criar faixas para cada direção (2 faixas por direção)
        offset = COMPRIMENTO_ESTRADA
        
        self.faixas_norte = [
            Faixa(DirecaoVeiculo.NORTE, Posicao3D(-LARGURA_FAIXA, -offset, 0), 0),
            Faixa(DirecaoVeiculo.NORTE, Posicao3D(0, -offset, 0), 1)
        ]
        
        self.faixas_sul = [
            Faixa(DirecaoVeiculo.SUL, Posicao3D(LARGURA_FAIXA, offset, 0), 0),
            Faixa(DirecaoVeiculo.SUL, Posicao3D(0, offset, 0), 1)
        ]
        
        self.faixas_leste = [
            Faixa(DirecaoVeiculo.LESTE, Posicao3D(-offset, -LARGURA_FAIXA, 0), 0),
            Faixa(DirecaoVeiculo.LESTE, Posicao3D(-offset, 0, 0), 1)
        ]
        
        self.faixas_oeste = [
            Faixa(DirecaoVeiculo.OESTE, Posicao3D(offset, LARGURA_FAIXA, 0), 0),
            Faixa(DirecaoVeiculo.OESTE, Posicao3D(offset, 0, 0), 1)
        ]
        
        # Semáforos de pedestres
        offset_sem = TAMANHO_CRUZAMENTO/2 + 1
        self.semaforos_pedestres = [
            SemaforoPedestre(Posicao3D(-offset_sem, -offset_sem, 0), "horizontal"),
            SemaforoPedestre(Posicao3D(offset_sem, -offset_sem, 0), "horizontal"),
            SemaforoPedestre(Posicao3D(-offset_sem, offset_sem, 0), "vertical"),
            SemaforoPedestre(Posicao3D(offset_sem, offset_sem, 0), "vertical")
        ]
        
        # Lista de pedestres
        self.pedestres: List[Pedestre] = []
        
        # Sincronização de semáforos
        self._sincronizar_semaforos()
    
    def _sincronizar_semaforos(self):
        """Sincroniza os semáforos para fluxo otimizado"""
        todas_faixas = self.faixas_norte + self.faixas_sul + self.faixas_leste + self.faixas_oeste
        
        # Define tempos diferentes para vias principais e secundárias
        for faixa in self.faixas_norte + self.faixas_sul:
            faixa.semaforo.tempo_verde = 20.0
            faixa.semaforo.tempo_vermelho = 15.0
        
        for faixa in self.faixas_leste + self.faixas_oeste:
            faixa.semaforo.tempo_verde = 12.0
            faixa.semaforo.tempo_vermelho = 23.0
        
        # Inicia com norte/sul verde
        for faixa in self.faixas_norte + self.faixas_sul:
            faixa.semaforo.estado = EstadoSemaforo.VERDE
            faixa.semaforo.tempo_restante = faixa.semaforo.tempo_verde
        
        for faixa in self.faixas_leste + self.faixas_oeste:
            faixa.semaforo.estado = EstadoSemaforo.VERMELHO
            faixa.semaforo.tempo_restante = faixa.semaforo.tempo_vermelho
    
    def spawnar_carro(self, spawn_rate: float, dt: float):
        """Spawna carros em todas as faixas baseado na taxa configurada"""
        todas_faixas = self.faixas_norte + self.faixas_sul + self.faixas_leste + self.faixas_oeste
        
        for faixa in todas_faixas:
            if random.random() < spawn_rate * dt:
                faixa.spawnar_carro()
    
    def spawnar_pedestre(self, spawn_rate: float, dt: float):
        """Spawna pedestres nas esquinas"""
        if random.random() < spawn_rate * dt:
            # Escolhe uma travessia aleatória
            travessias = [
                # Travessia horizontal
                {
                    'inicio': Posicao3D(-12, -2, ALTURA_CALCADA),
                    'destino': Posicao3D(12, -2, ALTURA_CALCADA),
                    'direcao': 'horizontal'
                },
                {
                    'inicio': Posicao3D(12, 2, ALTURA_CALCADA),
                    'destino': Posicao3D(-12, 2, ALTURA_CALCADA),
                    'direcao': 'horizontal'
                },
                # Travessia vertical
                {
                    'inicio': Posicao3D(-2, -12, ALTURA_CALCADA),
                    'destino': Posicao3D(-2, 12, ALTURA_CALCADA),
                    'direcao': 'vertical'
                },
                {
                    'inicio': Posicao3D(2, 12, ALTURA_CALCADA),
                    'destino': Posicao3D(2, -12, ALTURA_CALCADA),
                    'direcao': 'vertical'
                }
            ]
            
            travessia = random.choice(travessias)
            pedestre = Pedestre(
                travessia['inicio'],
                travessia['destino'],
                travessia['direcao']
            )
            self.pedestres.append(pedestre)
    
    def atualizar(self, dt: float, spawn_rate_carros: float, spawn_rate_pedestres: float):
        """Atualiza todo o cruzamento"""
        # Spawna novos carros e pedestres
        self.spawnar_carro(spawn_rate_carros, dt)
        self.spawnar_pedestre(spawn_rate_pedestres, dt)
        
        # Atualiza faixas e seus carros
        todas_faixas = self.faixas_norte + self.faixas_sul + self.faixas_leste + self.faixas_oeste
        for faixa in todas_faixas:
            faixa.atualizar(dt)
        
        # Atualiza semáforos de pedestres
        for semaforo in self.semaforos_pedestres:
            semaforo.atualizar(dt)
            
            if semaforo.botao_pressionado and self._pode_ativar_travessia_pedestre(semaforo):
                semaforo.ativar_travessia()
        
        # Atualiza pedestres
        for i in range(len(self.pedestres) - 1, -1, -1):
            pedestre = self.pedestres[i]
            
            semaforo_apropriado = self._get_semaforo_pedestre(pedestre)
            pedestre.atualizar(dt, semaforo_apropriado)
            
            if pedestre.completou_travessia:
                self.pedestres.pop(i)
    
    def _pode_ativar_travessia_pedestre(self, semaforo_pedestre: SemaforoPedestre) -> bool:
        """Verifica se é seguro ativar a travessia de pedestres"""
        if semaforo_pedestre.direcao == "horizontal":
            carros_esperando = sum(f.carros_esperando for f in self.faixas_norte + self.faixas_sul)
        else:
            carros_esperando = sum(f.carros_esperando for f in self.faixas_leste + self.faixas_oeste)
        
        return carros_esperando < 3
    
    def _get_semaforo_pedestre(self, pedestre: Pedestre) -> SemaforoPedestre:
        """Retorna o semáforo de pedestres apropriado"""
        if pedestre.direcao_travessia == "horizontal":
            return next(s for s in self.semaforos_pedestres if s.direcao == "horizontal")
        else:
            return next(s for s in self.semaforos_pedestres if s.direcao == "vertical")
    
    def desenhar_estrutura(self):
        """Desenha a estrutura 3D do cruzamento"""
        # Área central do cruzamento
        glPushMatrix()
        glTranslatef(0, 0, ALTURA_ESTRADA/2)
        Utils3D.desenhar_cubo(TAMANHO_CRUZAMENTO, TAMANHO_CRUZAMENTO, ALTURA_ESTRADA, CINZA_ESCURO)
        glPopMatrix()
        
        # Estradas
        self._desenhar_estradas()
        
        # Calçadas
        self._desenhar_calcadas()
        
        # Faixas de pedestres
        self._desenhar_faixas_pedestres()
    
    def _desenhar_estradas(self):
        """Desenha as estradas em 3D"""
        # Estradas verticais (norte-sul)
        for i in range(2):
            x_offset = -LARGURA_FAIXA + i * LARGURA_FAIXA
            for y_pos in [-COMPRIMENTO_ESTRADA/2, COMPRIMENTO_ESTRADA/2]:
                glPushMatrix()
                glTranslatef(x_offset, y_pos, ALTURA_ESTRADA/2)
                Utils3D.desenhar_cubo(LARGURA_FAIXA*2, COMPRIMENTO_ESTRADA, ALTURA_ESTRADA, CINZA_ESCURO)
                glPopMatrix()
        
        # Estradas horizontais (leste-oeste)
        for i in range(2):
            y_offset = -LARGURA_FAIXA + i * LARGURA_FAIXA
            for x_pos in [-COMPRIMENTO_ESTRADA/2, COMPRIMENTO_ESTRADA/2]:
                glPushMatrix()
                glTranslatef(x_pos, y_offset, ALTURA_ESTRADA/2)
                Utils3D.desenhar_cubo(COMPRIMENTO_ESTRADA, LARGURA_FAIXA*2, ALTURA_ESTRADA, CINZA_ESCURO)
                glPopMatrix()
    
    def _desenhar_calcadas(self):
        """Desenha as calçadas em 3D"""
        posicoes_calcadas = [
            (-15, -15), (15, -15), (-15, 15), (15, 15)
        ]
        
        for x, y in posicoes_calcadas:
            glPushMatrix()
            glTranslatef(x, y, ALTURA_CALCADA/2)
            Utils3D.desenhar_cubo(8, 8, ALTURA_CALCADA, CINZA_CLARO)
            glPopMatrix()
    
    def _desenhar_faixas_pedestres(self):
        """Desenha as faixas de pedestres em 3D"""
        # Faixas horizontais
        for y_offset in [-2, 2]:
            for x in range(-10, 11, 2):
                glPushMatrix()
                glTranslatef(x, y_offset, ALTURA_ESTRADA + 0.01)
                Utils3D.desenhar_cubo(1.5, 0.8, 0.02, BRANCO)
                glPopMatrix()
        
        # Faixas verticais
        for x_offset in [-2, 2]:
            for y in range(-10, 11, 2):
                glPushMatrix()
                glTranslatef(x_offset, y, ALTURA_ESTRADA + 0.01)
                Utils3D.desenhar_cubo(0.8, 1.5, 0.02, BRANCO)
                glPopMatrix()
    
    def desenhar(self):
        """Desenha todo o cruzamento"""
        self.desenhar_estrutura()
        
        # Desenha faixas
        todas_faixas = self.faixas_norte + self.faixas_sul + self.faixas_leste + self.faixas_oeste
        for faixa in todas_faixas:
            faixa.desenhar()
        
        # Desenha pedestres
        for pedestre in self.pedestres:
            pedestre.desenhar()
        
        # Desenha semáforos de pedestres
        for semaforo in self.semaforos_pedestres:
            semaforo.desenhar()
    
    def reset(self):
        """Reinicia o cruzamento"""
        # Limpa todos os carros
        for faixa in self.faixas_norte + self.faixas_sul + self.faixas_leste + self.faixas_oeste:
            faixa.carros.clear()
            faixa.carros_passaram = 0
            faixa.carros_esperando = 0
            faixa.tempo_espera_total = 0
            faixa.max_fila = 0
        
        # Limpa pedestres
        self.pedestres.clear()
        
        # Reseta semáforos
        self._sincronizar_semaforos()
        
        for semaforo in self.semaforos_pedestres:
            semaforo.estado = EstadoSemaforo.VERMELHO
            semaforo.tempo_restante = 0
            semaforo.botao_pressionado = False

class HUD2D:
    """Interface 2D sobreposta usando Pygame"""
    
    def __init__(self, tela_superficie):
        self.tela = tela_superficie
        self.font_titulo = pygame.font.Font(None, 32)
        self.font_normal = pygame.font.Font(None, 24)
        self.font_pequena = pygame.font.Font(None, 18)
    
    def desenhar(self, cruzamento, simulador_info):
        """Desenha a interface 2D sobre a cena 3D"""
        # Painel de estatísticas
        self._desenhar_painel_stats(cruzamento)
        
        # Painel de controles
        self._desenhar_painel_controles(simulador_info)
        
        # Painel de status
        self._desenhar_painel_status(simulador_info)
    
    def _desenhar_painel_stats(self, cruzamento):
        """Desenha o painel de estatísticas"""
        # Fundo semi-transparente
        painel = pygame.Surface((300, 350))
        painel.set_alpha(180)
        painel.fill((0, 0, 0))
        self.tela.blit(painel, (10, 10))
        
        # Título
        titulo = self.font_titulo.render("ESTATÍSTICAS 3D", True, (255, 255, 255))
        self.tela.blit(titulo, (20, 20))
        
        y_offset = 60
        
        # Estatísticas por direção
        direcoes = [
            ("Norte ↑", cruzamento.faixas_norte),
            ("Sul ↓", cruzamento.faixas_sul),
            ("Leste →", cruzamento.faixas_leste),
            ("Oeste ←", cruzamento.faixas_oeste)
        ]
        
        for nome_direcao, faixas in direcoes:
            # Título da direção
            texto_direcao = self.font_normal.render(nome_direcao, True, (255, 255, 0))
            self.tela.blit(texto_direcao, (25, y_offset))
            y_offset += 25
            
            # Estatísticas das faixas
            total_passaram = sum(f.carros_passaram for f in faixas)
            total_esperando = sum(f.carros_esperando for f in faixas)
            max_fila = max(f.max_fila for f in faixas) if faixas else 0
            
            stats_texto = [
                f"  Passaram: {total_passaram:>3}",
                f"  Esperando: {total_esperando:>2}",
                f"  Fila máx: {max_fila:>2}"
            ]
            
            for linha in stats_texto:
                texto = self.font_pequena.render(linha, True, (255, 255, 255))
                self.tela.blit(texto, (30, y_offset))
                y_offset += 18
            
            y_offset += 5
        
        # Total geral
        y_offset += 10
        total_geral = sum(f.carros_passaram for faixas in [cruzamento.faixas_norte, cruzamento.faixas_sul,
                                                          cruzamento.faixas_leste, cruzamento.faixas_oeste]
                         for f in faixas)
        
        texto_geral = self.font_normal.render("TOTAIS", True, (0, 255, 0))
        self.tela.blit(texto_geral, (25, y_offset))
        y_offset += 25
        
        geral_texto = f"Total carros: {total_geral}"
        texto = self.font_pequena.render(geral_texto, True, (255, 255, 255))
        self.tela.blit(texto, (30, y_offset))
    
    def _desenhar_painel_controles(self, simulador_info):
        """Desenha o painel de controles"""
        painel = pygame.Surface((500, 120))
        painel.set_alpha(180)
        painel.fill((0, 0, 0))
        self.tela.blit(painel, (10, ALTURA_TELA - 130))
        
        controles = [
            "CONTROLES 3D:",
            "P - Pausar | R - Reiniciar | W/S - Zoom | A/D - Rotação | Q/E - Altura",
            f"1-5 - Taxa carros ({simulador_info['spawn_rate_carros']:.1f}) | 8-9 - Taxa pedestres ({simulador_info['spawn_rate_pedestres']:.1f})",
            "Mouse - Câmera livre | ESC - Sair"
        ]
        
        y_offset = 15
        for i, linha in enumerate(controles):
            cor = (255, 255, 0) if i == 0 else (255, 255, 255)
            font = self.font_normal if i == 0 else self.font_pequena
            texto = font.render(linha, True, cor)
            self.tela.blit(texto, (20, ALTURA_TELA - 130 + y_offset))
            y_offset += 22 if i == 0 else 18
    
    def _desenhar_painel_status(self, simulador_info):
        """Desenha o painel de status"""
        painel = pygame.Surface((200, 100))
        painel.set_alpha(180)
        painel.fill((0, 0, 0))
        self.tela.blit(painel, (LARGURA_TELA - 210, 10))
        
        # Status
        status_texto = "PAUSADO" if simulador_info['pausado'] else "EXECUTANDO"
        cor_status = (255, 255, 0) if simulador_info['pausado'] else (0, 255, 0)
        
        texto_status = self.font_normal.render("STATUS:", True, (255, 255, 255))
        self.tela.blit(texto_status, (LARGURA_TELA - 200, 20))
        
        texto_estado = self.font_normal.render(status_texto, True, cor_status)
        self.tela.blit(texto_estado, (LARGURA_TELA - 200, 45))
        
        # FPS
        fps_texto = f"FPS: {simulador_info['fps']:.0f}"
        texto_fps = self.font_pequena.render(fps_texto, True, (255, 255, 255))
        self.tela.blit(texto_fps, (LARGURA_TELA - 200, 75))

class SimuladorTrafego3D:
    """Simulador principal 3D com Pygame + PyOpenGL"""
    
    def __init__(self):
        pygame.init()
        
        # Configurar janela com OpenGL
        pygame.display.set_mode((LARGURA_TELA, ALTURA_TELA), pygame.DOUBLEBUF | pygame.OPENGL)
        pygame.display.set_caption("Simulador 3D de Tráfego - Pygame + PyOpenGL")
        
        # Configurar OpenGL
        self._configurar_opengl()
        
        # Configurar iluminação
        self._configurar_iluminacao()
        
        self.clock = pygame.time.Clock()
        self.camera = Camera3D()
        self.cruzamento = Cruzamento()
        
        # Superfície para HUD 2D
        self.hud_superficie = pygame.Surface((LARGURA_TELA, ALTURA_TELA))
        self.hud_superficie.set_colorkey((0, 0, 0))
        self.hud = HUD2D(self.hud_superficie)
        
        # Estado do simulador
        self.executando = True
        self.pausado = False
        self.spawn_rate_carros = 0.3
        self.spawn_rate_pedestres = 0.1
        
        print("Simulador 3D de Tráfego iniciado!")
        print("Use P para pausar, R para reiniciar, Mouse para controlar câmera")
    
    def _configurar_opengl(self):
        """Configura os parâmetros básicos do OpenGL"""
        # Habilitar teste de profundidade
        glEnable(GL_DEPTH_TEST)
        
        # Configurar perspectiva
        glMatrixMode(GL_PROJECTION)
        glLoadIdentity()
        gluPerspective(60.0, LARGURA_TELA / ALTURA_TELA, 0.1, 200.0)
        
        # Configurar modelview
        glMatrixMode(GL_MODELVIEW)
        
        # Cor de fundo (céu azul)
        glClearColor(0.5, 0.7, 1.0, 1.0)
        
        # Habilitar blending para transparência
        glEnable(GL_BLEND)
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    
    def _configurar_iluminacao(self):
        """Configura a iluminação da cena 3D"""
        glEnable(GL_LIGHTING)
        glEnable(GL_LIGHT0)
        
        # Luz ambiente
        luz_ambiente = [0.3, 0.3, 0.3, 1.0]
        glLightfv(GL_LIGHT0, GL_AMBIENT, luz_ambiente)
        
        # Luz difusa
        luz_difusa = [0.8, 0.8, 0.8, 1.0]
        glLightfv(GL_LIGHT0, GL_DIFFUSE, luz_difusa)
        
        # Posição da luz (sol)
        posicao_luz = [20.0, 20.0, 30.0, 1.0]
        glLightfv(GL_LIGHT0, GL_POSITION, posicao_luz)
        
        # Habilitar normalização automática
        glEnable(GL_NORMALIZE)
    
    def processar_eventos(self):
        """Processa eventos do teclado e mouse"""
        for evento in pygame.event.get():
            if evento.type == pygame.QUIT:
                self.executando = False
            
            elif evento.type == pygame.KEYDOWN:
                if evento.key == pygame.K_ESCAPE:
                    self.executando = False
                
                elif evento.key == pygame.K_p:
                    self.pausado = not self.pausado
                    print(f"Simulador {'pausado' if self.pausado else 'retomado'}")
                
                elif evento.key == pygame.K_r:
                    self.cruzamento.reset()
                    self.pausado = False
                    print("Simulador reiniciado")
                
                # Controles da câmera
                elif evento.key == pygame.K_w:
                    self.camera.zoom(-2.0)
                elif evento.key == pygame.K_s:
                    self.camera.zoom(2.0)
                elif evento.key == pygame.K_a:
                    self.camera.rotacionar(-5.0, 0)
                elif evento.key == pygame.K_d:
                    self.camera.rotacionar(5.0, 0)
                elif evento.key == pygame.K_q:
                    self.camera.rotacionar(0, 5.0)
                elif evento.key == pygame.K_e:
                    self.camera.rotacionar(0, -5.0)
                
                # Taxa de spawn de carros (1-5)
                elif evento.key in [pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4, pygame.K_5]:
                    nivel = evento.key - pygame.K_0
                    self.spawn_rate_carros = nivel * 0.15
                    print(f"Taxa de spawn de carros: {self.spawn_rate_carros:.2f}")
                
                # Taxa de spawn de pedestres (8-9)
                elif evento.key == pygame.K_8:
                    self.spawn_rate_pedestres = max(0.05, self.spawn_rate_pedestres - 0.05)
                    print(f"Taxa de spawn de pedestres: {self.spawn_rate_pedestres:.2f}")
                elif evento.key == pygame.K_9:
                    self.spawn_rate_pedestres = min(0.5, self.spawn_rate_pedestres + 0.05)
                    print(f"Taxa de spawn de pedestres: {self.spawn_rate_pedestres:.2f}")
            
            elif evento.type == pygame.MOUSEBUTTONDOWN:
                if evento.button == 1:  # Botão esquerdo
                    mouse_x, mouse_y = pygame.mouse.get_pos()
                    self.camera.atualizar_mouse(mouse_x, mouse_y, True)
            
            elif evento.type == pygame.MOUSEBUTTONUP:
                if evento.button == 1:
                    self.camera.atualizar_mouse(0, 0, False)
            
            elif evento.type == pygame.MOUSEMOTION:
                if pygame.mouse.get_pressed()[0]:  # Botão esquerdo pressionado
                    mouse_x, mouse_y = pygame.mouse.get_pos()
                    self.camera.atualizar_mouse(mouse_x, mouse_y, True)
    
    def atualizar(self, dt: float):
        """Atualiza a lógica do simulador"""
        if not self.pausado:
            self.cruzamento.atualizar(dt, self.spawn_rate_carros, self.spawn_rate_pedestres)
    
    def desenhar_3d(self):
        """Desenha a cena 3D"""
        # Limpar buffers
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        
        # Aplicar transformação da câmera
        self.camera.aplicar_transformacao()
        
        # Desenhar o cruzamento
        self.cruzamento.desenhar()
    
    def desenhar_2d(self):
        """Desenha a interface 2D sobreposta"""
        # Desabilitar OpenGL temporariamente
        glDisable(GL_DEPTH_TEST)
        glDisable(GL_LIGHTING)
        
        # Configurar projeção 2D
        glMatrixMode(GL_PROJECTION)
        glPushMatrix()
        glLoadIdentity()
        glOrtho(0, LARGURA_TELA, ALTURA_TELA, 0, -1, 1)
        
        glMatrixMode(GL_MODELVIEW)
        glPushMatrix()
        glLoadIdentity()
        
        # Limpar superfície HUD
        self.hud_superficie.fill((0, 0, 0))
        
        # Desenhar HUD
        info_simulador = {
            'pausado': self.pausado,
            'fps': self.clock.get_fps(),
            'spawn_rate_carros': self.spawn_rate_carros,
            'spawn_rate_pedestres': self.spawn_rate_pedestres
        }
        
        self.hud.desenhar(self.cruzamento, info_simulador)
        
        # Converter superfície Pygame para textura OpenGL
        pygame_image = pygame.transform.flip(self.hud_superficie, False, True)
        pygame_image = pygame.image.tostring(pygame_image, "RGBA", True)
        
        # Desenhar textura
        glEnable(GL_TEXTURE_2D)
        textura_id = glGenTextures(1)
        glBindTexture(GL_TEXTURE_2D, textura_id)
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, LARGURA_TELA, ALTURA_TELA, 0, GL_RGBA, GL_UNSIGNED_BYTE, pygame_image)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        
        glEnable(GL_BLEND)
        glColor4f(1.0, 1.0, 1.0, 0.8)
        
        glBegin(GL_QUADS)
        glTexCoord2f(0, 0); glVertex2f(0, 0)
        glTexCoord2f(1, 0); glVertex2f(LARGURA_TELA, 0)
        glTexCoord2f(1, 1); glVertex2f(LARGURA_TELA, ALTURA_TELA)
        glTexCoord2f(0, 1); glVertex2f(0, ALTURA_TELA)
        glEnd()
        
        glDisable(GL_TEXTURE_2D)
        glDeleteTextures([textura_id])
        
        # Restaurar matrizes
        glPopMatrix()
        glMatrixMode(GL_PROJECTION)
        glPopMatrix()
        glMatrixMode(GL_MODELVIEW)
        
        # Reabilitar OpenGL 3D
        glEnable(GL_DEPTH_TEST)
        glEnable(GL_LIGHTING)
    
    def desenhar(self):
        """Desenha tudo"""
        self.desenhar_3d()
        self.desenhar_2d()
        
        pygame.display.flip()
    
    def executar(self):
        """Loop principal do simulador"""
        while self.executando:
            dt = self.clock.tick(FPS) / 1000.0  # Delta time em segundos
            
            self.processar_eventos()
            self.atualizar(dt)
            self.desenhar()
        
        pygame.quit()
        print("Simulador 3D finalizado")

def main():
    """Função principal"""
    try:
        simulador = SimuladorTrafego3D()
        simulador.executar()
    except KeyboardInterrupt:
        print("\nSimulador interrompido pelo usuário")
    except Exception as e:
        print(f"Erro no simulador: {e}")
        import traceback
        traceback.print_exc()
    finally:
        pygame.quit()
        sys.exit()

if __name__ == "__main__":
    main()