# Mapeamento das Lógicas: Contínuo → Discreto

## 🚗 **PERSONALIDADES DOS MOTORISTAS**
Manter **exatamente igual** ao sistema contínuo:

```gdscript
# Do Car.gd original
AGGRESSIVE: speed=6.0, reaction=[0.5,0.8], following=0.8, yellow_prob=0.8
CONSERVATIVE: speed=4.5, reaction=[1.2,1.5], following=1.3, yellow_prob=0.2  
ELDERLY: speed=3.5, reaction=[1.5,2.0], following=1.5, yellow_prob=0.1
NORMAL: speed=5.0, reaction=[0.8,1.2], following=1.0, yellow_prob=0.5
```

## 🚦 **CICLO DE SEMÁFOROS** 
Do TrafficManager.gd original:

```
CYCLE_TIMES = {
    "main_road_green": 20.0s,  # West↔East (rua principal dupla)
    "cross_road_green": 10.0s, # South→North (rua secundária única)
    "yellow_time": 3.0s,
    "safety_time": 1.0s,
    "total_cycle": 40.0s  # Ciclo completo
}
```

**Estados por tempo:**
- 0-20s: Main road GREEN, Cross road RED
- 20-23s: Main road YELLOW, Cross road RED  
- 23-24s: Main road RED, Cross road RED (safety)
- 24-34s: Main road RED, Cross road GREEN
- 34-37s: Main road RED, Cross road YELLOW
- 37-40s: Main road RED, Cross road RED (safety)

## 📍 **DIREÇÕES E SPAWN POINTS**
Do SpawnSystem.gd original:

```
Direction.LEFT_TO_RIGHT (0):  West→East spawn(-35,0,-1.25)
Direction.RIGHT_TO_LEFT (1):  East→West spawn(35,0,1.25)  
Direction.BOTTOM_TO_TOP (3):  South→North spawn(0,0,35)
```

**Taxas de spawn:**
- west_east_rate: 0.055 (rua principal)
- east_west_rate: 0.055 (rua principal)
- south_north_rate: 0.025 (rua secundária)

## 🛑 **PONTOS CRÍTICOS DE PARADA**
Do Car.gd original - Estados de intersecção:

```gdscript
enum IntersectionState { 
    APPROACHING,  # Aproximando
    WAITING,      # Parado antes da faixa de pedestres
    PROCEEDING,   # Decidiu prosseguir
    CROSSING,     # Atravessando (NUNCA para!)
    CLEARING      # Saindo da intersecção
}
```

**POSIÇÕES EXATAS de parada:**
- Direction 0 (West→East): para em X=-7.0 (antes da faixa)
- Direction 1 (East→West): para em X=7.0 (antes da faixa)
- Direction 3 (South→North): para em Z=7.0 (antes da faixa)

## 📏 **CÁLCULOS DE DISTÂNCIA**
Do Car.gd original - IDM (Intelligent Driver Model):

```gdscript
func calculate_safe_following_distance() -> float:
    var base_distance = personality_config.following_distance_factor * 3.0
    var speed_factor = current_speed / max_speed
    return base_distance + speed_factor * 5.0  # 3-8 metros

func calculate_braking_distance() -> float:
    var decel = personality_config.deceleration
    return (current_speed * current_speed) / (2.0 * decel)
```

## 🚥 **LÓGICA DE SEMÁFORO AMARELO**
Do Car.gd original - Decisão crítica:

```gdscript
func should_stop_at_yellow() -> bool:
    var braking_distance = calculate_braking_distance()
    var distance_to_stop = distance_to_intersection
    var yellow_prob = personality_config.yellow_light_probability
    
    if braking_distance > distance_to_stop:
        return false  # Muito perto, continua
    elif distance_to_stop > braking_distance * 2.0:
        return true   # Longe, para
    else:
        return randf() < yellow_prob  # Zona cinzenta - personalidade decide
```

## 📊 **SISTEMA DE FILAS**
Do SpawnSystem.gd original:

```
min_spawn_distance: 10.0     # Distância mínima entre carros
max_queue_length: 4          # Máximo de carros na fila
can_spawn_safely(): verifica se tem espaço
has_space_for_queueing(): permite fila mesmo com semáforo vermelho
```

## ⏱️ **RUSH HOUR MULTIPLIERS**
Do SpawnSystem.gd original:

```
7-9h: 2.0x (rush matinal)
12-14h: 1.5x (almoço)  
17-19h: 2.5x (rush vespertino)
22-6h: 0.3x (madrugada)
Outros: 1.0x (normal)
```

---

## 🔄 **ADAPTAÇÃO PARA EVENTOS DISCRETOS**

### **Principais Desafios:**

1. **Movimento Contínuo → Eventos Discretos**
   - Atual: posição atualizada a cada frame
   - Novo: posição calculada apenas em eventos específicos

2. **IDM Contínuo → Cálculo de Tempos de Viagem** 
   - Atual: acelera/desacelera suavemente
   - Novo: calcular tempo total de viagem por segmento

3. **Detecção de Colisão → Sistema de Filas**
   - Atual: detecta carros próximos a cada frame
   - Novo: sistema de fila que agenda próximo carro

4. **Estados de Intersecção → Eventos de Decisão**
   - Atual: verifica semáforo a cada frame
   - Novo: evento de "chegada na intersecção" que toma decisão

### **Solução Proposta:**

```gdscript
# DiscreteCar.gd - Representação lógica
class_name DiscreteCar
var car_id: int
var personality: DriverPersonality
var current_segment: String  # "spawn_to_intersection", "intersection_to_exit"  
var travel_start_time: float
var estimated_arrival_time: float

# VehicleJourney.gd - Cálculo de tempos
func calculate_travel_time(from_pos: Vector3, to_pos: Vector3, personality: DriverPersonality) -> float:
    var distance = from_pos.distance_to(to_pos)  
    var speed = PERSONALITIES[personality].base_speed
    return distance / speed  # Tempo base, pode adicionar variações
```

## ✅ **VALIDAÇÃO**
Todos os valores e lógicas devem produzir **resultados idênticos** ao simulador contínuo:
- Mesmo throughput de carros
- Mesmos tempos de espera  
- Mesma distribuição de personalidades
- Mesmo comportamento em rush hour