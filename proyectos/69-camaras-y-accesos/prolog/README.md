# #69 Camaras y accesos - version SWI-Prolog

Puerto funcional del proyecto a SWI-Prolog. Conserva el mismo dominio, la misma
API HTTP y la misma UI web; cambia el motor de ejecucion de Erlang/OTP a
Prolog.

Esta version es una implementacion separada dentro de `prolog/`. No modifica el
codigo Erlang original.

## Requisitos

- SWI-Prolog 9.2 o superior.
- `swi-prolog-nox` incluye HTTP, JSON, WebSocket y crypto.

Verificacion:

```bash
swipl --version
```

## Arranque

Servidor en `8090` con la UI y API:

```bash
cd prolog
./scripts/run.sh
```

Abrir:

- Dashboard: <http://localhost:8090/>
- Bitacora: <http://localhost:8090/bitacora.html>
- Nodo: <http://localhost:8090/nodo.html>
- Salud: <http://localhost:8090/api/salud>

Demo con 100,000 eventos historicos y carga en vivo:

```bash
./scripts/demo.sh --limpiar
```

Detener:

```bash
./scripts/demo.sh --detener
```

## Pruebas

```bash
cd prolog
make test
```

o directamente:

```bash
swipl -q -g "consult('test/run_tests.pl'),run_tests,halt"
```

## API

Mismas rutas que la version Erlang:

- `GET /api/salud`
- `GET|POST /api/eventos`
- `GET /api/dispositivos`
- `GET /api/dispositivos/:id`
- `GET /api/alertas`
- `GET /api/bitacora/verificar`
- `GET /metrics`
- `WS /ws/eventos`

Ejemplo de alta:

```bash
TS=$(($(date +%s) * 1000000))
curl -sS -X POST http://localhost:8090/api/eventos \
  -H 'content-type: application/json' \
  -d "{\"dispositivo_id\":\"camara-101\",\"tipo_dispositivo\":\"camara\",\"edificio\":\"A\",\"tipo_evento\":\"movimiento\",\"ts_evento\":$TS,\"ts_recepcion\":$TS}"
```

## Arquitectura

- `p69_evento.pl`: normalizacion, timestamps, reloj y cadena SHA-256.
- `p69_almacen.pl`: arboles rojo-negro para tiempo, edificio, dispositivo y seq.
- `p69_wal.pl`: WAL append-only en terminos Prolog.
- `p69_bitacora.pl`: hilo dueno del estado, ingesta, consultas, retencion y
  verificacion.
- `p69_cadena.pl`: verificacion de la cadena de eventos y checkpoints.
- `p69_http.pl`: API REST, UI estatica y WebSocket.
- `p69_simulador.pl`: generacion de eventos historicos y en vivo.

## Diferencias frente a Erlang/OTP

- No hay `gen_server`, supervisores ni releases. El estado vive en un hilo
  Prolog y las peticiones se serializan por cola de mensajes.
- Las consultas se ejecutan en el mismo hilo de la bitacora; no hay lectura
  concurrente tipo ETS.
- El WAL usa `flush_output/1`, no `fsync/1` porque SWI-Prolog 9.2 no expone
  `fsync` en la libreria estandar. La garantia de durabilidad es menor y queda
  documentada.
- La UI es la misma HTML/JS; no se reescribio en Prolog.
- El escenario de caos inicial es de 100,000 eventos, no 1,000,000.

## Estado

Implementacion en construccion. La evidencia y las mediciones se agregan cuando
las pruebas y la demo esten verificadas.
