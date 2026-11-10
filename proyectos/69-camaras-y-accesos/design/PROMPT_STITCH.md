# Prompt para Google Stitch - #69 Camaras y accesos

Copia todo el bloque siguiente en Google Stitch. Genera las pantallas en espanol,
con datos de ejemplo realistas y exporta el zip (incluyendo `DESIGN.md`) a `design/`.

---

## Brief de diseno

Disena la interfaz web de **Camaras y accesos**, un sistema de seguridad para un
campus con **100 puertas y 200 camaras**. El sistema no muestra video: muestra la
**bitacora de eventos** (puerta abierta, tarjeta leida, movimiento, alarma,
offline/online) y permite **buscar por rango de tiempo**, ver el estado de los
dispositivos y verificar que la bitacora no fue alterada.

Publico: operadores de seguridad y administradores del campus. Debe ser claro,
sobrio y rapido de leer en una sala de monitoreo, y perfectamente usable en celular.

Idioma de toda la interfaz: **espanol**. Formato de fecha: `2026-11-09 14:25`.
Zona horaria mostrada: UTC con etiqueta "UTC" o conversion local indicada.

## Estilo visual

- Enfoque "security operations": fondo claro neutro, tarjetas blancas, tipografia
  sans-serif legible, buen contraste, densidad media-alta de informacion.
- Barra lateral de navegacion oscura; contenido claro.
- Colores de estado (siempre acompanados de icono y texto, nunca solo color):
  - ok / en linea: verde `#1B7F3B`
  - alerta / reloj desfasado: ambar `#B7791F`
  - falla / offline: rojo `#B42318`
  - informacion / neutral: azul gris `#475467`
- Esquinas 8-12 px, sombras suaves, sin gradientes llamativos.
- Responsive: escritorio 1440 px y movil 390 px. En movil la navegacion pasa a
  menu inferior o hamburguesa y las tablas se convierten en tarjetas.
- Accesibilidad: foco visible, contraste AA, textos alternativos, no depender del color.

## Navegacion

Barra lateral con 4 secciones:
1. **Panel en vivo**
2. **Bitacora**
3. **Dispositivos**
4. **Integridad y salud**

Cabecera global con nombre del sistema, indicador de conexion en tiempo real
(conectado / reconectando / sin conexion) y hora actual.

## Pantalla 1 - Panel en vivo (Dashboard)

Objetivo: ver de un vistazo que esta pasando ahora.

Componentes:
- Fila de KPIs (tarjetas): eventos totales, eventos por segundo (ultimo minuto),
  camaras offline, puertas offline, dispositivos en alerta, eventos con reloj
  desfasado, cola de ingesta.
- Grafico simple de eventos por minuto (ultima hora) y mini lista de edificios.
- **Flujo de eventos en vivo** (tabla o lista): se actualiza por WebSocket y resalta
  las filas nuevas unos segundos. Columnas: hora corregida, dispositivo, edificio,
  tipo de evento, persona, estado del reloj.
- Panel lateral de **alertas activas** con dispositivo, edificio, estado y ultimo
  latido.
- Control "Pausar / reanudar" el flujo en vivo y boton "Actualizar".
- Estados: cargando (skeleton), sin eventos, error de conexion con boton reintentar,
  banner "sin conexion en tiempo real".

Datos que alimentan esta pantalla:
- WebSocket `/ws/eventos` envia `{ "tipo": "evento", "evento": {...} }` y cada 5 s
  `{ "tipo": "resumen", "ts": "...", "seq": 123, "cola_ingesta": 0,
  "dispositivos": 300, "camaras_offline": 2, "puertas_offline": 1, "en_alerta": 3 }`.
- `GET /api/eventos` para la carga inicial.
- `GET /api/alertas` y `GET /metrics`/`GET /api/salud` para los KPIs.

## Pantalla 2 - Bitacora / Historial

Objetivo: responder "que paso entre las 2:10 y las 2:25 en el edificio B?".

Componentes:
- Barra de filtros: **desde** y **hasta** (fecha y hora), **edificio**,
  **dispositivo/camara**, **tipo de evento**, **persona**, tamano de pagina.
  Incluye atajos: ultima hora, ultimas 24 h, ultimos 7 dias.
- Tabla de resultados con columnas: hora corregida (`ts_corregido_iso`),
  dispositivo (`dispositivo_id`), tipo (`tipo_dispositivo`), edificio,
  tipo de evento, persona, desfase de reloj (`offset_reloj` / `desfasado`),
  hash corto (primeros 12 caracteres de `hash`).
- Paginacion por `limite` y `offset`, mostrando total de resultados.
- Fila expandible o panel lateral con el detalle completo del evento: marca de
  tiempo cruda (`ts_evento_iso`), corregida (`ts_corregido_iso`), recepcion
  (`ts_recepcion_iso`), offset, `hash_prev` y `hash` completos.
- Estado vacio explicando como ampliar el rango; estado de carga; error de
  consulta con reintento.
- Boton "Verificar integridad" que lleva a la pantalla 4.

