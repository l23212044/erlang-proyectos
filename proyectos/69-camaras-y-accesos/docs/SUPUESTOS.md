# Supuestos y cifras — #69 Camaras y accesos

## Supuestos de diseno

- Las marcas de tiempo se almacenan en **microsegundos UTC**. La API acepta
  ISO-8601 con offset o epoch.
- Un evento pertenece a un solo dispositivo y edificio.
- `persona` es opcional; la demo no implementa anonimizacion ni cifrado de datos
  personales.
- La retencion por defecto es de **30 dias**; es configurable en `sys.config`.
  Con `modo_demo=true` el borrado usa `retencion_demo_seg` (ver umbrales abajo);
  `retencion_dias=0` sigue desactivando la retencion.
- Un dispositivo pasa a `alerta` si no hay latido en `dispositivo_alerta_seg` y
  a `falla` en `dispositivo_falla_seg`.
- El reloj se considera desfasado si supera `reloj_alerta_seg`; un desfase mayor
  que `reloj_falla_seg` marca el dispositivo en `falla`.
- La bitacora prioriza no perder eventos sobre la disponibilidad: si la cola
  crece demasiado responde 429 en vez de descartar.
- El WAL es append-only y no se trunca en esta version.
- No hay API de control fisico, apertura remota ni PTZ; la UI no simula esas
  acciones.

## Umbrales de alerta (supuestos propios, no verificados)

Todos viven en `config/sys.config` y se leen con `p69_config:get/2`; no hay
numeros magicos en el codigo. Son **supuestos propios de esta demo** y no se
verificaron contra fuentes externas:

| Clave | Valor inicial | Significado |
|---|---|---|
| `dispositivo_alerta_seg` | 60 | silencio que marca el dispositivo en `alerta` |
| `dispositivo_falla_seg` | 180 | silencio que marca el dispositivo en `falla` |
| `reloj_alerta_seg` | 30 | desfase que marca el evento como `desfasado` |
| `reloj_falla_seg` | 300 | desfase que marca el dispositivo en `falla` |
| `evento_tardio_seg` | 300 | retraso de llegada que marca el evento como `tardio` |
| `ingesta_max_cola` | 20000 | tamano maximo de la cola de ingesta |
| `ingesta_umbral_aviso` | 10000 | aviso al 50 % de la cola maxima |
| `ingesta_umbral_429` | 18000 | respuesta 429 al 90 % de la cola maxima |
| `mensajes_pendientes_max` | 10000 | mensajes en cola de un suscriptor antes de omitirle eventos |
| `retencion_demo_seg` | 600 | retencion de 10 minutos cuando `modo_demo=true` |

Estos valores sustituyen a `dispositivo_timeout_seg` (120 s) y
`umbral_reloj_seg` (60 s), que se retiraron para no tener dos fuentes de verdad.

Nota sobre `gemelo/`: el gemelo en SWI-Prolog no define estos umbrales de alerta;
`gemelo/CONTEXTO_AGENTES.md` deja que el estudiante los fije. Las ventanas del
reglamento del gemelo (retencion de 1 ano / 90 dias, consultas de 1 / 30 dias)
pertenecen a otra capa y no modifican estos valores.

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
