# Traffic Simulator 3D - Python Edition

Um simulador de tráfego 3D avançado desenvolvido em Python com IA comportamental, renderização em tempo real e física realística. Baseado em especificações detalhadas e protótipos testados.

![Traffic Simulator 3D](Inspiration/image.png)

## 🚦 Características Principais

### ⚡ Performance Otimizada
- **Renderização 3D** com ModernGL e OpenGL moderno
- **Instanced rendering** para centenas de carros simultâneos
- **Frustum culling** e LOD system automático
- **60 FPS** consistentes mesmo com 100+ veículos

### 🧠 IA Comportamental Avançada
- **4 Tipos de Personalidade**: Agressivo, Conservador, Normal, Idoso
- **Reações Individualizadas**: Cada motorista tem tempos de reação únicos
- **Lógica de Amarelo Inteligente**: Decisões baseadas em distância + personalidade
- **Formação de Filas Realística**: Carros continuam spawning mesmo com semáforo vermelho

### 🚗 Sistema de Carros Realístico
- **Física Baseada em Velocidade**: Aceleração e desaceleração graduais
- **Variações Individuais**: ±20% de velocidade, cores realísticas
- **Detecção de Obstáculos**: Prioridade para carros à frente, depois semáforos
- **Estatísticas Detalhadas**: Tempo de espera, personalidade, estado atual

### 🚥 Semáforos Sincronizados
- **Lógica do Mundo Real**: 15s verde, 3s amarelo, 1s segurança
- **Rua Principal**: 2 semáforos sincronizados (duas mãos)
- **Rua Transversal**: 1 semáforo (mão única, direção oposta)
- **Ciclo Total**: 37 segundos com tempos de segurança

### 🎮 Controles e Interface
- **Câmera Orbital**: Mouse para rotação, scroll para zoom
- **Controles WASD**: Movimento livre da câmera
- **Estatísticas em Tempo Real**: FPS, throughput, congestionamento
- **Debug Avançado**: Informações detalhadas de IA e performance

## 🏗️ Arquitetura Modular

```
traffic_simulator/
├── main.py                 # Entry point e loop principal
├── core/
│   ├── engine.py          # Engine 3D (ModernGL wrapper)
│   ├── scene.py           # Gerenciamento de cena 3D
│   └── camera.py          # Sistema de câmera orbital
├── entities/
│   ├── car.py             # Classe Car com IA comportamental
│   └── traffic_light.py   # Sistema de semáforos sincronizados
├── systems/
│   ├── spawn_system.py    # Sistema de spawn inteligente
│   └── ai_system.py       # IA coletiva e análise de tráfego
└── utils/
    ├── math_helpers.py    # Utilitários matemáticos 3D
    └── config.py          # Configurações centralizadas
```

## 🚀 Instalação e Execução

### Pré-requisitos
- Python 3.8+
- Windows/Linux/macOS com suporte a OpenGL 3.3+

### Instalação
```bash
# Clone o repositório
git clone <repository-url>
cd traffic_simulator

# Instale as dependências
pip install -r requirements.txt

# Execute o simulador
python main.py
```

### Dependências Principais
```
moderngl>=5.6.4    # Renderização OpenGL moderna
pygame>=2.1.0      # Window management e input
numpy>=1.21.0      # Matemática e arrays
pyrr>=0.10.3       # Matemática 3D adicional
```

## 🎯 Controles

| Controle | Ação |
|----------|------|
| **Mouse** | Rotacionar câmera em torno da intersecção |
| **Scroll** | Zoom in/out |
| **WASD** | Mover target da câmera |
| **Q/E** | Mover câmera para cima/baixo |
| **SPACE** | Pausar/Retomar simulação |
| **R** | Reset câmera para posição padrão |
| **F1** | Mostrar/ocultar debug info |
| **F2** | Reset completo da simulação |
| **ESC** | Sair |

## 📊 Configuração Avançada

### Personalidades dos Motoristas
```python
DRIVER_PERSONALITIES = {
    'AGGRESSIVE': {
        'reaction_time': (0.5, 0.8),     # Reação rápida
        'following_distance_factor': 0.8, # Distância menor
        'yellow_light_probability': 0.8,  # 80% acelera no amarelo
    },
    'CONSERVATIVE': {
        'reaction_time': (1.2, 2.0),     # Reação lenta
        'following_distance_factor': 1.4, # Distância maior
        'yellow_light_probability': 0.1,  # 10% acelera no amarelo
    },
    # ... mais personalidades
}
```

### Configurações de Performance
```python
RENDER_CONFIG = {
    'target_fps': 60,
    'msaa_samples': 4,
    'enable_frustum_culling': True,
    'max_cars_per_batch': 100,
}
```

