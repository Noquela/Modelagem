# 🎯 PLANO MESTRE - DISCRETE EVENTS TRAFFIC SIMULATOR

## 🚨 OBJETIVO PRINCIPAL
Criar simulador de tráfego usando **EVENTOS DISCRETOS** que funcione **EXATAMENTE** igual ao simulator 3D, mas com eventos explícitos na UI.

---

## 📐 ANÁLISE DO SISTEMA ORIGINAL (simulator_3d)

### ⏰ TIMING DOS SEMÁFOROS (40s total)
```
t=0-20s:  Main Road (1,2) = VERDE  | Cross Road (3) = VERMELHO
t=20-23s: Main Road (1,2) = AMARELO| Cross Road (3) = VERMELHO
t=23-24s: TODOS = VERMELHO (segurança 1s)
t=24-34s: Main Road (1,2) = VERMELHO| Cross Road (3) = VERDE
t=34-37s: Main Road (1,2) = VERMELHO| Cross Road (3) = AMARELO
t=37-40s: TODOS = VERMELHO (segurança 3s)
```

### 🚗 SPAWN DE CARROS
- **Direções**: West→East, East→West, North→South
- **Distribuição**: Aleatória/exponencial
- **Comportamento**: Param no vermelho, andam no verde

### 🎮 UI ORIGINAL
- Estatísticas em tempo real
- Controles de pause/velocidade
- Debug info no console

---

## 🏗️ NOVA ARQUITETURA DISCRETE EVENTS

### 📂 ESTRUTURA DE ARQUIVOS FINAL
```
scripts/
├── DiscreteTrafficSimulator.gd    # CONTROLLER PRINCIPAL
├── DiscreteEventScheduler.gd      # FILA DE EVENTOS APENAS
├── TrafficLightSystem.gd          # SEMÁFOROS APENAS
├── VehicleSystem.gd               # VEÍCULOS APENAS
├── EventTypes.gd                  # ENUMS DOS EVENTOS
├── DiscreteEvent.gd               # CLASSE EVENTO
└── DiscreteUI.gd                  # UI MOSTRANDO EVENTOS
```

---

## 🎯 EVENTOS DISCRETOS ESPECÍFICOS

### 🚦 EVENTOS DE SEMÁFOROS (6 tipos)
```gdscript
SEMAFORO_MAIN_VERDE         # t=0, 40, 80...  → Sem. 1,2 VERDE
SEMAFORO_MAIN_AMARELO       # t=20, 60, 100.. → Sem. 1,2 AMARELO  
SEMAFORO_TODOS_VERMELHO_1   # t=23, 63, 103.. → TODOS VERMELHO
SEMAFORO_CROSS_VERDE        # t=24, 64, 104.. → Sem. 3 VERDE
SEMAFORO_CROSS_AMARELO      # t=34, 74, 114.. → Sem. 3 AMARELO
SEMAFORO_TODOS_VERMELHO_2   # t=37, 77, 117.. → TODOS VERMELHO
```

### 🚗 EVENTOS DE VEÍCULOS (4 tipos)
```gdscript
SPAWN_CARRO_WEST         # Criar carro West→East
SPAWN_CARRO_EAST         # Criar carro East→West  
SPAWN_CARRO_NORTH        # Criar carro North→South
CARRO_SAIU               # Carro saiu do sistema
```

### 📊 EVENTOS DE SISTEMA (1 tipo)
```gdscript
UPDATE_STATS             # Atualizar estatísticas UI
```

---

## 🔄 FLUXO DE EXECUÇÃO

### 1. INICIALIZAÇÃO
```
1. DiscreteTrafficSimulator cria componentes
2. Agenda primeiro ciclo de semáforos (6 eventos)
3. Agenda primeiros spawns de carros (3 eventos)  
4. Agenda primeira atualização stats (1 evento)
5. TOTAL: 10 eventos iniciais na fila
```

### 2. LOOP PRINCIPAL
```
1. EventScheduler pega próximo evento da fila
2. Avança tempo para tempo_do_evento  
3. Emite signal evento_processado(evento)
4. DiscreteTrafficSimulator recebe signal
5. Processa evento específico
6. Agenda novos eventos conforme necessário
7. Repete infinitamente
```

### 3. PROCESSAMENTO POR TIPO
```
SEMAFORO_*: 
  → TrafficLightSystem.set_state()
  → Agenda próximo evento semáforo

SPAWN_CARRO_*:
  → VehicleSystem.spawn_vehicle() 
  → Agenda próximo spawn (distribuição exponencial)

CARRO_SAIU:
  → VehicleSystem.remove_vehicle()
  → Atualiza estatísticas

UPDATE_STATS:
  → Calcula métricas
  → Atualiza UI
  → Agenda próximo update (10s depois)
```

