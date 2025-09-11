# PLANO DE UI PARA O PROFESSOR
## Simulador de Tráfego Híbrido

### 📋 OBJETIVO
Criar interface simples e funcional com **3 seções principais** conforme solicitado:
1. **Tabela de Estatísticas** - Métricas em tempo real
2. **Gráfico de Distribuição de Frequência** - Eventos do sistema  
3. **Painel de Controle Interativo** - Controles de simulação

---

## 🎯 ESPECIFICAÇÕES TÉCNICAS

### **SEÇÃO 1: Tabela de Estatísticas**
**Arquivo:** `StatisticsTable.gd`
**Posição:** Superior esquerda
**Tamanho:** 400x300px

**Métricas exibidas:**
- ⏱️ Tempo de simulação atual
- 🚗 Carros ativos na simulação  
- 📊 Total de carros processados (spawned/despawned)
- 🚦 Estado atual dos semáforos (S1, S2, S3)
- ⚡ Velocidade média dos veículos
- 🛑 Total de paradas nos semáforos
- 📈 Throughput (carros/minuto)
- 🚥 Tempo médio de espera nos semáforos

**Update:** A cada 1 segundo (performance otimizada)

### **SEÇÃO 2: Gráfico de Frequência de Eventos**
**Arquivo:** `EventFrequencyChart.gd`  
**Posição:** Superior direita
**Tamanho:** 500x300px

**Eventos trackados:**
- `car_spawned` (Verde)
- `car_despawned` (Vermelho) 
- `traffic_light_changed` (Amarelo)
- `car_stopped` (Laranja)
- `car_started` (Azul)

**Tipos de visualização:**
- Gráfico de barras (frequência total)
- Timeline de eventos (últimos 50 eventos)
- Botão para alternar entre modos

### **SEÇÃO 3: Painel de Controle Interativo**
**Arquivo:** `InteractiveControls.gd`
**Posição:** Inferior (largura completa)  
**Tamanho:** 900x200px

**Controles disponíveis:**

#### **Simulação:**
- ▶️/⏸️ Play/Pause
- 🔄 Reset completo
- ⚡ Speed multiplier (0.5x, 1x, 2x, 5x)

#### **Semáforos:**
- 🚦 **S1/S2 (Rua Principal):** Slider para duração do ciclo (15-60s)
- 🚦 **S3 (Rua Transversal):** Slider para duração do ciclo (10-45s)
- 🔄 Sincronização de semáforos (On/Off)
- 🟢 Forçar estado manualmente (RED/YELLOW/GREEN)

#### **Spawn de Carros:**
- 🚗 Taxa de spawn (slider 0.1-10x)
- 🎯 Máximo de carros simultâneos (5-50)
- 📍 Taxa por direção (Oeste→Leste, Leste→Oeste, Sul→Norte)

---

## 🏗️ ARQUITETURA DA SOLUÇÃO

### **Estrutura de Arquivos:**
```
traffic_simulator_hybrid/scripts/ui_nova/
├── SimpleUI.gd              # Manager principal (150 linhas max)
├── StatisticsTable.gd       # Tabela de stats (100 linhas max)  
├── EventFrequencyChart.gd   # Gráfico simples (80 linhas max)
└── InteractiveControls.gd   # Painel de controles (120 linhas max)
```

### **Princípios de Design:**
1. **Simplicidade:** Máximo 450 linhas de código total
2. **Performance:** Updates incrementais, sem recrear UI
3. **Modularidade:** Cada seção é independente
4. **Responsividade:** Layout funciona em diferentes resoluções

---

## 📋 PLANO DE EXECUÇÃO

### **FASE 1: Setup Base** (15 min)
- [ ] Criar estrutura de pastas `ui_nova/`
- [ ] Criar `SimpleUI.gd` com layout básico (GridContainer 2x2)
- [ ] Configurar referencias aos sistemas do backend
- [ ] Testar integração básica

### **FASE 2: Tabela de Estatísticas** (20 min)  
- [ ] Criar `StatisticsTable.gd` com TableContainer
- [ ] Implementar coleta de dados básicos
- [ ] Adicionar formatação de valores (tempo, percentagens)
- [ ] Testar updates em tempo real

### **FASE 3: Gráfico de Frequência** (25 min)
- [ ] Criar `EventFrequencyChart.gd` com _draw() customizado  
- [ ] Implementar modo barra (frequência total)
- [ ] Implementar modo timeline (eventos recentes)
- [ ] Adicionar botão toggle entre modos

### **FASE 4: Painel de Controles** (30 min)
- [ ] Criar `InteractiveControls.gd` com seções organizadas
- [ ] Implementar controles de simulação (play/pause/reset/speed)
- [ ] Adicionar sliders para tempo de semáforos
- [ ] Conectar controles com sistemas backend

### **FASE 5: Integração e Polish** (10 min)
- [ ] Integrar nova UI no Main.gd  
- [ ] Remover UI antiga temporariamente
- [ ] Ajustar posicionamento e tamanhos
- [ ] Testes finais e debug

---

## 🎨 LAYOUT FINAL

```
┌─────────────────────────────────────────────────────┐
│  📊 ESTATÍSTICAS        📈 GRÁFICO DE FREQUÊNCIA    │
│  ┌─────────────────┐     ┌─────────────────────────┐│
│  │• Tempo: 05:23   │     │     ▁▂▃▄▅▆█ EVENTOS    ││
│  │• Carros: 12     │     │   🟢🔴🟡🟠🔵           ││  
│  │• Spawned: 45    │     │   [BARRAS] [TIMELINE]   ││
│  │• S1/S2: VERDE   │     │                         ││
│  │• S3: VERMELHO   │     │                         ││
│  │• Velocidade:    │     │                         ││
│  │  28.5 km/h      │     │                         ││
│  │• Throughput:    │     │                         ││  
│  │  8.2 carros/min │     │                         ││
│  └─────────────────┘     └─────────────────────────┘│
├─────────────────────────────────────────────────────┤
│  🎮 CONTROLES INTERATIVOS                           │
│  ┌─SIMULAÇÃO──┐ ┌─SEMÁFOROS────┐ ┌─SPAWN──────────┐ │
│  │▶️ PAUSAR    │ │S1/S2: [===|=] │ │Taxa: [====|===]│ │
│  │🔄 RESET     │ │S3:    [==|===]│ │Max:  [====|===]│ │  
│  │⚡ Speed: 2x │ │🔄 Sync: ✅    │ │O→L:  [===|====]│ │
│  └────────────┘ └──────────────┘ └────────────────┘ │
└─────────────────────────────────────────────────────┘
```

---

## ✅ CRITÉRIOS DE SUCESSO

1. **Funcionalidade:** Todas as métricas são exibidas corretamente
2. **Performance:** UI roda a 60fps sem lag  
3. **Interatividade:** Todos os controles afetam a simulação
4. **Simplicidade:** Código limpo, fácil de entender
5. **Apresentável:** Interface profissional para o professor

---

## 🚀 PRÓXIMOS PASSOS

**COMEÇAR AGORA:**
1. Executar Fase 1 (Setup Base)
2. Testar se integração funciona
3. Prosseguir fase por fase
4. Cada fase deve ser testada antes de continuar

**TEMPO ESTIMADO TOTAL:** ~100 minutos
**OBJETIVO:** Interface funcional para apresentação ao professor