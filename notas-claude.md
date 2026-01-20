# Notas sobre Organización de Agentes en Claude Code

## Estrategias de Organización Multi-Agente

### 1. **Ejecución en Paralelo vs Secuencial**
- **Paralelo**: Tareas independientes (búsquedas, análisis de diferentes archivos)
  ```
  - Buscar implementación de X
  - Buscar documentación de Y
  - Analizar rendimiento de Z
  ```
- **Secuencial**: Tareas con dependencias (una necesita el resultado de otra)
  ```
  - Explorar código → Diseñar plan → Implementar → Probar
  ```

### 2. **Agentes Especializados Disponibles**

**Para tu proyecto de física cuántica:**
- `Explore`: Búsquedas rápidas en el código
- `Plan`: Diseñar estrategias antes de implementar
- `python-pro`: Optimización de scripts de visualización
- `performance-engineer`: Analizar cuellos de botella en simulaciones
- `refactoring-specialist`: Mejorar estructura del código Fortran/Python

### 3. **Agentes Orchestrator/Coordinator**

Los agentes de orquestación (`multi-agent-coordinator`, `workflow-orchestrator`, `agent-organizer`) tienen roles específicos:

- **multi-agent-coordinator**: Coordina múltiples agentes en workflows complejos con dependencias
- **workflow-orchestrator**: Diseña procesos complejos con estados y transacciones
- **agent-organizer**: Selecciona y ensambla equipos de agentes para tareas específicas
- **task-distributor**: Distribuye trabajo balanceado entre múltiples agentes

**Cuándo usarlos:**
- Proyectos con 5+ subtareas interdependientes
- Necesitas orquestación automática de agentes especializados
- Quieres delegar la estrategia de ejecución

### 4. **Mejores Prácticas para tu Caso**

Para tu simulación de tunelamiento cuántico:

**Tarea simple** (1 agente):
```
"Optimiza la visualización en grafica/densidades_y_potencial.py"
→ Uso directo de python-pro
```

**Tarea compleja** (múltiples agentes en paralelo):
```
"Analiza rendimiento y mejora documentación"
→ performance-engineer + documentation-engineer en paralelo
```

**Proyecto grande** (orchestrator):
```
"Refactoriza todo el sistema de visualización"
→ workflow-orchestrator coordina:
  - Explore (mapear código)
  - Plan (diseñar arquitectura)
  - refactoring-specialist (ejecutar cambios)
  - test-automator (validar)
```

### 5. **Recomendación Práctica**

Para maximizar eficiencia:
1. **Tareas pequeñas**: Hazlas tú directamente
2. **2-3 tareas independientes**: Lánzalas en paralelo manualmente
3. **Workflows complejos**: Usa un orchestrator que coordine automáticamente

---

*Notas generadas el 2026-01-20*
