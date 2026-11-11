# PROMPT PARA OPENCODE — Demo del proyecto #69 "Cámaras y accesos" (Erlang/OTP)

## 0. Rol y contexto

Eres mi pair-programmer senior en Erlang/OTP, trabajando dentro de **opencode**. Trabajamos en el proyecto **#69 — Cámaras y accesos** (dominio *Seguridad y ciudad*: bitácora de eventos y búsqueda por rango de tiempo) para la materia **Programación Lógica y Funcional** (5.º semestre, Ing. de Sistemas). Soy **Diego Antonio Barboza Carballo**.

Entorno: **Ubuntu 26.04 sobre WSL2**, usando opencode (CLI). Las reglas permanentes del proyecto están en `AGENTS.md`; léelo y respétalo. El directorio actual es la raíz del proyecto (`69-camaras-y-accesos/`), clonado del repo `https://github.com/l23212044/erlang-proyectos` (carpeta del proyecto 69).

**Objetivo de esta sesión:** producir el **entregable de la DEMO** (Demo UI Erlang). Todo lo que hagas se evalúa con la rúbrica de la sección 2. Optimiza para sacar **"Excelente"** en cada criterio, pero **sin mentir ni simular**: si algo no está hecho o no lo verificaste, lo dices.

## 1. Primero: lee y entiende (no escribas código todavía)

Lee completo, en este orden:

1. `problema/readme.md` — el problema, escenario a simular, casos difíciles, qué se debe entregar.
2. `README.md` — arranque, pendientes y **diseño OTP sugerido** (gen_server por cámara/lector, ETS `ordered_set` indexada por tiempo, supervisor por sitio con la bitácora aislada, API REST + WebSocket con cowboy, métricas con recon, prueba de caos).
3. `design/PROMPT_STITCH.md` — pantallas mínimas para Google Stitch.
4. `rebar.config`, `config/sys.config`, `config/vm.args`, `src/*`, `test/*` — el esqueleto actual (módulos `p69_camaras_y_accesos_*`, deps `cowboy 2.12.0` y `recon 2.5.6`, `warnings_as_errors` activo).

Esta primera parte se hace en el agente **plan** (solo lectura; yo cambio al agente **build** con `Tab` cuando apruebe). Muéstrame en el chat un plan por fases (sección 4) con los módulos que crearás y las decisiones de diseño principales, usa la lista de tareas (`todowrite`) para llevar el avance, y **espera mi aprobación** antes de implementar.

## 2. Rúbrica de la demo (criterios de evaluación)

Cada criterio se califica Excelente / Bueno / Aceptable / Insuficiente / Deficiente. Meta: **Excelente en todos**.

| # | Criterio | Qué se necesita para "Excelente" | Qué debes producir |
|---|---|---|---|
| 1 | Solución funcional en Erlang | Solución completa o superior al problema, bien implementada, con uso claro de programación funcional, concurrencia/procesos y resultados verificables en la demo | Backend OTP completo (sección 3) |
| 2 | Montaje y ejecución en VM | Corre en una VM/entorno definido, configuración clara, estable y demostrable | Release + systemd + script de setup reproducible (sección 3.7) |
| 3 | Demostración | Flujo completo: entradas, salidas, casos principales, evidencias | `docs/GUION_DEMO.md` + `scripts/demo.sh` (sección 3.10) |
| 4 | Diseño UIX con Google Stitch | UIX coherente, usable, navegación clara, hecha **con Google Stitch** | Prompt de Stitch afinado + integración del export (sección 5) |
| 5 | Manual de uso en Gist | Manual completo para el cliente: propósito, instalación/acceso, pasos, ejemplos, capturas, solución de problemas | `docs/MANUAL_GIST.md` listo para publicar (sección 6) |
| 6 | Calidad técnica del código | Bien estructurado, modular, legible, comentado, buenas prácticas de Erlang | Convenciones de la sección 7 |
| 7 | Integración backend–entorno–UIX | Lógica Erlang + VM + UI funcionando como una experiencia consistente y verificable | UI consume la API real; sección 5 |
| 8 | Presentación y argumentación técnica | Explicar con seguridad problema, solución, decisiones y uso de Erlang; responder preguntas | `docs/DISENO_OTP.md` + preguntas y respuestas en el guion |

## 3. Requisitos técnicos del backend

Respeta las convenciones del esqueleto (prefijo `p69_camaras_y_accesos_`, o un prefijo corto `p69_` consistente en módulos nuevos; código en ASCII sin acentos; comentarios en español).

### 3.1 Modelo de datos

Evento: `id/seq` monotónico por llegada, `dispositivo_id`, `tipo_dispositivo` (puerta | camara), `edificio`, `tipo_evento` (ej. puerta_abierta, tarjeta_leida, movimiento, alarma, offline, online), `persona` (opcional, anonimizable), `ts_evento` (lo que reporta el dispositivo), `ts_corregido` (tras corrección de reloj), `ts_recepcion`, `hash_prev`, `hash`.

