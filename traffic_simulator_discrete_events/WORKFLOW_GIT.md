# Workflow Git para Simulador de Eventos Discretos

## Estrutura de Branches

### Branch Principal
- `main` - Código estável e validado

### Branches de Desenvolvimento
- `sprint-1-event-system` - Sprint 1: Core Event System
- `sprint-2-discrete-vehicles` - Sprint 2: Sistema de Veículos Discretos
- `sprint-3-traffic-lights` - Sprint 3: Sistema de Semáforos Discretos
- `sprint-4-hybrid-rendering` - Sprint 4: Sistema Híbrido de Renderização
- `sprint-5-analytics` - Sprint 5: Analytics e Otimização

## Processo de Sprint

### 1. Início do Sprint
```bash
git checkout main
git pull origin main
git checkout -b sprint-X-description
```

### 2. Durante o Sprint
- Commits frequentes com mensagens descritivas
- Testes locais de cada feature implementada
- Documentação atualizada

### 3. Fim do Sprint - VALIDAÇÃO OBRIGATÓRIA
**❌ NÃO FAZER MERGE SEM VALIDAÇÃO COMPLETA**

#### Checklist de Validação:
- [ ] Código compila sem erros
- [ ] Todas funcionalidades do sprint implementadas
- [ ] Testes manuais realizados
- [ ] Performance aceitável
- [ ] Documentação atualizada
- [ ] Nenhum bug crítico identificado

#### Comandos de Finalização:
```bash
# 1. Validar localmente
godot --headless --check-only

# 2. Commit final
git add .
git commit -m "feat: Sprint X - [description] - VALIDATED"

# 3. Push para remote
git push origin sprint-X-description

# 4. Criar PR/Merge para main
git checkout main
git merge sprint-X-description

# 5. Push main apenas APÓS validação completa
git push origin main

# 6. Limpar branch de desenvolvimento
git branch -d sprint-X-description
```

## Convenções de Commit

### Formato:
`tipo: escopo - descrição`

### Tipos:
- `feat`: Nova funcionalidade
- `fix`: Correção de bug
- `docs`: Documentação
- `style`: Formatação
- `refactor`: Refatoração de código
- `test`: Testes
- `chore`: Tarefas gerais

### Exemplos:
```
feat: event-scheduler - implementa fila de eventos ordenada por tempo
fix: discrete-car - corrige cálculo de tempo de viagem
docs: plano - atualiza arquitetura com sistema preditivo
```

## Estrutura de Pastas

```
traffic_simulator_discrete_events/
├── scripts/
│   ├── core/                 # Sprint 1
│   │   ├── DiscreteEventScheduler.gd
│   │   ├── DiscreteEvent.gd
│   │   └── SimulationClock.gd
│   ├── entities/             # Sprint 2
│   │   ├── DiscreteCar.gd
│   │   └── VehicleJourney.gd
│   ├── traffic/              # Sprint 3
│   │   ├── DiscreteTrafficManager.gd
│   │   └── TrafficQueue.gd
│   └── rendering/            # Sprint 4
│       ├── HybridRenderer.gd
│       └── CarVisualProxy.gd
├── scenes/
│   └── Main.tscn
├── docs/
│   ├── PLANO_DISCRETO.md
│   ├── WORKFLOW_GIT.md
│   └── sprint_reports/
└── tests/
    └── validation_scripts/
```

## Regras Importantes

1. **🚫 NUNCA fazer push para main sem validação**
2. **✅ Todo commit deve ser funcional**  
3. **📝 Documentar mudanças significativas**
4. **🧪 Testar antes de finalizar sprint**
5. **🔄 Backup de segurança antes de merges grandes**