---

## 🎨 UI DOS EVENTOS DISCRETOS

### 📊 PAINEL PRINCIPAL
```
🎯 EVENTOS DISCRETOS
├── ⏰ Tempo Simulação: 123.45s
├── 📊 Eventos Processados: 1247
├── 🔄 Evento Atual: "🟢 Semáforos 1,2 → Verde"
└── ⏭️ Próximos Eventos:
    ├── 1. t=125.30s - 🚗 Spawn → West
    ├── 2. t=127.15s - 🟡 Semáforo 3 → Amarelo
    ├── 3. t=130.00s - 🔴 Todos → Vermelho
    ├── 4. t=131.00s - 🟢 Semáforos 1,2 → Verde
    └── ...
```

### 🎮 PAINEL CONTROLES
```
🎮 CONTROLES
├── ⏸️ Pausar | ▶️ Continuar
├── ⚡ Velocidade: [slider 0.1x - 5x]
└── 🚦 Estados Atuais:
    ├── Semáforos 1,2: VERDE
    └── Semáforo 3: VERMELHO
```

---

## ⚙️ IMPLEMENTAÇÃO DETALHADA

### 🗂️ PASSO 1: EventTypes.gd
```gdscript
extends RefCounted
class_name EventTypes

enum Type {
    # Semáforos (6 tipos)
    SEMAFORO_MAIN_VERDE,
    SEMAFORO_MAIN_AMARELO, 
    SEMAFORO_TODOS_VERMELHO_1,
    SEMAFORO_CROSS_VERDE,
    SEMAFORO_CROSS_AMARELO,
    SEMAFORO_TODOS_VERMELHO_2,
    
    # Veículos (4 tipos)
    SPAWN_CARRO_WEST,
    SPAWN_CARRO_EAST,
    SPAWN_CARRO_NORTH, 
    CARRO_SAIU,
    
    # Sistema (1 tipo)
    UPDATE_STATS
}

static func get_name(type: Type) -> String:
    # Retorna nome para UI
    
static func get_color(type: Type) -> Color:
    # Retorna cor para UI
```

### 🗂️ PASSO 2: DiscreteEvent.gd
```gdscript
extends RefCounted
class_name DiscreteEvent

var time: float
var type: EventTypes.Type  
var data: Dictionary

func _init(event_time: float, event_type: EventTypes.Type, event_data: Dictionary = {}):
    # Construtor simples
```

### 🗂️ PASSO 3: DiscreteEventScheduler.gd
```gdscript
extends Node
class_name DiscreteEventScheduler

# RESPONSABILIDADE: APENAS manter fila ordenada + avançar tempo
# NÃO sabe o que cada evento faz

var event_queue: Array[DiscreteEvent] = []
var simulation_time: float = 0.0
var is_paused: bool = false

signal event_ready(event: DiscreteEvent)
signal time_updated(time: float)
signal queue_updated(queue: Array)

func schedule_event(time: float, type: EventTypes.Type, data: Dictionary = {}):
    # Adiciona evento na fila ordenada
    
func process_next_event():
    # Pega próximo evento, avança tempo, emite signal
    
func pause/resume/set_speed():
    # Controles básicos
```

### 🗂️ PASSO 4: TrafficLightSystem.gd  
```gdscript
extends Node
class_name TrafficLightSystem

# RESPONSABILIDADE: APENAS controlar estados dos semáforos
# NÃO agenda eventos

var main_road_state: String = "red"      # Semáforos 1,2
var cross_road_state: String = "red"     # Semáforo 3
var traffic_lights_3d: Array[Node3D] = []

func set_main_road_state(state: String):
    # Define estado sem agendar eventos
    
func set_cross_road_state(state: String):
    # Define estado sem agendar eventos
    
func apply_visual_changes():
    # Aplica mudanças nos semáforos 3D
```

### 🗂️ PASSO 5: VehicleSystem.gd
```gdscript
extends Node  
class_name VehicleSystem

# RESPONSABILIDADE: APENAS criar/destruir veículos
# NÃO agenda eventos

var vehicles: Array[Node] = []
var car_scene: PackedScene

func spawn_vehicle(direction: String):
    # Cria veículo 3D sem agendar eventos
    
func remove_vehicle(vehicle: Node):
    # Remove veículo sem agendar eventos
```