### 3.2 Árbol de supervisión (justifica cada decisión frente a los casos difíciles)

Diseña y documenta quién reinicia a quién y por qué. Punto de partida (puedes mejorarlo, justificando):

- Supervisor raíz → `bitacora_sup` (**aislada**: dueña de las tablas ETS y del log en disco, estrategia pensada para que un fallo de dispositivos/consultas/API **no** destruya la bitácora), `sitio_sup` por edificio/sitio (supervisor dinámico de `dispositivo` gen_servers: ~100 puertas + ~200 cámaras, estado propio: último latido, offset de reloj, contadores), `consultas_sup` (procesos efímeros por consulta), `retencion` (gen_server), `metricas`, y el listener de cowboy.
- Estrategias: elige `one_for_one` / `rest_for_one` / `simple_one_for_one` (o `DynamicSupervisor` equivalente en OTP) con justificación; define `intensity/period` razonables.
- Las tablas ETS deben sobrevivir a la caída de procesos clientes (dueño estable o patrón `heir`).

### 3.2.1 "La bitácora no perdió nada" (pregunta guía 1)

- **Persistencia previa al ACK**: write-ahead log en disco (`disk_log` de OTP o equivalente) antes de confirmar el evento; al arrancar, **reconstruir las ETS** desde el log (caso "reinicio con eventos aún en memoria").
- **Ingesta sin pérdida en picos (2,000 ev/s)**: buffer/batching, medición de cola, y política de *backpressure* explícita (p. ej. responder 429/503 con `Retry-After` en vez de descartar en silencio). Documenta la política.
- **Inmutabilidad**: encadenar registros con SHA-256 (`hash = H(hash_prev || registro)`); endpoint que **verifica la cadena** y detecta manipulación (incluye una demo en la que alteras un registro y la verificación falla).

### 3.2.2 Organización para buscar por rango (pregunta guía 2)

- ETS `ordered_set` con llave `{ts, seq}` y búsqueda por rango con `ets:select`/`ets:next` **sin recorrer toda la tabla**; índices secundarios por edificio y dispositivo.
- **Segmentación por tiempo** (p. ej. una tabla por hora/día) para que la retención sea soltar segmentos completos.

### 3.3 Casos difíciles (todos deben estar implementados y demostrables)

1. **Eventos tardíos con marca de tiempo antigua**: se insertan en su posición correcta del índice por tiempo; la cadena de hashes sigue el **orden de llegada** (`seq`), no el de `ts_evento` — documenta por qué.
2. **Reloj desajustado (4 min de atraso)**: estimar offset por dispositivo (diferencia `ts_recepcion − ts_evento`, robusta, p. ej. mediana), guardar `ts_evento` crudo **y** `ts_corregido`, permitir buscar por tiempo corregido, y marcar el dispositivo con alerta de "reloj desfasado".
3. **Retención/borrado sin afectar consultas en curso**: una consulta debe poder terminar con una vista consistente aunque el proceso de retención corra a la vez (p. ej. segmentos marcados como expirados y borrados solo cuando no hay consultas leyéndolos). El borrado queda registrado en la cadena (checkpoint) para que la verificación siga siendo válida.
4. **Reinicio con eventos en memoria**: ver 3.2.1.

### 3.4 API (cowboy 2.x)

- `POST /api/eventos` (uno o lote)
- `GET /api/eventos?desde=&hasta=&camara=&edificio=&tipo=&persona=` (rango de tiempo ISO-8601 o epoch; paginación)
- `GET /api/dispositivos` y `GET /api/dispositivos/:id` (estado: ok / alerta / falla, último latido, offset de reloj, eventos recientes)
- `GET /api/alertas`
- `GET /api/bitacora/verificar`
- `GET /api/salud`
- `GET /metrics` (eventos por cámara, cámaras offline, latencia de consultas de rango, cola de ingesta, tamaño de segmentos)
- `WS /ws/eventos` (eventos nuevos y cambios de estado en tiempo real)
- Servir estáticos desde `priv/www/` (la UI de Stitch).
- JSON: si OTP ≥ 27, usa el módulo estándar `json` (menos dependencias); si no, justifica la librería elegida.
- Validación de entrada y errores HTTP coherentes (400/404/429/503), sin que un request malformado tumbe procesos.

### 3.5 Simulador y fallas inyectadas

Módulo/CLI que simule el **escenario del problema**: 100 puertas + 200 cámaras, **150 ev/s promedio con picos de 2,000 ev/s**, generación de datos históricos ("el mes pasado") para la búsqueda de un edificio entre dos horas, un dispositivo con reloj 4 min atrasado, eventos tardíos, dispositivos que pasan a offline. Configurable (duración, tasa, semilla).