### Configurações de Spawn
```python
SPAWN_CONFIG = {
    'base_rate': 0.025,           # Taxa base de spawn
    'randomness_factor': 0.5,     # Variação aleatória (±50%)
    'rush_hour_multiplier': 1.5,  # Multiplicador de rush hour
}
```

## 🔬 Algoritmos Implementados

### 1. **Detecção de Obstáculos Inteligente**
```python
def check_obstacles(car):
    # PRIORIDADE 1: Carros à frente
    # PRIORIDADE 2: Semáforos (só se conseguir parar antes da intersecção)
    # REGRA: Não parar no meio da intersecção
```

### 2. **Sistema de Filas Dinâmicas**
```python
def calculate_queue_position(car, direction, lane):
    # Encontrar posição na fila
    # Permitir spawn atrás da fila
    # Distância direcional correta
```

### 3. **Spawn Inteligente com Formação de Filas**
```python
def can_spawn_or_queue(direction, lane):
    # 1. Verificar espaço livre para spawn normal
    # 2. Se não há espaço, verificar se pode formar fila
    # 3. Algoritmo direcional para distâncias corretas
```

## 📈 Estatísticas e Métricas

O simulador coleta métricas detalhadas em tempo real:

- **Throughput**: Carros/minuto por direção
- **Tempo de Espera Médio**: Por tipo de motorista
- **Nível de Congestionamento**: 0-100% por via
- **Eficiência da Intersecção**: Tempo útil vs tempo de espera
- **Colisões Potenciais**: Sistema de prevenção ativo

## 🎨 Características Visuais

### Renderização 3D Realística
- **Carros 3D**: Modelos com carroceria, janelas e rodas
- **Semáforos Detalhados**: Postes, hastes e luzes funcionais
- **Ambiente Completo**: Ruas, grama, linhas de faixa
- **Iluminação Dinâmica**: Luzes dos semáforos mudam de intensidade

### Sistema de Cores
- **Carros**: Cores realísticas (preto, branco, prata, etc.)
- **Semáforos**: Vermelho/Amarelo/Verde com intensidade variável
- **Ambiente**: Verde para grama, cinza para asfalto

## 🧪 Features Experimentais

### Sistema de Eventos
- **Rush Hour**: Aumento automático de spawn em horários específicos
- **Acidentes Simulados**: Bloqueio temporário de faixas
- **Veículos de Emergência**: Comportamento especial (futuro)

### Análise com IA
- **Otimização Automática**: Ajuste de velocidades baseado na congestion
- **Prevenção de Colisões**: Detecção preditiva de conflitos
- **Recomendações de Fluxo**: Sugestões para melhorar throughput

## 🏆 Objetivos de Performance

- **✅ 60 FPS** consistentes com 100+ carros
- **✅ Spawn inteligente** com formação realística de filas  
- **✅ IA comportamental** única por carro
- **✅ Semáforos sincronizados** com lógica do mundo real
- **✅ Interface responsiva** com estatísticas em tempo real

## 🔧 Desenvolvimento e Extensibilidade

### Adicionando Novos Comportamentos
1. Estenda `DriverPersonality` em `config.py`
2. Implemente lógica em `Car._make_driving_decision()`
3. Ajuste distribuição em `SpawnSystem._choose_personality()`

### Criando Novos Tipos de Intersecção
1. Modifique geometria em `Scene3D._create_scene_geometry()`
2. Ajuste lógica de semáforos em `TrafficLightSystem`
3. Configure spawn points em `SpawnSystem._create_spawn_points()`

### Personalizando Renderização
1. Adicione shaders em `Engine3D._init_shaders()`
2. Modifique geometria em `utils/math_helpers.py`
3. Ajuste iluminação em `Scene3D`

## 🐛 Solução de Problemas

### Performance Baixa
- Reduza `max_cars_per_batch` em `config.py`
- Desabilite `enable_frustum_culling` se necessário
- Diminua `msaa_samples` para 0

### Carros Não Spawnam
- Verifique `min_spawn_distance` em configurações
- Ajuste `base_rate` do spawn system
- Confirme que semáforos estão funcionando

### Problemas de Renderização
- Atualize drivers de vídeo
- Verifique suporte a OpenGL 3.3+
- Teste com `msaa_samples = 0`

## 📝 Licença

Este projeto é desenvolvido para fins educacionais e de demonstração. Baseado em especificações detalhadas e prototipagem anterior.

## 🙏 Agradecimentos

Baseado no protótipo HTML original que demonstrou a viabilidade dos algoritmos de IA comportamental e sincronização de semáforos implementados nesta versão Python.