### 🗂️ PASSO 6: DiscreteTrafficSimulator.gd
```gdscript
extends Node
class_name DiscreteTrafficSimulator  

# RESPONSABILIDADE: COORDENAR TUDO + PROCESSAR EVENTOS
# Único lugar que agenda eventos

var event_scheduler: DiscreteEventScheduler
var traffic_lights: TrafficLightSystem  
var vehicles: VehicleSystem

func _ready():
    create_components()
    connect_signals() 
    initialize_simulation()

func _on_event_ready(event: DiscreteEvent):
    # ÚNICO local que processa eventos
    match event.type:
        EventTypes.Type.SEMAFORO_MAIN_VERDE:
            process_semaforo_main_verde()
        EventTypes.Type.SPAWN_CARRO_WEST:
            process_spawn_carro_west()
        # etc...

func process_semaforo_main_verde():
    # 1. traffic_lights.set_main_road_state("green")
    # 2. event_scheduler.schedule_event(time + 20.0, SEMAFORO_MAIN_AMARELO)

func process_spawn_carro_west():
    # 1. vehicles.spawn_vehicle("West")
    # 2. event_scheduler.schedule_event(time + exponential(), SPAWN_CARRO_WEST)

func initialize_simulation():
    # Agenda 10 eventos iniciais
    # Semáforos: 6 eventos do ciclo
    # Spawns: 3 eventos (West, East, North)  
    # Stats: 1 evento
```

### 🗂️ PASSO 7: DiscreteUI.gd
```gdscript
extends Control
class_name DiscreteUI

# RESPONSABILIDADE: APENAS mostrar eventos + controles
# NÃO processa lógica de simulação

var simulator: DiscreteTrafficSimulator
var scheduler: DiscreteEventScheduler

func _ready():
    find_components()
    create_ui()
    connect_signals()

func _on_event_ready(event: DiscreteEvent):
    # Atualiza "Evento Atual"
    
func _on_queue_updated(queue: Array):
    # Atualiza lista "Próximos Eventos"
    
func _on_time_updated(time: float):
    # Atualiza "Tempo Simulação"
```

---

## 🚀 ORDEM DE IMPLEMENTAÇÃO

### ✅ FASE 1: BASE (30 min)
1. Deletar todos scripts antigos
2. Criar EventTypes.gd
3. Criar DiscreteEvent.gd  
4. Criar DiscreteEventScheduler.gd
5. Testar fila básica

### ✅ FASE 2: SEMÁFOROS (30 min)
6. Criar TrafficLightSystem.gd
7. Integrar com semáforos 3D existentes
8. Testar mudanças visuais
9. Criar eventos de semáforo

### ✅ FASE 3: CONTROLLER (30 min) 
10. Criar DiscreteTrafficSimulator.gd
11. Conectar EventScheduler + TrafficLights
12. Implementar processamento de eventos semáforo
13. Testar ciclo completo 40s

### ✅ FASE 4: VEÍCULOS (45 min)
14. Criar VehicleSystem.gd
15. Integrar com carros 3D existentes  
16. Implementar spawn/destroy
17. Adicionar eventos de veículos
18. Testar spawn automático

### ✅ FASE 5: UI (30 min)
19. Criar DiscreteUI.gd
20. Mostrar fila de eventos
21. Controles pause/velocidade
22. Testar tudo integrado

### ✅ FASE 6: POLISH (15 min)
23. Ajustar timing/distribuições
24. Melhorar UI/cores  
25. Teste final completo

---

## 🎯 CRITÉRIOS DE SUCESSO

### ✅ FUNCIONAL
- [ ] Eventos aparecem na UI em tempo real
- [ ] Semáforos mudam exatamente como simulator 3D  
- [ ] Carros spawnam e obedecem semáforos
- [ ] Controles pause/velocidade funcionam
- [ ] Fila de eventos sempre visível

### ✅ TÉCNICO  
- [ ] Zero duplicação de agendamento
- [ ] Responsabilidade única por arquivo
- [ ] Eventos discretos puros (tempo salta)
- [ ] UI atualizada via signals apenas
- [ ] Código limpo e bem documentado

---

## 🚨 REGRAS IMPORTANTES

### ❌ NÃO FAZER
- NÃO usar _process() para eventos discretos
- NÃO agendar o mesmo evento em 2 lugares  
- NÃO misturar lógica visual com lógica de eventos
- NÃO fazer polling/verificações contínuas
- NÃO deixar código antigo interferir

### ✅ FAZER
- ✅ Tempo avança apenas quando há eventos
- ✅ Cada evento agendado em 1 lugar só
- ✅ Separar visual 3D da lógica de eventos  
- ✅ Usar signals para comunicação
- ✅ Deletar código antigo completamente

---

**ESTE PLANO É NOSSA BÍBLIA. SEGUIR EXATAMENTE. SEM IMPROVISOS.**