### 3.6 Prueba de caos (documentada con resultados REALES)

Script reproducible que: carga millones de eventos, lanza una consulta de rango **mientras sigue la ingesta** (medir que no se bloquea), mata procesos (un dispositivo, un `sitio_sup`, el proceso de retención, un proceso de consulta, y —con cuidado— el dueño de la bitácora) y verifica recuperación y ausencia de pérdida. Escribe `docs/CAOS.md` con: *qué maté, qué esperaba, qué ocurrió*, con **números medidos**. Nada de cifras inventadas: si no lo mediste, no lo escribas.

### 3.7 Entorno y release

- Verifica con `erl -noshell -eval '...'` la versión de OTP instalada y `rebar3 version`. Si falta Erlang/rebar3 o son incompatibles con cowboy 2.12 / `warnings_as_errors`, **propón** la instalación (apt, o mise/asdf/kerl) y **pídeme confirmación antes de usar `sudo`** o instalar nada. Si cowboy 2.12.0 no compila con la versión de OTP, sube a la última 2.x compatible y justifícalo.
- `scripts/setup.sh` idempotente que deje la máquina lista (dependencias, compile, release) — reproducible también en una VM Ubuntu de AWS Academy.
- `rebar3 as prod release` funcional; unidad **systemd** (`deploy/p69.service`) con instrucciones; comprueba si WSL tiene systemd habilitado (`/etc/wsl.conf`) y, si no, documenta cómo activarlo o usa el script de arranque del release.
- Ajusta `config/vm.args` a los núcleos reales de la máquina (`nproc`) y cambia la cookie por una generada (no dejar `cambiar_en_produccion`).
- La UI debe ser alcanzable desde el navegador de Windows (`localhost:PUERTO`); el listener debe escuchar donde corresponda.

### 3.8 Pruebas

`rebar3 compile` y `rebar3 eunit` **en verde** (con `warnings_as_errors`). Pruebas unitarias de: búsqueda por rango, evento tardío, corrección de reloj, cadena de hashes (incluida detección de alteración), retención con consulta en curso, recuperación desde el log y validación de la API. Opcional: `rebar3 proper` si aporta.

### 3.9 Documentación técnica (para sustentar)

- `docs/DISENO_OTP.md`: procesos, supervisores, quién reinicia a quién, justificación frente a cada caso difícil, diagrama (Mermaid).
- `docs/SUPUESTOS.md`: lista de supuestos propios y **cifras del documento del problema que verificaste** (si tienes acceso web, verifícalas con fuentes vigentes y cita; si no, márcalas "no verificadas" — **no inventes fuentes**).
- Actualiza `README.md` (equipo, arranque, pendientes reales marcados).

### 3.10 Material de la demo

- `scripts/demo.sh`: deja el sistema en estado limpio y listo para la presentación (arranca release, carga datos, abre el flujo).
- `docs/GUION_DEMO.md`: guion cronometrado (~10 min) con el **flujo completo** (arranque en la VM → dashboard en tiempo real → simulación de picos → búsqueda por rango de un edificio → dispositivo con reloj atrasado → verificación de la cadena + alteración detectada → borrado por retención durante una consulta → prueba de caos en vivo). Incluye una sección **"Preguntas probables y respuestas"** a nivel de 5.º semestre: ¿por qué Erlang/OTP?, ¿por qué `gen_server` y no procesos sueltos?, "let it crash" y supervisión, ¿por qué ETS `ordered_set` y no una BD?, concurrencia por paso de mensajes vs. memoria compartida, inmutabilidad y programación funcional en el diseño, qué pasa si se cae X, límites de la solución.

## 4. Fases de trabajo (con puntos de control)

Trabaja por fases. Al terminar cada una: ejecuta `rebar3 compile && rebar3 eunit`, haz **commit** con mensaje claro (Conventional Commits en español está bien), actualiza `docs/PROGRESO.md` (estado, decisiones, pendientes) y **detente a reportarme**.

- **Fase 1 — Entorno**: verificar/instalar Erlang + rebar3, compilar el esqueleto, `scripts/setup.sh`.
- **Fase 2 — Núcleo OTP**: bitácora (ETS + log + hash), dispositivos, supervisión, retención, consultas por rango, pruebas.
- **Fase 3 — API + tiempo real + métricas**: cowboy, WebSocket, `/metrics`, estáticos.
- **Fase 4 — Simulador y caos**: escenario completo, fallas inyectadas, `docs/CAOS.md` con datos medidos.
- **Fase 5 — Stitch (requiere mi intervención, ver sección 5)**.
- **Fase 6 — Integración UI + release + systemd + demo**.
- **Fase 7 — Documentación y manual (sección 6)**.

## 5. Google Stitch — requiere mi intervención manual