Respuesta real de `GET /api/eventos?desde=&hasta=&edificio=&camara=&tipo=&persona=&limite=&offset=`:

```json
{
  "total": 128,
  "desde": 1762680000000000,
  "desde_iso": "2026-11-09T14:00:00.000000Z",
  "hasta": 1762683600000000,
  "hasta_iso": "2026-11-09T15:00:00.000000Z",
  "limite": 50,
  "offset": 0,
  "eventos": [
    {
      "seq": 42,
      "dispositivo_id": "cam-042",
      "tipo_dispositivo": "camara",
      "edificio": "B",
      "tipo_evento": "movimiento",
      "persona": null,
      "ts_evento": 1762681234567890,
      "ts_evento_iso": "2026-11-09T14:20:34.567890Z",
      "ts_corregido": 1762681234567890,
      "ts_corregido_iso": "2026-11-09T14:20:34.567890Z",
      "ts_recepcion": 1762681234600000,
      "ts_recepcion_iso": "2026-11-09T14:20:34.600000Z",
      "offset_reloj": 0,
      "desfasado": false,
      "hash_prev": "9F2C...",
      "hash": "7A1B..."
    }
  ]
}
```

## Pantalla 3 - Dispositivos (lista y detalle)

Objetivo: saber que camara o puerta esta fallando y su desfase de reloj.

Lista (`GET /api/dispositivos`):
- Buscador por id, filtro por edificio y por estado (ok/alerta/falla).
- Tarjetas o tabla: id, tipo (puerta/camara), edificio, estado con badge,
  ultimo latido, offset de reloj en segundos, indicador de desfase.
- Contador resumen por estado.

Detalle (`GET /api/dispositivos/:id`):
- Cabecera: id, tipo, edificio, estado, ultimo latido, offset de reloj, desfase.
- Contadores por tipo de evento (`contadores`).
- Lista de eventos recientes del dispositivo (`recientes`).
- Si `desfasado` es true, mostrar aviso "reloj desfasado: offset de X s".
- Boton volver a la lista.

Respuesta real de detalle:

```json
{
  "id": "cam-042",
  "tipo": "camara",
  "edificio": "B",
  "estado": "alerta",
  "ultimo_latido": 1762681234600000,
  "ultimo_latido_iso": "2026-11-09T14:20:34.600000Z",
  "offset_segundos": 240.0,
  "desfasado": true,
  "contadores": {"movimiento": 120, "alarma": 1},
  "recientes": []
}
```

Estados posibles de `estado`: `ok`, `alerta`, `falla`. En la UI traducelos a
"En linea", "Alerta" y "Falla".

## Pantalla 4 - Integridad y salud

Objetivo: demostrar que la bitacora no fue alterada y que el sistema esta sano.

Componentes:
- Tarjeta grande de **integridad de la cadena**:
  - ok: icono verde, "Bitacora verificada", eventos verificados, eliminados por
    retencion, checkpoints, ultimo seq.
  - falla: icono rojo, "Integridad comprometida", motivo (evento alterado,
    eslabon roto, secuencia incompleta) y seq afectado.
  - Boton "Verificar ahora".
- Tarjeta de **salud del sistema**: version, OTP, uptime, procesos, memoria total,
  cola de ingesta, numero de segmentos, pines de consulta.
- Tabla de **segmentos** (si se muestra): id, desde, hasta, eventos, memoria.
- Nota explicativa breve: "cada evento encadena el hash del anterior; si cambia un
  registro, la verificacion falla".

Respuestas reales:

`GET /api/bitacora/verificar`

```json
{"integridad": "ok",
 "resumen": {"eventos": 150000, "eliminados": 20, "ultimo_seq": 150020,
             "checkpoints": 3}}
```

En caso de falla (HTTP 409):

```json
{"integridad": "falla",
 "detalle": {"motivo": "evento_alterado", "seq": 42}}
```

`GET /api/salud`

```json
{"estado": "ok", "version": "0.1.0", "otp": "27",
 "uptime_seg": 3600, "procesos": 340, "memoria_total": 73400320,
 "bitacora": {"seq": 150020, "ultimo_hash": "...", "cp_seq": 3,
              "segmentos": 3, "pines": 0, "relojes": 300, "cola_ingesta": 0},
 "metricas": {}}
```

## Interacciones y estados requeridos

- Todos los listados: carga, vacio, error y reintento.
- Notificaciones toast para errores de la API (400, 404, 429/503 con mensaje).
- Manejo de reconexion del WebSocket con indicador visible.
- Confirmacion visual cuando la verificacion de integridad termina.
- No inventes funciones que no existan en la API. Si quieres anadir algo, marcalo
  como visual y no como dato real.

## Exportacion

Exporta el zip de Google Stitch en `design/`, descomprimelo en esa carpeta e incluye
`DESIGN.md`. Genera al menos las 4 pantallas en escritorio y las 4 equivalentes en
movil. Nombra los archivos de forma clara (`panel.html`, `bitacora.html`,
`dispositivos.html`, `integridad.html` o los que entregue Stitch).
