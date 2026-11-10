# Progreso — #69 Camaras y accesos

Bitacora de trabajo para poder retomar la sesion si se corta. Se actualiza al final de cada fase.

## Estado general

- Fase 1 (Entorno): **completada** (toolchain local; ver nota).
- Fase 2 (Nucleo OTP): **completada** (`rebar3 compile` OK, `rebar3 eunit` 41 pruebas, 0 fallos).
- Fase 3 (API REST, WebSocket, metricas y estaticos): **completada** (`rebar3 compile` OK, `rebar3 eunit` 45 pruebas, 0 fallos; humo real de API y WS).
- Fases 4 a 7: pendientes.

## Entorno verificado

- Ubuntu 26.04.1 LTS sobre WSL2, PID 1 = systemd (`/etc/wsl.conf` con `systemd=true`).
- `nproc` = 20 nucleos.
- OTP 27.3.4.6 y rebar3 3.26.0.
- Nota: `sudo` de este entorno pide autenticacion interactiva y el shell del agente no
  tiene TTY, por lo que no se pudo instalar con `apt`. Se extrajeron los paquetes
  oficiales de Ubuntu en `~/.local/opt/erlang-p69` y `~/.local/bin/rebar3` para poder
  trabajar. El `scripts/setup.sh` sigue usando `apt` para una VM normal.

Para usar el toolchain local en esta maquina:

```bash
export PATH="$HOME/.local/opt/erlang-p69/bin:$HOME/.local/bin:$PATH"
```

## Decisiones tomadas

- Zona horaria de almacenamiento: UTC (la API acepta ISO-8601 con offset).
- Puerto HTTP por defecto: 8080; interfaz 0.0.0.0 para alcanzar la UI desde Windows.
- Retencion por defecto: 30 dias; segmentos diarios.
- Cookie de Erlang generada aleatoriamente (no queda `cambiar_en_produccion`).
- Uso del modulo estandar `json` de OTP 27 (menos dependencias).

## Modulos del nucleo OTP (Fase 2)

- `p69_config`: lectura centralizada de `sys.config`.
- `p69_evento`: logica pura (normalizacion, timestamps, hash canonico, mediana).
- `p69_reloj`: estimacion de offset por mediana (pura).
- `p69_wal`: WAL append-only con registros enmarcados y sync antes del ACK.
- `p69_almacen`: tablas ETS por segmento (ordered_set) + indices por edificio y dispositivo.
- `p69_cadena`: verificacion pura de la cadena de eventos y de checkpoints.
- `p69_bitacora`: gen_server dueno de ETS/WAL; ingesta, consultas con pines, retencion y recuperacion.
- `p69_dispositivo`, `p69_sitio_sup`, `p69_sitios_sup`, `p69_sitios`: estado por dispositivo y supervision por edificio.
- `p69_consultas_sup`, `p69_consulta`: consultas efimeras que no bloquean la ingesta.
- `p69_retencion`: borrado periodico de segmentos vencidos.
- `p69_metricas`: contadores ETS para `/metrics` (Fase 3).
- `p69_api`, `p69_api_eventos`, `p69_api_dispositivos`, `p69_api_alertas`,
  `p69_api_verificar`, `p69_api_salud`, `p69_api_metrics`: handlers REST (Fase 3).
- `p69_http`: listener cowboy y tabla de rutas (incluye estaticos de `priv/www`).
- `p69_ws` y `p69_eventos_pub`: WebSocket `/ws/eventos` y pub/sub de eventos (Fase 3).

## Decisiones de los casos dificiles

- Evento tardio: se inserta en el `ordered_set` por `{ts_corregido, seq}`; la cadena de hashes sigue el orden de llegada (`seq`). La verificacion recorre el libro de hashes por `seq`.
- Reloj desfasado: offset por mediana de `ts_recepcion - ts_evento`; se guardan `ts_evento` y `ts_corregido`; se marca `desfasado`.
- Retencion: pin por consulta; la bitacora omite segmentos en uso y registra un checkpoint en una cadena propia de checkpoints.
- Reinicio: al iniciar se relee el WAL, se reconstruyen segmentos/ETS y se aplican los checkpoints de retencion.
- Verificacion tras borrado: el libro de hashes (`seq -> hash/hash_prev`) se conserva; los eventos presentes se recalculan y los eliminados conservan el eslabon.

## Pendientes reales

- Instalar Erlang/rebar3 con `apt` a nivel sistema cuando haya TTY/sudo (necesario para
  desplegar el servicio systemd con rutas estandar; el release puede incluir su propio ERTS).
- Esperar el export de Google Stitch en `design/` (Fase 5); el prompt ya esta mejorado con campos reales de la API.
- Simulador, caos, UI, release/systemd, manual (Fases 4 a 7).

## Registro de fases

### Fase 1 — Entorno

- `rebar3 compile`: OK.
- `rebar3 eunit`: 2 tests, 0 fallos.
- `scripts/setup.sh` creado (idempotente).
- `config/vm.args` ajustado a 20 nucleos y cookie aleatoria.
- `config/sys.config` con parametros base (puerto, datos, retencion, umbrales de ingesta).

### Fase 2 — Nucleo OTP

- Modulos nuevos listados arriba; supervision raiz `rest_for_one` (bitacora aislada y duena de ETS/WAL).
- `rebar3 compile`: OK sin warnings (`warnings_as_errors`).
- `rebar3 eunit`: **41 tests, 0 fallos**.
- Pruebas cubren: busqueda por rango, evento tardio, filtros/indices, correccion de reloj,
  cadena de hashes y deteccion de alteracion, checkpoints, retencion con consulta en curso,
  recuperacion desde WAL y arbol de supervision.
- Limitacion documentada: el WAL crece sin truncarse; el libro de hashes conserva una entrada
  por evento para poder verificar tras la retencion.

### Fase 3 - API REST, WebSocket, metricas y estaticos

- Endpoints: `GET /`, `GET/POST /api/eventos`, `GET /api/dispositivos`,
  `GET /api/dispositivos/:id`, `GET /api/alertas`, `GET /api/bitacora/verificar`,
  `GET /api/salud`, `GET /metrics`, `WS /ws/eventos`.
- Supervisor raiz ampliado con `p69_eventos_pub` y `p69_http`; `num_aceptores` en
  `sys.config`; `priv/www/index.html` es solo marcador de posicion honesto (la UI
  final vendra del export de Stitch).
- `rebar3 compile`: OK sin warnings.
- `rebar3 eunit`: **45 tests, 0 fallos**, incluida una suite de integracion HTTP real
  (salud, estaticos, alta, busqueda con filtros, dispositivos, alertas, validacion,
  paginacion y verificacion de integridad).
- Humo manual con el release de desarrollo:
  - `GET /api/salud` -> `estado: ok`, OTP 27.
  - `POST /api/eventos` con fecha de 2023 -> `400 fuera_de_retencion` (retencion de
    30 dias; comportamiento correcto).
  - `GET /api/eventos`, `/api/bitacora/verificar` y `/metrics` -> respuestas reales.
  - WebSocket `/ws/eventos`: handshake `101 Switching Protocols`, resumen inicial y
    resumen posterior al alta de un evento.
- Prueba de reconocimiento: un evento con `ts_evento` antiguo pero
  `ts_recepcion` actual se marca `desfasado` y se corrige con el offset estimado; para
  cargas historicas hay que enviar `ts_recepcion` dentro de la retencion.