Tú no puedes operar Google Stitch (aunque tengas `webfetch`, no es una API que puedas usar por mí); **yo lo hago a mano**. Reglas:

1. **No inventes ni simules una UI "hecha con Stitch".** Una UI no creada con Stitch vale 0 en el criterio 4. No escribas la UI final por tu cuenta.
2. Cuando termines la Fase 3 (API estable), **mejora `design/PROMPT_STITCH.md`**: pantallas (Dashboard en tiempo real, Detalle de dispositivo, Bitácora/historial con filtro por rango de tiempo y alertas, y si aporta: verificación de integridad y salud del sistema), componentes concretos, colores de estado (ok / alerta / falla), legible en celular, **todo en español**, e incluye los **campos reales que expone la API** para que el diseño encaje con los datos.
3. Después **detente y dime exactamente** qué hacer: abrir Stitch, pegar el prompt, iterar, y **exportar el zip (con `DESIGN.md`) a `design/`**. También dime qué capturas de pantalla de Stitch debo guardar para la entrega.
4. Cuando yo te avise que el export está en `design/`, **intégralo** (tomando el HTML/CSS exportado como base, sin rediseñarlo) en `priv/www/` conectándolo a la API real y al WebSocket, con navegación clara entre pantallas y estados de carga/error. Si el export no encaja con la API, ajusta el cableado, y si hace falta cambiar el diseño, dime qué debo regenerar en Stitch.

## 6. Manual de uso para el Gist

Crea `docs/MANUAL_GIST.md` (Markdown autocontenido, para el **cliente**, no para desarrolladores): propósito del sistema, requisitos, instalación/acceso en la VM (paso a paso con comandos), cómo iniciar/detener, recorrido de la UI, ejemplos de uso de la API con `curl`, interpretación de colores de estado y alertas, cómo buscar por rango de tiempo, cómo verificar integridad, **solución de problemas comunes** (puerto ocupado, cookie, systemd en WSL, etc.) y marcadores `<!-- CAPTURA: descripción -->` donde faltan capturas. Al final, dame la **lista de capturas** que debo tomar (de Stitch y de la app real).

Para publicarlo: si `gh` está instalado y autenticado, ofrécete a correr `gh gist create`; si no, indícame cómo subirlo yo a gist.github.com. **No publiques nada sin mi confirmación.**

## 7. Calidad del código (criterio 6)

- Módulos pequeños y cohesivos, una responsabilidad por módulo; separar lógica pura (funcional, sin efectos) de procesos y de I/O.
- `-spec` y `-type` en funciones exportadas; `-moduledoc`/comentarios en español donde aporten (el porqué, no el qué).
- Manejo explícito de errores (`{ok,_}`/`{error,_}`), sin `catch` genéricos que oculten fallas; "let it crash" donde corresponda y supervisión que lo respalde.
- Sin números mágicos: parámetros en `sys.config`/`application:get_env`.
- Logging con `logger` y metadatos útiles.
- Sin warnings (`warnings_as_errors` debe seguir activo).
- Dialyzer: intenta `rebar3 dialyzer` y reporta el resultado.

## 8. Reglas de trabajo

- **Un paso a la vez**: no encadenes decenas de cambios sin compilar. Compila y prueba tras cada módulo. No supongas el comportamiento de una función de OTP/cowboy: si dudas, revisa el código de `_build/default/lib/` o la documentación con `webfetch`.
- **Si el contexto se compacta**, relee `AGENTS.md` y `docs/PROGRESO.md` antes de continuar.

- **Honestidad ante todo**: no declares que algo funciona sin haberlo ejecutado; muestra la salida relevante de compile/eunit/pruebas. Si algo falla o queda pendiente, dilo.
- Mi `opencode.json` ya te pide aprobación para comandos sensibles; **aun así pregúntame explícitamente** antes de: `sudo`, instalar paquetes, `git push`, publicar Gists, borrar archivos o cambiar dependencias.
- No toques fuera de este proyecto.
- Si algo del problema es ambiguo, haz una suposición razonable, anótala en `docs/SUPUESTOS.md` y sigue (pregunta solo si bloquea).
- Mantén `docs/PROGRESO.md` actualizado para poder retomar la sesión si se corta.
- **Mantén un archivo `docs/PENDIENTE_USUARIO.md`** con todo lo que requiere mi acción manual (Stitch, capturas, Gist, confirmar entorno, ensayar la demo) y recuérdamelo al final de cada fase.

## 9. Empieza ahora

1. Haz la lectura de la sección 1.
2. Revisa el entorno (`lsb_release -a`, `erl`, `rebar3`, `nproc`, `git status`) sin instalar nada aún.
3. Preséntame el **plan por fases** y las **decisiones de diseño OTP** clave, junto con cualquier duda real, y espera mi aprobación.
