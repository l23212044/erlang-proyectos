# Evidencia de API y release

Fecha: 2026-11-11T07:07:11Z

Release real en `_build/prod/rel`, arrancado con `scripts/demo.sh --limpiar --puerto 18090`.

## Release en ejecucion

```text
  77104 /home/zero/erlang-proyectos/proyectos/69-camaras-y-accesos/_build/prod/rel/p69_camaras_y_accesos/bin/p69_camaras_y_accesos -Bd -S 20:20 -SDcpu 20:20 -SDio 10 -K true -P 1048576 -Q 65536 -e 204800 -zdbbl 65536 -A 
```

## GET /api/salud

Se muestra el resumen de campos; `metricas` trae 311 claves y se omite aqui.

```http
{
  "version": "0.1.0",
  "otp": "27",
  "estado": "ok",
  "bitacora": {
    "cola_ingesta": 0,
    "cp_seq": 0,
    "pines": 0,
    "relojes": 300,
    "segmentos": 1,
    "seq": 22279,
    "ultimo_hash": "61419212D2846BB4F745497AC4C6CB5031D85DA24C52DC21F045DD998CE6D138"
  },
  "memoria_total": 143060016,
  "procesos": 459,
  "uptime_seg": 389,
  "metricas_claves": 311,
  "ingesta_aceptada": 2976,
  "eventos_ingresados": 22279
}
HTTP 200
```

## GET /api/dispositivos?edificio=G (extracto de camara-017)

```http
{
  "total_edificio_G": 30,
  "camara-017": {
    "id": "camara-017",
    "edificio": "G",
    "estado": "alerta",
    "desfasado": true,
    "offset_segundos": 240.0,
    "contadores": {
      "alarma": 6,
      "movimiento": 63,
      "offline": 1
    }
  },
  "evento_reciente": {
    "desfasado": true,
    "dispositivo_id": "camara-017",
    "edificio": "G",
    "hash": "E5186CEDE3A959AF4D99EDE3BF0EE7F7D0323DDB9ABF8AA4D60D9922419DCE76",
    "hash_prev": "CB584151E85FF6D792FCD26297F855048D8D67453C9E9E3B66D9DF0F0884F5E7",
    "offset_reloj": 240000000,
    "persona": null,
    "seq": 22231,
    "tipo_dispositivo": "camara",
    "tipo_evento": "alarma",
    "ts_corregido": 1794380742099231,
    "ts_corregido_iso": "2026-11-11T07:05:42.099231Z",
    "ts_evento": 1794380502099231,
    "ts_evento_iso": "2026-11-11T07:01:42.099231Z",
    "ts_recepcion": 1794380742099231,
    "ts_recepcion_iso": "2026-11-11T07:05:42.099231Z"
  }
}
HTTP 200
```

## GET /api/eventos?limite=1

```http
{
  "offset": 0,
  "total": 21741,
  "desde_iso": "2026-11-11T06:07:11.817620Z",
  "hasta_iso": "2026-11-11T07:07:11.817620Z",
  "primer_evento": {
    "desfasado": false,
    "dispositivo_id": "puerta-019",
    "edificio": "I",
    "hash": "AA0C8CB245DD4FEED13355ED1802301000275992247855108C3B0504EE68F403",
    "hash_prev": "98ED7F3DE896F02E5E17DF99F3B385B605443DA696963C1C1A4CCF83054F205E",
    "offset_reloj": 38914,
    "persona": "persona-26",
    "seq": 540,
    "tipo_dispositivo": "puerta",
    "tipo_evento": "tarjeta_leida",
    "ts_corregido": 1794377232146643,
    "ts_corregido_iso": "2026-11-11T06:07:12.146643Z",
    "ts_evento": 1794377232107729,
    "ts_evento_iso": "2026-11-11T06:07:12.107729Z",
    "ts_recepcion": 1794377232185512,
    "ts_recepcion_iso": "2026-11-11T06:07:12.185512Z"
  }
}
HTTP 200
```

## GET /api/bitacora/verificar

```http
{"integridad":"ok","resumen":{"checkpoints":0,"eliminados":0,"eventos":22279,"ultimo_seq":22279}}
HTTP 200
```

## GET /metrics (primeras 20 lineas)

```text
# HELP p69_eventos_total Eventos aceptados desde el arranque
# TYPE p69_eventos_total counter
p69_eventos_total 22279
# HELP p69_ingesta_rechazada_total Eventos rechazados (validacion o sobrecarga)
# TYPE p69_ingesta_rechazada_total counter
p69_ingesta_rechazada_total 0
# HELP p69_alertas_reloj_total Eventos marcados con reloj desfasado
# TYPE p69_alertas_reloj_total counter
p69_alertas_reloj_total 80
# HELP p69_consultas_total Consultas de rango ejecutadas
# TYPE p69_consultas_total counter
p69_consultas_total 7
# HELP p69_consulta_latencia_promedio_us Latencia promedio de consultas
# TYPE p69_consulta_latencia_promedio_us gauge
p69_consulta_latencia_promedio_us 16911
# HELP p69_cola_ingesta Mensajes pendientes en la bitacora
# TYPE p69_cola_ingesta gauge
p69_cola_ingesta 0
# HELP p69_segmentos Segmentos temporales activos
# TYPE p69_segmentos gauge
```

La salida de `/metrics` continua con una linea por dispositivo; se corta aqui
para mantener el archivo legible.
