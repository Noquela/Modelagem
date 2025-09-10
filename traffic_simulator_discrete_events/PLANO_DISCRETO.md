# Plano: Simulador de Tráfego com Eventos Discretos

## Conceito Fundamental

**Eventos Contínuos (atual)**: Carros se movem continuamente a cada frame, checam colisões constantemente
**Eventos Discretos (novo)**: Carros só "existem" em momentos específicos (eventos), como:
- Chegada na intersecção
- Mudança de semáforo  
- Conclusão de atravessar
- Spawn de novos veículos

## Arquitetura Híbrida Proposta

```
Frontend (Visual) - Contínuo ──────┐
                                   ├─── Sincronização
Backend (Lógica) - Discreto ───────┘
```

## Sprint Breakdown Detalhado

### Sprint 1: Sistema de Eventos Discretos Core (2-3 dias)

**Objetivos:**
- Criar o motor de eventos discretos
- Implementar Event Scheduler
- Sistema básico de tempo simulado

**Entregáveis:**
1. `DiscreteEventScheduler.gd` - Motor principal
2. `DiscreteEvent.gd` - Classe base para eventos  
3. `SimulationClock.gd` - Controle de tempo simulado
4. Eventos básicos: `CarSpawnEvent`, `CarArrivalEvent`

### Sprint 2: Sistema de Veículos Discretos (3-4 dias)

**Objetivos:**
- Migrar lógica de carros para eventos discretos
- Implementar estados discretos dos veículos
- Calcular tempos de viagem entre pontos

**Entregáveis:**
1. `DiscreteCar.gd` - Representação lógica do carro
2. `VehicleJourney.gd` - Cálculo de rotas e tempos
3. Eventos: `CarDepartureEvent`, `IntersectionArrivalEvent`
4. Sistema de filas discretas

### Sprint 3: Sistema de Semáforos Discretos (2-3 dias)

**Objetivos:**
- Eventos de mudança de semáforo
- Lógica de processamento de filas
- Integração com timing de semáforos

**Entregáveis:**
1. `DiscreteTrafficManager.gd` - Controlador discreto
2. Eventos: `LightChangeEvent`, `QueueProcessingEvent`
3. `TrafficQueue.gd` - Gerenciamento de filas por direção

### Sprint 4: Sistema Híbrido de Renderização (3-4 dias)

**Objetivos:**
- Sincronizar backend discreto com frontend contínuo
- Interpolação visual entre eventos
- Manter 60fps visual com lógica discreta

**Entregáveis:**
1. `HybridRenderer.gd` - Ponte visual-lógica
2. `CarVisualProxy.gd` - Representação visual
3. Sistema de interpolação de movimento
4. Sincronização de estado visual

### Sprint 5: Analytics e Otimização (2 dias)

**Objetivos:**
- Métricas específicas para simulação discreta
- Performance tuning
- Validação vs simulador contínuo

**Entregáveis:**
1. `DiscreteAnalytics.gd` - Métricas especializadas
2. Comparação de performance
3. Validação de resultados
4. Interface de debug

## Arquitetura Técnica Detalhada

### 1. Sistema de Eventos Discretos

```gdscript
# DiscreteEvent.gd
class_name DiscreteEvent
extends RefCounted

var event_time: float
var event_type: String
var entity_id: int
var data: Dictionary

func execute(simulator): pass
```

### 2. Motor de Simulação

```gdscript
# DiscreteEventScheduler.gd
class_name DiscreteEventScheduler

var future_events: Array[DiscreteEvent] = []
var current_time: float = 0.0
var entities: Dictionary = {}

func schedule_event(event: DiscreteEvent):
    # Inserir ordenado por tempo
    
func process_next_event():
    # Executa próximo evento na linha do tempo
```

### 3. Entidades Discretas

```gdscript
# DiscreteCar.gd
class_name DiscreteCar

var car_id: int
var current_segment: String
var destination: String
var journey_start_time: float
var state: CarState # TRAVELING, QUEUED, CROSSING

func calculate_travel_time(from: String, to: String) -> float:
    # Baseado na velocidade e personalidade
```

### 4. Tipos de Eventos Principais

1. **SpawnEvent**: Criar novo veículo
2. **ArrivalEvent**: Veículo chega na intersecção  
3. **DepartureEvent**: Veículo sai da intersecção
4. **LightChangeEvent**: Mudança de semáforo
5. **QueueProcessEvent**: Processar fila quando luz fica verde

## Benefícios da Abordagem Discreta

### Vantagens:
1. **Performance**: Só processa quando algo muda
2. **Escalabilidade**: Pode simular milhares de veículos
3. **Precisão**: Eventos exatos, sem aproximações de frame
4. **Análise**: Estatísticas mais precisas
5. **Determinismo**: Resultados reproduzíveis

