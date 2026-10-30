---
name: flymoney-execute-stage
description: Execute one explicitly authorized FlyMoney roadmap stage, from its approved plan through implementation, verification, and Obsidian status updates. Use for requests to implement a stage, not roadmap discussion or status questions.
---

# Ejecutar una etapa de FlyMoney

Este skill ejecuta **una sola etapa por invocación**. Una pregunta sobre el roadmap, una solicitud de revisar el plan o «¿cómo seguimos?» no autoriza cambios de código. Ejecuta la etapa cuando el usuario pida explícitamente implementarla o use `$flymoney-execute-stage`.

## Fuentes y límites

- Lee `/Users/jheisecke/Documents/Obsidian/flymoney/CLAUDE.md` y `Roadmap.md`; sigue los enlaces de la etapa elegida a su nota de alcance y plan. Los documentos pueden estar en carpetas diferentes.
- Lee `Reference/Decisions.md`, `Reference/Architecture.md`, `Reference/Coding Standards.md` y las instrucciones pertinentes de este repo antes de planificar o implementar.
- El contrato de la etapa y las decisiones registradas en Obsidian definen el comportamiento. No inventes requisitos ni cambies decisiones bloqueadas.
- Mantén el trabajo dentro de la etapa. Registra hallazgos fuera de alcance para tratarlos después; no los implementes como extras.

## Elegir roadmap y etapa

1. Resuelve un único roadmap antes de buscar una etapa. Usa el roadmap, funcionalidad o etapa que el usuario nombre si la referencia es inequívoca. Si no nombra ninguno, usa el contexto activo solo cuando identifique un roadmap sin ambigüedad; si hay varias opciones, pregunta cuál elegir antes de cambiar estados o código.
2. Sigue los enlaces de `Roadmap.md`; no concluyas que falta un plan mirando una sola carpeta.
3. Elige la etapa de implementación pendiente más temprana que cumpla sus dependencias. Si el usuario nombró una etapa concreta, comprueba sus dependencias. No saltes una etapa bloqueada ni marques como implementación una fila solo de diseño.
4. Registra el `git status` inicial y conserva los cambios preexistentes del usuario.

## Plan y autorización

- Antes de tocar código, lee la nota de alcance y el plan enlazados para la etapa.
- Si el plan falta o está desactualizado, prepara o corrige el plan en la ubicación que indica el roadmap. Debe cubrir alcance y exclusiones, arquitectura y archivos afectados, pasos, criterios de aceptación, pruebas/verificación y riesgos relevantes. Actualiza el estado del roadmap según el progreso real.
- **No implementes hasta que el plan esté aprobado por el usuario.** Si la invocación autoriza explícitamente la etapa pero el plan aún necesita aprobación, termina con el plan listo para revisar y solicita esa aprobación; no infieras aprobación del pedido de implementar.
- No alteres el alcance del plan para justificar atajos. Si una decisión de producto no está documentada, detente en esa decisión y pregunta; continúa solo el trabajo independiente.

## Implementación

- Sigue Clean Architecture + MVVM y la dirección `Presentation → Domain ← Data`. Mantén el dominio independiente de SwiftUI y persistencia; ViewModels dependen de protocolos de casos de uso; la composición de dependencias vive en `AppAssembly`.
- Respeta las decisiones y límites de `CLAUDE.md`: iOS 18+, Swift 6, SwiftData en Data, DI manual, sin dependencias externas nuevas sin aprobación, sin UIKit salvo excepción documentada y sin archivos fuente antes de aprobar el plan.
- Aplica las skills disponibles adecuadas al cambio, según `CLAUDE.md`: `architecture-skill`, `swift-language-skill`, `swiftui-skill`, `i18n-skill`, `swift-concurrency-expert`, `swift-testing-skill`, `core-data-expert` e `ios-debugger-skill` cuando correspondan. No afirmes haberlas aplicado si no están disponibles.
- Añade cobertura con Swift Testing junto con los cambios de producción. Conserva accesibilidad, localización, Dynamic Type y el encabezado estándar requerido para cada archivo Swift.
- Implementa únicamente esta etapa. Deja el roadmap en progreso mientras haya trabajo activo y comunica archivos cambiados, decisiones técnicas y cualquier desvío del plan.

## Revisión y cierre

1. Revisa el diff contra cada criterio de aceptación de la etapa y su plan. Comprueba que no se hayan incluido cambios fuera de alcance ni alterado trabajo preexistente.
2. Ejecuta las verificaciones focalizadas definidas en el plan, incluyendo build para simulador iOS 18 cuando corresponda. Atiende los fallos y repite las verificaciones afectadas; no declares éxito si una comprobación requerida falla o no se pudo realizar.
3. Si hay hallazgos corregibles, corrígelos y repite la revisión. Si un bloqueo requiere una decisión del usuario, deja el estado real y pide esa decisión.
4. Solo al cumplir los criterios, actualiza `Roadmap.md` y marca las casillas de aceptación en la nota/plan de etapa, tal como indica `CLAUDE.md`. No reescribas el plan para ocultar divergencias; explica cualquier trabajo diferido.
5. Resume qué se implementó, cómo se verificó, qué documentos de Obsidian se actualizaron y qué queda pendiente.

No hagas commit, PR, publicación ni despliegue como parte de este flujo salvo que el usuario lo pida por separado.
