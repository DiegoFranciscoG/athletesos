# Investigación — Notificaciones tácticas + hidratación dinámica

Alcance: solo la funcionalidad de recordatorios en segundo plano y seguimiento de
hidratación (feature elegida como primera del backlog de "AthleteOS mega-prompt").
Se irán añadiendo secciones nuevas a medida que se investiguen otras features.

| Fuente | URL | Fecha de consulta | Qué regla/dato sale de ahí |
|---|---|---|---|
| pub.dev — `flutter_local_notifications` | https://pub.dev/packages/flutter_local_notifications | 2026-09-22 | Versión estable actual 22.3.1 (proyecto usa 17.2.4, hay que evaluar upgrade). Android 13+ requiere `SCHEDULE_EXACT_ALARM` (o `USE_EXACT_ALARM`) para alarmas exactas; Android 14+ exige `RECEIVE_BOOT_COMPLETED` para volver a programar tras reinicio. Notificaciones diarias recurrentes se programan con `zonedSchedule(..., matchDateTimeComponents: DateTimeComponents.time)`, no con `showDailyAtTime` (deprecado). |
| pub.dev — `workmanager` | https://pub.dev/packages/workmanager | 2026-09-22 | Versión estable 0.10.10. Es un wrapper de Android WorkManager; no da garantía de horario exacto. |
| Android Developers (oficial) — Define work requests | https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work | 2026-09-22 | **Intervalo mínimo de un `PeriodicWorkRequest` es 15 minutos** (mismo límite que `JobScheduler`). El sistema **no garantiza puntualidad**: Doze/App Standby y las restricciones (red, batería) pueden retrasar la ejecución. Conclusión de diseño: WorkManager sirve para sincronización periódica en segundo plano (ej. reenviar registros de hidratación pendientes), **no** para recordatorios que deben sonar a una hora exacta — eso lo cubre `flutter_local_notifications` con `zonedSchedule`. |
| ACSM (American College of Sports Medicine) — Position Stand: Exercise and Fluid Replacement | https://pubmed.ncbi.nlm.nih.gov/17277604/ | 2026-09-22 | Pre-entreno: ~500 ml de líquido 2 h antes. Durante ejercicio intenso >1 h: 600–1200 ml/hora (o 200–300 ml cada 10–20 min). Objetivo: evitar pérdida de peso corporal por deshidratación >2%. Fuente revisada por pares / posición oficial de una sociedad científica reconocida — cumple el estándar "fuente confiable" del proyecto. |
| National Academies of Sciences, Engineering and Medicine (antes Institute of Medicine) — Dietary Reference Intakes for Water | https://www.nationalacademies.org/news/report-sets-dietary-intake-levels-for-water-salt-and-potassium-to-maintain-health-and-reduce-chronic-disease-risk | 2026-09-22 | Ingesta adecuada (AI) de agua total (bebida + alimentos): **hombres ≈ 3.7 L/día, mujeres ≈ 2.7 L/día**. ~80% de esa agua viene de bebidas, ~20% de alimentos → línea base de bebida sola ≈ 3.0 L/día (hombre). Esta es la meta base del modelo; el ajuste dinámico por entrenamiento usa el rango ACSM de arriba (se suma, no reemplaza, en los días con sesión de fútbol/gym). |

## Decisiones de diseño derivadas de la investigación

1. **Dos mecanismos, no uno**: `flutter_local_notifications.zonedSchedule` para
   recordatorios con hora fija (agua cada N minutos durante ventana de
   actividad, aviso pre-entreno 15 min antes, desconexión circadiana a hora
   fija). `workmanager` solo para sincronizar con el backend registros de
   hidratación/hábitos hechos offline — nunca para decidir cuándo notificar,
   porque no tiene garantía de horario.
2. **Meta de hidratación dinámica** = 3.0 L base (bebida, ajustado a que el
   usuario es hombre) + bono por sesión de fútbol/gym programada ese día,
   usando el punto medio ACSM de 900 ml/hora de sesión (dentro del rango
   600–1200 ml/h). La lógica de cálculo vive en Postgres (consistente con la
   arquitectura database-first ya usada en el resto del proyecto), no
   hardcodeada en Dart.
3. **Persistencia**: hidratación necesita registro incremental (+300 ml, +500
   ml...) a lo largo del día, algo que la tabla `habito`/`registro_habito`
   existente no soporta (son booleanos completado/no completado). Se necesita
   una tabla nueva — ver `docs/modelo-datos.md`.
