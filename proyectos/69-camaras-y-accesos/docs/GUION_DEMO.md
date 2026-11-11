# Guion de demo — #69 Camaras y accesos (~10 min)

Objetivo: mostrar el flujo completo (ingesta, busqueda, UI, integridad,
retencion y caos) usando la app real. No se usan capturas ni datos inventados.

## Antes de empezar (5 min antes)

1. Detener cualquier `rebar3 shell` o servicio que use el puerto `8080`.
2. Construir el release:

   ```bash
   cd /home/zero/erlang-proyectos/proyectos/69-camaras-y-accesos
   export PATH="$HOME/.local/opt/erlang-p69/bin:$HOME/.local/bin:$PATH"
   rebar3 as prod release
   ```

3. Preparar la demo (limpia datos de `/tmp/p69-demo`, carga historico y arranca
   flujo en vivo):

   ```bash
   scripts/demo.sh --limpiar
   ```

4. Dejar abiertas estas pestanas:
   - `http://localhost:8080/`
   - `http://localhost:8080/bitacora.html`
   - `http://localhost:8080/nodo.html`
   - terminal con `journalctl -u p69-camaras-y-accesos -f` o `tail -f /tmp/p69-demo.log`

Evidencia de la preparacion: `Evidencias/Pruebas_backend.md`.

## 0:00 — Contexto (1 min)

"Una empresa con 100 puertas y 200 camaras genera millones de eventos. El
problema no es el video: es poder responder que paso entre dos horas concretas
en un edificio, sin perder eventos y demostrando que la bitacora no se altero."

## 1:00 — Dashboard en vivo (2 min)

1. Abrir `http://localhost:8080/`.
2. Senalar:
   - KPIs de nodos operativos, en alerta y en falla.
   - Indicador `WS EN LINEA` y latencia.
   - Tarjetas de nodos con ultimo latido y offset de reloj.
   - Eventos recientes.
3. Esperar unos segundos: el WebSocket actualiza el panel sin recargar.

Evidencia del dashboard: `Evidencias/Capturas.md`.

## 3:00 — Busqueda por rango y filtros (2 min)

1. Ir a `Bitacora`.
2. Elegir preset `1 h`; luego un rango personalizado.
3. Filtrar por edificio `A` y severidad `critico`.
4. Buscar un dispositivo (`camara-101`) y mostrar que el filtro es instantaneo
   sobre los eventos ya cargados.
5. Exportar CSV y copiar un hash.

Evidencia de la bitacora: `Evidencias/Capturas.md`.

## 5:00 — Detalle de nodo y reloj desfasado (1.5 min)

1. Abrir el detalle de `camara-017` (el simulador le inyecta 4 minutos de
   atraso).
2. Mostrar `OFFSET`, estado `ALERTA` y el evento con `desfasado: true`.
3. Explicar: se guarda `ts_evento` crudo y `ts_corregido`; la busqueda usa el
   corregido.

Evidencia del detalle de nodo: `Evidencias/Capturas.md`.

## 6:30 — Integridad SHA-256 (1 min)

1. En el detalle, pulsar `VERIFICAR`.
2. Mostrar la respuesta:

   ```bash
   curl -sS http://localhost:8080/api/bitacora/verificar
   ```

   Esperado: `{"integridad":"ok", ...}`.
3. Explicar que cada evento encadena `hash_prev` + registro con SHA-256.
4. (Opcional, si se preparo una copia de datos) alterar un byte del WAL,
   reiniciar y mostrar `409` / `CADENA ALTERADA`.

## 7:30 — Retencion y consultas en curso (1 min)

1. Mostrar en `docs/CAOS.md` el caso de retencion con pin:
   el segmento responde `en_uso` y no se borra hasta cerrar la consulta.
2. Senalar que cada borrado genera un checkpoint encadenado y la verificacion
   sigue en `ok`.

## 8:30 — Prueba de caos real (1.5 min)

Ejecutar (idealmente antes de la demo, porque tarda):

```bash
scripts/caos.sh --eventos 1000000
```

Mostrar la tabla de `docs/CAOS.md`:

- 1,000,000 de eventos cargados; `seq` y presentes coinciden.
- Consulta concurrente ~353 ms promedio vs ~314 ms en reposo.
- Matar dispositivo/sitio/retencion/consulta/bitacora y recuperacion.
- Bitacora: recuperacion del WAL en 11,619 ms conservando `seq`.

## 10:00 — Cierre y limites (30 s)

- "La bitacora es la fuente de verdad; los dispositivos son estado efimero."
- "El WAL no se trunca en esta version; el arranque con millones de eventos es
  lineal."
- "No hay control fisico/PTZ: la UI lo dice y no finge acciones."
- "La UI se integro desde el export de Google Stitch."

## Preguntas probables y respuestas

**Por que Erlang/OTP?**
Concurrencia ligera, aislamiento de fallos, supervision y paso de mensajes. La
ingesta y las consultas corren en procesos separados; un fallo no tumba la
bitacora.

**Por que gen_server y no procesos sueltos?**
Estado encapsulado, callbacks claros, supervision estandar y trazabilidad.
`gen_server` serializa las escrituras de la bitacora y evita condiciones de
carrera.

**Que significa "let it crash"?**
Dejar que un proceso falle y que el supervisor lo reinicie en un estado
conocido, en lugar de llenar el codigo de `catch` que oculta errores. La
bitacora persiste antes del ACK, por eso el reinicio no pierde eventos.

**Por que ETS ordered_set y no una base de datos?**
Acceso en memoria y orden por llave de tiempo; `ets:next` permite rangos sin
recorrer todo. La persistencia la da el WAL. Una BD seria el siguiente paso si
se necesita consulta distribuida o SQL.

**Como se evita perder eventos en un pico?**
WAL + `sync` antes del ACK, cola acotada y backpressure con 429; no se descarta
en silencio.

**Que pasa si se cae la bitacora?**
`rest_for_one` reinicia bitacora y dependientes; al arrancar relee el WAL y
restaura `seq`/`last_hash`.

**Evento tardio y cadena de hashes?**
El evento se inserta por `ts_corregido`, pero la cadena sigue el orden de llegada
(`seq`); por eso la verificacion recorre por `seq`.

**Como se maneja el reloj desfasado?**
Offset por mediana de `ts_recepcion - ts_evento`; se guardan ambos tiempos y se
marca `desfasado`.

**Que pasa con la retencion y una consulta en curso?**
La consulta abre un pin; el segmento queda `en_uso` y no se borra hasta que la
consulta termina. El borrado se registra como checkpoint.

**Limites?**
WAL sin truncar, libro de hashes por evento, estado efimero de dispositivos y
sin API de control fisico.
