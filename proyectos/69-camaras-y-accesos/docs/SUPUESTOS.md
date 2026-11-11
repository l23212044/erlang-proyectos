# Supuestos y cifras — #69 Camaras y accesos

## Supuestos de diseno

- Las marcas de tiempo se almacenan en **microsegundos UTC**. La API acepta
  ISO-8601 con offset o epoch.
- Un evento pertenece a un solo dispositivo y edificio.
- `persona` es opcional; la demo no implementa anonimizacion ni cifrado de datos
  personales.
- La retencion por defecto es de **30 dias**; es configurable en `sys.config`.
- Un dispositivo pasa a `falla` si no hay latido en `dispositivo_timeout_seg`
  (120 s por defecto).
- El reloj se considera desfasado si supera `umbral_reloj_seg` (60 s).
- La bitacora prioriza no perder eventos sobre la disponibilidad: si la cola
  crece demasiado responde 429 en vez de descartar.
- El WAL es append-only y no se trunca en esta version.
- No hay API de control fisico, apertura remota ni PTZ; la UI no simula esas
  acciones.

## Cifras del enunciado

Las siguientes cifras se tomaron del documento `problema/readme.md` como ordenes
de magnitud. **No se verificaron con fuentes externas en esta sesion**, por lo
que se marcan como referencia y no como dato citado:

- 100 puertas y 200 camaras.
- 150 eventos/s promedio y picos de 2,000/s.
- Camara 1080p H.264: 2-4 Mbps, 20-40 GB por dia.
- Retencion tipica de video: 30-90 dias.
- Retencion tipica de bitacora: de 1 a varios anos.

## Mediciones propias verificadas

Solo se reportan cifras que salieron de corridas reales en este entorno:

- `rebar3 eunit`: 51 pruebas, 0 fallos (ultima corrida).
- Carga de 1,000,000 de eventos: 12,144 ms (~82,345 ev/s), con `seq` y eventos
  presentes iguales.
- Consulta concurrente: 353 ms promedio durante la ingesta vs 314 ms en reposo.
- Recuperacion de bitacora tras `kill`: 11,619 ms, conservando `seq`.
- Verificacion de cadena tras caos: 4,854 ms, `integridad: ok`.

La tabla completa y el comando reproducible estan en `docs/CAOS.md`.

## Fuera de alcance

- Video RTSP o almacenamiento de imagenes.
- Control de puertas o PTZ.
- Autenticacion/autorizacion de usuarios.
- Cifrado en reposo o anonimizacion avanzada.
- Clustering distribuido.