### Desafios:
1. **Sincronização**: Visual contínuo + lógica discreta
2. **Interpolação**: Movimento suave entre eventos
3. **Complexidade**: Mais difícil de debug inicialmente

## Cronograma Sugerido

```
Semana 1: Sprint 1 + Sprint 2 (Sistema Core)
Semana 2: Sprint 3 + Sprint 4 (Integração Visual) 
Semana 3: Sprint 5 + Polish (Otimização Final)
```

---

## ANÁLISE CRÍTICA: VIABILIDADE DA FLUIDEZ VISUAL

### Problema Central: Tradução Backend → Frontend

O maior desafio não está na lógica discreta, mas em **como traduzir eventos discretos em movimento visual fluido a 60fps**.

### Desafios Técnicos Identificados:

#### 1. **Gap Temporal Entre Eventos**
```
Evento Discreto: Carro spawn às 10.0s → próximo evento às 15.3s
Frontend: Precisa de 60 frames × 5.3s = 318 frames intermediários
```
**Solução**: Sistema de interpolação temporal com predição de trajetória

#### 2. **Latência de Sincronização**
- Backend processa eventos instantaneamente
- Frontend precisa de tempo para interpolar movimento
- **Risco**: Carros "teleportando" ou movimento robótico

#### 3. **Estados Fantasma**
- Frontend mostra carros "entre eventos" que não existem no backend
- **Complexidade**: Manter consistência de estado

#### 4. **Performance da Ponte**
- Sistema atual: ~1000 checks/frame para 100 carros
- Sistema híbrido: interpolação + sincronização pode ser mais custoso

### ✨ **SOLUÇÃO GENIAL: Sistema de Predição por Agendamento**

O sistema de eventos discretos agenda eventos **no futuro**. O frontend pode ler essa agenda e renderizar fluidamente!

#### A. **Frontend Preditivo Baseado em Agenda**
```gdscript
# DiscreteEventScheduler.gd
func get_future_events_for_entity(entity_id: int, time_window: float) -> Array[DiscreteEvent]:
    # Retorna todos eventos futuros de uma entidade nos próximos X segundos
    
func predict_entity_position_at_time(entity_id: int, target_time: float) -> Vector3:
    # Interpola posição baseado em eventos agendados
```

#### B. **Sistema de Renderização Preditiva**
```gdscript
class CarVisualProxy:
    var car_id: int
    var current_visual_position: Vector3
    var future_events_cache: Array[DiscreteEvent]
    
    func update_visual_position(delta: float):
        var current_time = simulation_clock.get_time()
        var target_time = current_time + delta
        
        # Interpola baseado em eventos já agendados
        visual_position = event_scheduler.predict_entity_position_at_time(car_id, target_time)
```

#### C. **Timeline Preditivo**
```
Scheduler: [T+0s: SpawnEvent] → [T+5.2s: ArrivalEvent] → [T+7.1s: DepartureEvent]
Frontend:  Lê agenda → Interpola posições → Renderiza 60fps fluido
```

#### C. **Sistema de Timeline Duplo**
```
Backend Timeline: [0s] → [5.2s] → [12.8s] → [eventos discretos]
Visual Timeline:  [frame] → [frame] → [frame] → [60fps contínuo]
```

### Avaliação Realista:

#### ✅ **Vai Funcionar Bem:**
- Spawn de veículos (fácil interpolar)
- Mudanças de semáforo (instantâneas)
- Estatísticas e analytics (melhor que atual)

#### ⚠️ **Desafio Médio:**
- Movimento em linha reta (interpolação linear)
- Filas paradas (estado estático)

#### 🔴 **Desafio Alto:**
- **Curvas e mudanças de direção** (requer predição complexa)
- **Interações entre carros** (como manter IDM visual?)
- **Decisões de semáforo amarelo** (evento discreto vs reação visual)

### Alternativa Híbrida Mais Segura:

#### **"Eventos Discretos com Física Simplificada"**
```gdscript
# Backend: Eventos discretos para decisões importantes
# Frontend: Física simplificada para movimento suave

class HybridCar:
    var discrete_logic: DiscreteCar      # Decisões e estados
    var continuous_physics: CarMovement  # Movimento visual apenas
```

**Vantagem**: Combina precisão discreta com fluidez contínua
**Desvantagem**: Mais complexo, duas representações por carro

### Recomendação Final:

O sistema **pode** ter a mesma fluidez, mas vai ser **significativamente mais complexo** do que parece inicialmente. O Sprint 4 (Sistema Híbrido) vai ser o mais crítico e pode levar mais tempo que estimado.

**Sugestão**: Comece com um **protótipo simples** primeiro:
1. Apenas movimentos em linha reta
2. Sem curvas nem interações complexas  
3. Teste a fluidez visual antes de expandir

Se a fluidez não for satisfatória no protótipo, pode ser melhor manter o sistema contínuo atual e otimizá-lo em vez de migrar completamente.