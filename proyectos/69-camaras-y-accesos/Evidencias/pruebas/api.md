# Evidencia de API y release

Fecha: 2026-11-11T07:03:36Z

## Release en ejecucion

```text
  28054 /home/zero/erlang-proyectos/proyectos/69-camaras-y-accesos/_build/prod/rel/p69_camaras_y_accesos/erts-15.2.7.4/bin/epmd -daemon
  77104 /home/zero/erlang-proyectos/proyectos/69-camaras-y-accesos/_build/prod/rel/p69_camaras_y_accesos/bin/p69_camaras_y_accesos -Bd -S 20:20 -SDcpu 20:20 -SDio 10 -K true -P 1048576 -Q 65536 -e 204800 -zdbbl 65536 -A 16 -hmqd off_heap -- -root /home/zero/erlang-proyectos/proyectos/69-camaras-y-accesos/_build/prod/rel/p69_camaras_y_accesos -bindir /home/zero/erlang-proyectos/proyectos/69-camaras-y-accesos/_build/prod/rel/p69_camaras_y_accesos/erts-15.2.7.4/bin -progname home/zero/erlang-proyectos/proyectos/69-camaras-y-accesos/_build/prod/rel/p69_camaras_y_accesos/bin/p69_camaras_y_accesos -- -home /home/zero -- -noshell -noinput -boot /home/zero/erlang-proyectos/proyectos/69-camaras-y-accesos/_build/prod/rel/p69_camaras_y_accesos/releases/0.1.0/start -mode embedded -boot_var SYSTEM_LIB_DIR /home/zero/erlang-proyectos/proyectos/69-camaras-y-accesos/_build/prod/rel/p69_camaras_y_accesos/lib -config /home/zero/erlang-proyectos/proyectos/69-camaras-y-accesos/_build/prod/rel/p69_camaras_y_accesos/releases/0.1.0/sys.config -name p69_camaras_y_accesos@127.0.0.1 -setcookie 08872f34e79325432fa10329633f9c07 -- -- foreground -config /tmp/p69-demo-sys.config --
```

## GET /api/salud

```http
{"version":"0.1.0","otp":"27","estado":"ok","metricas":{"{eventos_dispositivo,<<\"puerta-024\">>}":43,"{eventos_dispositivo,<<\"camara-046\">>}":60,"{eventos_dispositivo,<<\"camara-074\">>}":52,"{eventos_dispositivo,<<\"camara-093\">>}":49,"{eventos_dispositivo,<<\"camara-086\">>}":52,"{eventos_dispositivo,<<\"camara-062\">>}":31,"{eventos_dispositivo,<<\"puerta-040\">>}":57,"{eventos_dispositivo,<<\"camara-053\">>}":43,"{eventos_dispositivo,<<\"camara-091\">>}":48,"{eventos_dispositivo,<<\"camara-007\">>}":46,"{eventos_dispositivo,<<\"camara-119\">>}":53,"{eventos_dispositivo,<<\"camara-114\">>}":45,"{eventos_dispositivo,<<\"camara-047\">>}":48,"{eventos_dispositivo,<<\"puerta-075\">>}":52,"{eventos_dispositivo,<<\"camara-135\">>}":50,"{eventos_dispositivo,<<\"camara-094\">>}":63,"{eventos_dispositivo,<<\"puerta-080\">>}":53,"ingesta_aceptada":1722,"{eventos_dispositivo,<<\"camara-173\">>}":62,"{eventos_dispositivo,<<\"puerta-092\">>}":38,"{eventos_dispositivo,<<\"camara-065\">>}":47,"{eventos_dispositivo,<<\"camara-098\">>}":42,"{eventos_dispositivo,<<\"puerta-062\">>}":41,"{eventos_dispositivo,<<\"camara-162\">>}":58,"{eventos_dispositivo,<<\"puerta-059\">>}":64,"{eventos_dispositivo,<<\"camara-023\">>}":47,"{eventos_dispositivo,<<\"camara-076\">>}":55,"{eventos_dispositivo,<<\"camara-113\">>}":53,"consulta_latencia_total_us":49647,"{eventos_dispositivo,<<\"camara-145\">>}":42,"{eventos_dispositivo,<<\"camara-102\">>}":49,"{eventos_dispositivo,<<\"puerta-025\">>}":60,"{eventos_dispositivo,<<\"camara-004\">>}":50,"{eventos_dispositivo,<<\"camara-127\">>}":62,"{eventos_dispositivo,<<\"camara-042\">>}":48,"{eventos_dispositivo,<<\"camara-084\">>}":42,"{eventos_dispositivo,<<\"camara-154\">>}":51,"{eventos_dispositivo,<<\"camara-110\">>}":44,"{eventos_dispositivo,<<\"puerta-099\">>}":48,"{eventos_dispositivo,<<\"camara-146\">>}":53,"{eventos_dispositivo,<<\"camara-121\">>}":54,"{eventos_dispositivo,<<\"camara-056\">>}":50,"{eventos_dispositivo,<<\"camara-001\">>}":59,"{eventos_dispositivo,<<\"camara-193\">>}":52,"{eventos_dispositivo,<<\"puerta-074\">>}":51,"{eventos_dispositivo,<<\"camara-128\">>}":52,"{eventos_dispositivo,<<\"camara-182\">>}":41,"{eventos_dispositivo,<<\"camara-087\">>}":50,"{eventos_dispositivo,<<\"camara-085\">>}":44,"{eventos_dispositivo,<<\"puerta-089\">>}":52,"{eventos_dispositivo,<<\"puerta-081\">>}":60,"{eventos_dispositivo,<<\"camara-070\">>}":43,"{eventos_dispositivo,<<\"camara-156\">>}":60,"{eventos_dispositivo,<<\"camara-072\">>}":41,"{eventos_dispositivo,<<\"camara-174\">>}":48,"{eventos_dispositivo,<<\"camara-183\">>}":56,"{eventos_dispositivo,<<\"camara-167\">>}":52,"{eventos_dispositivo,<<\"camara-112\">>}":51,"{eventos_dispositivo,<<\"puerta-060\">>}":56,"{eventos_dispositivo,<<\"camara-005\">>}":43,"{eventos_dispositivo,<<\"puerta-091\">>}":47,"{eventos_dispositivo,<<\"camara-170\">>}":63,"{eventos_dispositivo,<<\"puerta-012\">>}":43,"{eventos_dispositivo,<<\"camara-073\">>}":44,"{eventos_dispositivo,<<\"puerta-078\">>}":57,"{eventos_dispositivo,<<\"camara-129\">>}":56,"{eventos_dispositivo,<<\"puerta-044\">>}":48,"{eventos_dispositivo,<<\"puerta-017\">>}":42,"{eventos_dispositivo,<<\"camara-152\">>}":58,"{eventos_dispositivo,<<\"camara-009\">>}":52,"{eventos_dispositivo,<<\"camara-060\">>}":60,"{eventos_dispositivo,<<\"camara-036\">>}":55,"{eventos_dispositivo,<<\"camara-191\">>}":40,"{eventos_dispositivo,<<\"puerta-055\">>}":52,"{eventos_dispositivo,<<\"puerta-090\">>}":54,"{eventos_dispositivo,<<\"camara-031\">>}":48,"{eventos_dispositivo,<<\"camara-034\">>}":51,"{eventos_dispositivo,<<\"camara-142\">>}":51,"{eventos_dispositivo,<<\"puerta-050\">>}":59,"{eventos_dispositivo,<<\"camara-092\">>}":46,"{eventos_dispositivo,<<\"puerta-077\">>}":47,"{eventos_dispositivo,<<\"camara-123\">>}":52,"{eventos_dispositivo,<<\"camara-012\">>}":50,"{eventos_dispositivo,<<\"camara-079\">>}":42,"{eventos_dispositivo,<<\"camara-132\">>}":59,"{eventos_dispositivo,<<\"camara-083\">>}":38,"{eventos_dispositivo,<<\"camara-136\">>}":47,"{eventos_dispositivo,<<\"camara-108\">>}":45,"{eventos_dispositivo,<<\"camara-051\">>}":42,"{eventos_dispositivo,<<\"camara-192\">>}":56,"{eventos_dispositivo,<<\"camara-082\">>}":40,"{eventos_dispositivo,<<\"camara-008\">>}":43,"{eventos_dispositivo,<<\"camara-052\">>}":44,"{eventos_dispositivo,<<\"puerta-031\">>}":38,"{eventos_dispositivo,<<\"puerta-048\">>}":64,"{eventos_dispositivo,<<\"camara-029\">>}":53,"{eventos_dispositivo,<<\"camara-063\">>}":52,"{eventos_dispositivo,<<\"puerta-014\">>}":61,"{eventos_dispositivo,<<\"camara-153\">>}":74,"{eventos_dispositivo,<<\"camara-140\">>}":53,"{eventos_dispositivo,<<\"camara-030\">>}":49,"{eventos_dispositivo,<<\"camara-168\">>}":34,"{eventos_dispositivo,<<\"camara-196\">>}":56,"{eventos_dispositivo,<<\"camara-115\">>}":56,"{eventos_dispositivo,<<\"camara-033\">>}":53,"{eventos_dispositivo,<<\"puerta-057\">>}":57,"{eventos_dispositivo,<<\"camara-165\">>}":39,"{eventos_tipo,<<\"puerta_abierta\">>}":3110,"{eventos_dispositivo,<<\"puerta-043\">>}":57,"{eventos_dispositivo,<<\"camara-116\">>}":58,"{eventos_dispositivo,<<\"puerta-087\">>}":51,"{eventos_dispositivo,<<\"puerta-058\">>}":40,"{eventos_dispositivo,<<\"camara-039\">>}":61,"{eventos_dispositivo,<<\"puerta-029\">>}":63,"{eventos_dispositivo,<<\"camara-081\">>}":40,"{eventos_dispositivo,<<\"camara-064\">>}":61,"{eventos_dispositivo,<<\"puerta-083\">>}":58,"{eventos_dispositivo,<<\"puerta-079\">>}":38,"consultas":4,"{eventos_dispositivo,<<\"camara-077\">>}":47,"{eventos_dispositivo,<<\"puerta-041\">>}":48,"{eventos_dispositivo,<<\"camara-014\">>}":55,"{eventos_dispositivo,<<\"camara-002\">>}":48,"{eventos_dispositivo,<<\"puerta-033\">>}":55,"{eventos_dispositivo,<<\"puerta-049\">>}":34,"{eventos_dispositivo,<<\"camara-143\">>}":36,"{eventos_dispositivo,<<\"camara-050\">>}":42,"{eventos_dispositivo,<<\"camara-095\">>}":46,"{eventos_dispositivo,<<\"camara-198\">>}":43,"{eventos_dispositivo,<<\"camara-024\">>}":47,"{eventos_dispositivo,<<\"camara-025\">>}":55,"{eventos_dispositivo,<<\"camara-195\">>}":50,"{eventos_dispositivo,<<\"camara-199\">>}":59,"{eventos_dispositivo,<<\"camara-090\">>}":51,"{eventos_dispositivo,<<\"puerta-046\">>}":63,"{eventos_dispositivo,<<\"puerta-009\">>}":51,"{eventos_dispositivo,<<\"camara-078\">>}":51,"{eventos_dispositivo,<<\"camara-111\">>}":52,"{eventos_dispositivo,<<\"puerta-064\">>}":56,"{eventos_dispositivo,<<\"puerta-023\">>}":40,"{eventos_dispositivo,<<\"puerta-026\">>}":48,"{eventos_dispositivo,<<\"camara-157\">>}":49,"{eventos_dispositivo,<<\"puerta-052\">>}":58,"{eventos_dispositivo,<<\"camara-171\">>}":61,"{eventos_dispositivo,<<\"camara-180\">>}":56,"{eventos_dispositivo,<<\"puerta-069\">>}":62,"{eventos_dispositivo,<<\"puerta-037\">>}":50,"{eventos_dispositivo,<<\"camara-103\">>}":49,"{eventos_dispositivo,<<\"camara-055\">>}":43,"{eventos_dispositivo,<<\"camara-003\">>}":67,"{eventos_dispositivo,<<\"camara-181\">>}":46,"{eventos_dispositivo,<<\"camara-150\">>}":55,"{eventos_dispositivo,<<\"camara-120\">>}":40,"{eventos_dispositivo,<<\"camara-187\">>}":45,"{eventos_dispositivo,<<\"camara-186\">>}":41,"{eventos_dispositivo,<<\"camara-160\">>}":42,"{eventos_dispositivo,<<\"puerta-051\">>}":46,"{eventos_dispositivo,<<\"camara-059\">>}":58,"{eventos_dispositivo,<<\"camara-067\">>}":54,"{eventos_dispositivo,<<\"camara-200\">>}":32,"{eventos_dispositivo,<<\"puerta-034\">>}":66,"{eventos_dispositivo,<<\"puerta-082\">>}":51,"{eventos_dispositivo,<<\"puerta-007\">>}":49,"{eventos_dispositivo,<<\"camara-100\">>}":50,"{eventos_dispositivo,<<\"puerta-027\">>}":44,"{eventos_dispositivo,<<\"camara-015\">>}":47,"{eventos_dispositivo,<<\"camara-040\">>}":46,"{eventos_dispositivo,<<\"camara-021\">>}":57,"{eventos_dispositivo,<<\"puerta-035\">>}":52,"{eventos_dispositivo,<<\"camara-130\">>}":52,"{eventos_tipo,<<\"movimiento\">>}":8982,"{eventos_dispositivo,<<\"puerta-067\">>}":49,"{eventos_dispositivo,<<\"camara-089\">>}":61,"{eventos_dispositivo,<<\"camara-134\">>}":51,"{eventos_dispositivo,<<\"camara-190\">>}":41,"{eventos_dispositivo,<<\"camara-026\">>}":36,"{eventos_dispositivo,<<\"camara-022\">>}":32,"{eventos_dispositivo,<<\"camara-044\">>}":54,"{eventos_dispositivo,<<\"puerta-097\">>}":59,"{eventos_dispositivo,<<\"camara-164\">>}":64,"{eventos_dispositivo,<<\"camara-058\">>}":56,"{eventos_dispositivo,<<\"camara-019\">>}":39,"{eventos_tipo,<<\"offline\">>}":333,"eventos_ingresados":15168,"{eventos_dispositivo,<<\"camara-197\">>}":52,"{eventos_dispositivo,<<\"camara-096\">>}":56,"{eventos_dispositivo,<<\"puerta-003\">>}":45,"{eventos_dispositivo,<<\"camara-010\">>}":46,"{eventos_dispositivo,<<\"puerta-013\">>}":44,"{eventos_dispositivo,<<\"camara-013\">>}":47,"{eventos_dispositivo,<<\"puerta-022\">>}":47,"{eventos_dispositivo,<<\"camara-118\">>}":42,"{eventos_dispositivo,<<\"puerta-085\">>}":63,"{eventos_dispositivo,<<\"camara-139\">>}":50,"{eventos_dispositivo,<<\"camara-061\">>}":60,"{eventos_dispositivo,<<\"camara-101\">>}":51,"{eventos_dispositivo,<<\"puerta-045\">>}":71,"{eventos_dispositivo,<<\"camara-176\">>}":64,"{eventos_dispositivo,<<\"puerta-042\">>}":41,"{eventos_dispositivo,<<\"puerta-061\">>}":59,"{eventos_dispositivo,<<\"camara-071\">>}":61,"{eventos_dispositivo,<<\"puerta-054\">>}":64,"{eventos_dispositivo,<<\"camara-147\">>}":35,"{eventos_dispositivo,<<\"puerta-015\">>}":39,"{eventos_dispositivo,<<\"camara-016\">>}":63,"alertas_reloj":61,"{eventos_dispositivo,<<\"puerta-047\">>}":55,"{eventos_dispositivo,<<\"puerta-066\">>}":49,"{eventos_tipo,<<\"online\">>}":206,"{eventos_dispositivo,<<\"puerta-008\">>}":46,"{eventos_dispositivo,<<\"puerta-004\">>}":56,"{eventos_dispositivo,<<\"puerta-073\">>}":60,"{eventos_dispositivo,<<\"camara-104\">>}":40,"{eventos_dispositivo,<<\"camara-069\">>}":51,"{eventos_dispositivo,<<\"puerta-095\">>}":44,"{eventos_tipo,<<\"alarma\">>}":1023,"{eventos_dispositivo,<<\"camara-099\">>}":40,"{eventos_dispositivo,<<\"camara-041\">>}":50,"{eventos_dispositivo,<<\"camara-043\">>}":47,"{eventos_dispositivo,<<\"camara-189\">>}":57,"{eventos_dispositivo,<<\"puerta-028\">>}":45,"{eventos_dispositivo,<<\"camara-011\">>}":49,"{eventos_dispositivo,<<\"camara-144\">>}":66,"{eventos_dispositivo,<<\"camara-045\">>}":49,"{eventos_dispositivo,<<\"puerta-019\">>}":53,"{eventos_dispositivo,<<\"camara-126\">>}":47,"{eventos_dispositivo,<<\"camara-038\">>}":48,"{eventos_dispositivo,<<\"puerta-076\">>}":51,"{eventos_dispositivo,<<\"camara-137\">>}":64,"{eventos_dispositivo,<<\"puerta-036\">>}":47,"{eventos_dispositivo,<<\"camara-169\">>}":40,"{eventos_dispositivo,<<\"camara-133\">>}":55,"{eventos_dispositivo,<<\"puerta-096\">>}":49,"{eventos_dispositivo,<<\"camara-138\">>}":47,"{eventos_dispositivo,<<\"camara-175\">>}":58,"{eventos_dispositivo,<<\"camara-161\">>}":52,"{eventos_dispositivo,<<\"puerta-016\">>}":61,"{eventos_dispositivo,<<\"camara-037\">>}":48,"{eventos_dispositivo,<<\"puerta-100\">>}":49,"{eventos_dispositivo,<<\"camara-159\">>}":52,"{eventos_dispositivo,<<\"camara-020\">>}":42,"{eventos_dispositivo,<<\"camara-172\">>}":48,"{eventos_dispositivo,<<\"puerta-063\">>}":45,"{eventos_dispositivo,<<\"camara-107\">>}":53,"{eventos_dispositivo,<<\"puerta-001\">>}":62,"{eventos_dispositivo,<<\"camara-125\">>}":36,"{eventos_dispositivo,<<\"camara-048\">>}":55,"{eventos_dispositivo,<<\"camara-032\">>}":52,"{eventos_dispositivo,<<\"puerta-053\">>}":45,"{eventos_dispositivo,<<\"puerta-065\">>}":58,"{eventos_dispositivo,<<\"camara-109\">>}":55,"{eventos_dispositivo,<<\"puerta-039\">>}":52,"{eventos_dispositivo,<<\"puerta-084\">>}":51,"{eventos_dispositivo,<<\"puerta-072\">>}":40,"{eventos_dispositivo,<<\"camara-124\">>}":41,"{eventos_dispositivo,<<\"camara-141\">>}":45,"{eventos_dispositivo,<<\"camara-131\">>}":52,"{eventos_dispositivo,<<\"puerta-068\">>}":39,"{eventos_dispositivo,<<\"camara-151\">>}":42,"{eventos_dispositivo,<<\"puerta-002\">>}":57,"{eventos_dispositivo,<<\"camara-028\">>}":55,"{eventos_dispositivo,<<\"camara-122\">>}":63,"{eventos_dispositivo,<<\"camara-080\">>}":62,"{eventos_dispositivo,<<\"puerta-021\">>}":51,"{eventos_dispositivo,<<\"camara-054\">>}":55,"{eventos_dispositivo,<<\"puerta-018\">>}":42,"{eventos_dispositivo,<<\"camara-166\">>}":54,"{eventos_dispositivo,<<\"camara-194\">>}":47,"{eventos_dispositivo,<<\"camara-178\">>}":45,"{eventos_dispositivo,<<\"camara-179\">>}":54,"{eventos_dispositivo,<<\"puerta-093\">>}":49,"{eventos_dispositivo,<<\"camara-049\">>}":52,"{eventos_dispositivo,<<\"camara-106\">>}":55,"{eventos_dispositivo,<<\"camara-148\">>}":55,"{eventos_dispositivo,<<\"puerta-086\">>}":55,"{eventos_tipo,<<\"tarjeta_leida\">>}":1514,"{eventos_dispositivo,<<\"puerta-088\">>}":50,"{eventos_dispositivo,<<\"puerta-094\">>}":40,"{eventos_dispositivo,<<\"camara-035\">>}":53,"{eventos_dispositivo,<<\"camara-117\">>}":47,"{eventos_dispositivo,<<\"camara-088\">>}":54,"{eventos_dispositivo,<<\"camara-068\">>}":42,"{eventos_dispositivo,<<\"camara-177\">>}":54,"{eventos_dispositivo,<<\"puerta-030\">>}":60,"{eventos_dispositivo,<<\"camara-158\">>}":61,"{eventos_dispositivo,<<\"camara-018\">>}":51,"{eventos_dispositivo,<<\"puerta-056\">>}":51,"{eventos_dispositivo,<<\"camara-155\">>}":39,"{eventos_dispositivo,<<\"puerta-098\">>}":56,"{eventos_dispositivo,<<\"camara-188\">>}":54,"{eventos_dispositivo,<<\"camara-075\">>}":46,"{eventos_dispositivo,<<\"camara-006\">>}":49,"{eventos_dispositivo,<<\"puerta-011\">>}":45,"{eventos_dispositivo,<<\"camara-149\">>}":59,"{eventos_dispositivo,<<\"puerta-010\">>}":55,"{eventos_dispositivo,<<\"puerta-006\">>}":56,"{eventos_dispositivo,<<\"puerta-032\">>}":41,"{eventos_dispositivo,<<\"camara-057\">>}":51,"{eventos_dispositivo,<<\"camara-185\">>}":46,"{eventos_dispositivo,<<\"camara-066\">>}":44,"{eventos_dispositivo,<<\"puerta-071\">>}":59,"{eventos_dispositivo,<<\"puerta-070\">>}":62,"{eventos_dispositivo,<<\"camara-163\">>}":51,"{eventos_dispositivo,<<\"camara-017\">>}":51,"{eventos_dispositivo,<<\"puerta-005\">>}":54,"{eventos_dispositivo,<<\"puerta-038\">>}":66,"{eventos_dispositivo,<<\"camara-105\">>}":45,"{eventos_dispositivo,<<\"camara-097\">>}":51,"{eventos_dispositivo,<<\"puerta-020\">>}":45,"{eventos_dispositivo,<<\"camara-184\">>}":49,"{eventos_dispositivo,<<\"camara-027\">>}":42},"bitacora":{"cola_ingesta":0,"cp_seq":0,"pines":0,"relojes":300,"segmentos":1,"seq":15168,"ultimo_hash":"F8A99BA1004E386A8B9D7A9CFFAF47A99CD1EF3639B970E5C1D74FF0C7DAF19C"},"memoria_total":128461688,"procesos":460,"uptime_seg":174}
HTTP 200
```

## GET /api/dispositivos?edificio=G (camara-017)

```http
{
  "total": 30,
  "camara-017": [
    {
      "contadores": {
        "alarma": 5,
        "movimiento": 46
      },
      "desfasado": true,
      "edificio": "G",
      "estado": "alerta",
      "id": "camara-017",
      "offset_segundos": 240.0,
      "recientes": [
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "2194F76EABFA4170DB510BA84840E4E70B80B55B4D3C60A93D64A634BF4908BE",
          "hash_prev": "FD480113DCE805146F034C9621D9FA110A07CAA61407815CE9E97F9CB19784E0",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 14874,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380608433402,
          "ts_corregido_iso": "2026-11-11T07:03:28.433402Z",
          "ts_evento": 1794380368433402,
          "ts_evento_iso": "2026-11-11T06:59:28.433402Z",
          "ts_recepcion": 1794380608433402,
          "ts_recepcion_iso": "2026-11-11T07:03:28.433402Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "9669102A687C50F5E72732B25B81960946DB5393D781EEB07C9F521A8FA49C62",
          "hash_prev": "279C33CFF157B9562B523B0266371E47983D8595406C059259B81F1EE3485188",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 14436,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380606210240,
          "ts_corregido_iso": "2026-11-11T07:03:26.210240Z",
          "ts_evento": 1794380366210240,
          "ts_evento_iso": "2026-11-11T06:59:26.210240Z",
          "ts_recepcion": 1794380606210240,
          "ts_recepcion_iso": "2026-11-11T07:03:26.210240Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "1D0005022DEAF65D7B6E8958BBBB0310806C1C676B9378C9B08FBC411F7269F5",
          "hash_prev": "9488D3E8A5AE3F93CDF90C3246C7F1F02A9B103295049AAE6145D8AA0980F723",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 14285,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380605369980,
          "ts_corregido_iso": "2026-11-11T07:03:25.369980Z",
          "ts_evento": 1794380365369980,
          "ts_evento_iso": "2026-11-11T06:59:25.369980Z",
          "ts_recepcion": 1794380605369980,
          "ts_recepcion_iso": "2026-11-11T07:03:25.369980Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "A290FFBF3CC452D43F7EE5BC6BAE202B2DD05C3E586F6C88EDF578F63FD79C7B",
          "hash_prev": "87F8CFBCE2E83D721696C1EEFE53E0FA020FE55F9FF30FA55491214509B235BC",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 14228,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380605192342,
          "ts_corregido_iso": "2026-11-11T07:03:25.192342Z",
          "ts_evento": 1794380365192342,
          "ts_evento_iso": "2026-11-11T06:59:25.192342Z",
          "ts_recepcion": 1794380605192342,
          "ts_recepcion_iso": "2026-11-11T07:03:25.192342Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "D23A10D6660ACC7AC98EAC6067E924F37D76A45B6A6F949A2AA261A696F4C7DF",
          "hash_prev": "9E7DF2F00A836D2C9C27C9172C52F63520C1BEDD123D0C8630D93B8EB00F9459",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 13824,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380599580410,
          "ts_corregido_iso": "2026-11-11T07:03:19.580410Z",
          "ts_evento": 1794380359580410,
          "ts_evento_iso": "2026-11-11T06:59:19.580410Z",
          "ts_recepcion": 1794380599580410,
          "ts_recepcion_iso": "2026-11-11T07:03:19.580410Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "FAC01CC3CD3A4D072E9B54BC8BD602C5D8092643C85F35E37509E0BCF78A8D13",
          "hash_prev": "E1938542CD8DBB371C6CA499614DDA75C9250545F967F6901E3013B0711EE569",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 13498,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380588560569,
          "ts_corregido_iso": "2026-11-11T07:03:08.560569Z",
          "ts_evento": 1794380348560569,
          "ts_evento_iso": "2026-11-11T06:59:08.560569Z",
          "ts_recepcion": 1794380588560569,
          "ts_recepcion_iso": "2026-11-11T07:03:08.560569Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "13EB4949054CF86C5C97EC5D0682764CAC3F3C16155E22E1F619B1C3FABE7442",
          "hash_prev": "BD641C9199336E655A8B1210894CC79BCD098C4A943106F7AC0D909B8C4ACF1E",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 12985,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380577679403,
          "ts_corregido_iso": "2026-11-11T07:02:57.679403Z",
          "ts_evento": 1794380337679403,
          "ts_evento_iso": "2026-11-11T06:58:57.679403Z",
          "ts_recepcion": 1794380577679403,
          "ts_recepcion_iso": "2026-11-11T07:02:57.679403Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "8873664E3F31F0A504383C86EC699430701926EE18BC055D887036436CEBED79",
          "hash_prev": "2A7ED4E3D6572EDA2F0A6C98D228E90798DB7CF88867A632E3119F8042A6DB88",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 11352,
          "tipo_dispositivo": "camara",
          "tipo_evento": "alarma",
          "ts_corregido": 1794380548067260,
          "ts_corregido_iso": "2026-11-11T07:02:28.067260Z",
          "ts_evento": 1794380308067260,
          "ts_evento_iso": "2026-11-11T06:58:28.067260Z",
          "ts_recepcion": 1794380548067260,
          "ts_recepcion_iso": "2026-11-11T07:02:28.067260Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "644F72F83979FCBEBC3719F4EC25DA7966A4B3E3E59C65E58D03815E3BF1AAF7",
          "hash_prev": "AA6CB5D07AE20D1AB4AA9036FE27AE18C37F6253E430620186BA352FB9587D57",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 11308,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380547908116,
          "ts_corregido_iso": "2026-11-11T07:02:27.908116Z",
          "ts_evento": 1794380307908116,
          "ts_evento_iso": "2026-11-11T06:58:27.908116Z",
          "ts_recepcion": 1794380547908116,
          "ts_recepcion_iso": "2026-11-11T07:02:27.908116Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "3A71DB4E7490340507AA8CA8441FA99B4656676F54B4D999BD03F4AF3CF3D0C4",
          "hash_prev": "6911360999C1E93DD6ABDDD9B9BC17634ED9834CF861A3335685B450688FC970",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 11264,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380547632744,
          "ts_corregido_iso": "2026-11-11T07:02:27.632744Z",
          "ts_evento": 1794380307632744,
          "ts_evento_iso": "2026-11-11T06:58:27.632744Z",
          "ts_recepcion": 1794380547632744,
          "ts_recepcion_iso": "2026-11-11T07:02:27.632744Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "D3DD1026402EAF50DBBB17CB08A3E56BD2AE2C9B3D6CA31C8FE1F552DE0DD4C9",
          "hash_prev": "4D959C9AC139BE9EB4BD6921D4AA226A35BA3BEC913A83B8FA1AA568044D660E",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 11150,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380547099719,
          "ts_corregido_iso": "2026-11-11T07:02:27.099719Z",
          "ts_evento": 1794380307099719,
          "ts_evento_iso": "2026-11-11T06:58:27.099719Z",
          "ts_recepcion": 1794380547099719,
          "ts_recepcion_iso": "2026-11-11T07:02:27.099719Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "3CEADF99B101007CAD1B296EAE26A7F73692AF00D758CEAA153394F7711BF3FD",
          "hash_prev": "E4D801CC38E6F3A0D27E0E793FC150798DB5204E742B92D7BB19192E2A3E9E87",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 10969,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380546155350,
          "ts_corregido_iso": "2026-11-11T07:02:26.155350Z",
          "ts_evento": 1794380306155350,
          "ts_evento_iso": "2026-11-11T06:58:26.155350Z",
          "ts_recepcion": 1794380546155350,
          "ts_recepcion_iso": "2026-11-11T07:02:26.155350Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "5DB87D1267FDAF9DA6B1C7BAC0444A2CECCE6CE06B33F919735586050EABBC70",
          "hash_prev": "CA19401F593FA586DEEE6CBE6F6597B09E0B44EB5EBADEC18DFB8E9866B90C66",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 10244,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380535584797,
          "ts_corregido_iso": "2026-11-11T07:02:15.584797Z",
          "ts_evento": 1794380295584797,
          "ts_evento_iso": "2026-11-11T06:58:15.584797Z",
          "ts_recepcion": 1794380535584797,
          "ts_recepcion_iso": "2026-11-11T07:02:15.584797Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "6B0B706C4DDC85A983730609D42C48C74788A7D4293A307029D272C30A77F161",
          "hash_prev": "08EC01B55B949C3345990C2CBBE013B1727055E115AC666597566F2079CDD6A7",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 9729,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380518658569,
          "ts_corregido_iso": "2026-11-11T07:01:58.658569Z",
          "ts_evento": 1794380278658569,
          "ts_evento_iso": "2026-11-11T06:57:58.658569Z",
          "ts_recepcion": 1794380518658569,
          "ts_recepcion_iso": "2026-11-11T07:01:58.658569Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "32E1907B9E71AFF38F32B52ABC5D33EECE82A84E15AC925BDED974AA68B6CD7A",
          "hash_prev": "04A13683C638175D773B635984ADA5CEA5FA48B815B511437ABC762FFF607C1D",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 9177,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380515788174,
          "ts_corregido_iso": "2026-11-11T07:01:55.788174Z",
          "ts_evento": 1794380275788174,
          "ts_evento_iso": "2026-11-11T06:57:55.788174Z",
          "ts_recepcion": 1794380515788174,
          "ts_recepcion_iso": "2026-11-11T07:01:55.788174Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "A3F039F73EBAF3F81253039EA81C04D5A21BFC89BDA97C5E2E4797AC03F72E78",
          "hash_prev": "9E279A347DA044E716186075874710B6771A12B3BB6AB0F5420C1C4CABDB046A",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 8195,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380494533874,
          "ts_corregido_iso": "2026-11-11T07:01:34.533874Z",
          "ts_evento": 1794380254533874,
          "ts_evento_iso": "2026-11-11T06:57:34.533874Z",
          "ts_recepcion": 1794380494533874,
          "ts_recepcion_iso": "2026-11-11T07:01:34.533874Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "8D32EECF58F2DA11A485633D92AD82635A4A819FCA68C1DB84375A0EA748C804",
          "hash_prev": "A67A02A3C30CFA12AC6FB3ABEBD9B1C0977E1AA4B16DDA75AC3B564265E8EE5A",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 7873,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380488000206,
          "ts_corregido_iso": "2026-11-11T07:01:28.000206Z",
          "ts_evento": 1794380248000206,
          "ts_evento_iso": "2026-11-11T06:57:28.000206Z",
          "ts_recepcion": 1794380488000206,
          "ts_recepcion_iso": "2026-11-11T07:01:28.000206Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "5DB888F639B3CF746C3DF01878E0031B3306F03E707343FAA5AC3B951F726F08",
          "hash_prev": "B29A55516E89BDF46D2E1F705F3CB12DE00DF1EF30AA91AD8F41D294BDB68FFA",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 7819,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380487684267,
          "ts_corregido_iso": "2026-11-11T07:01:27.684267Z",
          "ts_evento": 1794380247684267,
          "ts_evento_iso": "2026-11-11T06:57:27.684267Z",
          "ts_recepcion": 1794380487684267,
          "ts_recepcion_iso": "2026-11-11T07:01:27.684267Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "C4E5CE348A9DB8B45CC41E8E966BF5857E45026C2514235262549CE87CBFF6C7",
          "hash_prev": "C80C26EB23298A3BBC4445A89FBCABC199F06F69ABDAC8004E75BFEB859C8976",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 7146,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380484301275,
          "ts_corregido_iso": "2026-11-11T07:01:24.301275Z",
          "ts_evento": 1794380244301275,
          "ts_evento_iso": "2026-11-11T06:57:24.301275Z",
          "ts_recepcion": 1794380484301275,
          "ts_recepcion_iso": "2026-11-11T07:01:24.301275Z"
        },
        {
          "desfasado": true,
          "dispositivo_id": "camara-017",
          "edificio": "G",
          "hash": "1539B69E57F62FA6AED10F70AC22CCC91823E37FF4400BBF16ED2D56CC47FCF8",
          "hash_prev": "C6C3CABF3CFA7509971640D2FCA3BAC0981F0BBDB0CF8A444BA758ACAD43E15C",
          "offset_reloj": 240000000,
          "persona": null,
          "seq": 7067,
          "tipo_dispositivo": "camara",
          "tipo_evento": "movimiento",
          "ts_corregido": 1794380483928209,
          "ts_corregido_iso": "2026-11-11T07:01:23.928209Z",
          "ts_evento": 1794380243928209,
          "ts_evento_iso": "2026-11-11T06:57:23.928209Z",
          "ts_recepcion": 1794380483928209,
          "ts_recepcion_iso": "2026-11-11T07:01:23.928209Z"
        }
      ],
      "tipo": "camara",
      "ultimo_latido": 1794380608433402,
      "ultimo_latido_iso": "2026-11-11T07:03:28.433402Z"
    }
  ]
}
HTTP 200
```

## GET /api/eventos?limite=3

```http
{"offset":0,"total":14929,"eventos":[{"desfasado":false,"dispositivo_id":"camara-127","edificio":"G","hash":"3E9A2D5C76AA51842431C324D6E9F420FA70AAEED349A4FE63EDA3C61A77EB12","hash_prev":"AD28BE0550BE83FB5053D218634A7399FCFA5208BDE6FA695A767CCC0A79261B","offset_reloj":71869,"persona":null,"seq":242,"tipo_dispositivo":"camara","tipo_evento":"movimiento","ts_corregido":1794377017833100,"ts_corregido_iso":"2026-11-11T06:03:37.833100Z","ts_evento":1794377017761231,"ts_evento_iso":"2026-11-11T06:03:37.761231Z","ts_recepcion":1794377017833100,"ts_recepcion_iso":"2026-11-11T06:03:37.833100Z"},{"desfasado":false,"dispositivo_id":"camara-157","edificio":"G","hash":"58EF7358F0E1B4ADF69CD8746937742A83100A1EAAF77B7A0E820D4D6BF77A79","hash_prev":"3E9A2D5C76AA51842431C324D6E9F420FA70AAEED349A4FE63EDA3C61A77EB12","offset_reloj":42961,"persona":null,"seq":243,"tipo_dispositivo":"camara","tipo_evento":"movimiento","ts_corregido":1794377017853943,"ts_corregido_iso":"2026-11-11T06:03:37.853943Z","ts_evento":1794377017810982,"ts_evento_iso":"2026-11-11T06:03:37.810982Z","ts_recepcion":1794377017893830,"ts_recepcion_iso":"2026-11-11T06:03:37.893830Z"},{"desfasado":false,"dispositivo_id":"puerta-063","edificio":"C","hash":"A2A84409BD8A747804D0D7E3A60D5259270FFA821B2AB913451DAC1B8FA5EEC7","hash_prev":"58EF7358F0E1B4ADF69CD8746937742A83100A1EAAF77B7A0E820D4D6BF77A79","offset_reloj":66269,"persona":"persona-12","seq":244,"tipo_dispositivo":"puerta","tipo_evento":"puerta_abierta","ts_corregido":1794377019246551,"ts_corregido_iso":"2026-11-11T06:03:39.246551Z","ts_evento":1794377019180282,"ts_evento_iso":"2026-11-11T06:03:39.180282Z","ts_recepcion":1794377019246551,"ts_recepcion_iso":"2026-11-11T06:03:39.246551Z"}],"desde":1794377016943392,"desde_iso":"2026-11-11T06:03:36.943392Z","hasta":1794380616943392,"hasta_iso":"2026-11-11T07:03:36.943392Z","limite":3}
HTTP 200

```

## GET /api/bitacora/verificar

```http
{"integridad":"ok","resumen":{"checkpoints":0,"eliminados":0,"eventos":15171,"ultimo_seq":15171}}
HTTP 200
```

## GET /metrics

```text
# HELP p69_eventos_total Eventos aceptados desde el arranque
# TYPE p69_eventos_total counter
p69_eventos_total 15171
# HELP p69_ingesta_rechazada_total Eventos rechazados (validacion o sobrecarga)
# TYPE p69_ingesta_rechazada_total counter
p69_ingesta_rechazada_total 0
# HELP p69_alertas_reloj_total Eventos marcados con reloj desfasado
# TYPE p69_alertas_reloj_total counter
p69_alertas_reloj_total 61
# HELP p69_consultas_total Consultas de rango ejecutadas
# TYPE p69_consultas_total counter
p69_consultas_total 5
# HELP p69_consulta_latencia_promedio_us Latencia promedio de consultas
# TYPE p69_consulta_latencia_promedio_us gauge
p69_consulta_latencia_promedio_us 13272
# HELP p69_cola_ingesta Mensajes pendientes en la bitacora
# TYPE p69_cola_ingesta gauge
p69_cola_ingesta 0
# HELP p69_segmentos Segmentos temporales activos
# TYPE p69_segmentos gauge
p69_segmentos 1
# HELP p69_segmentos_eventos Eventos en segmentos activos
# TYPE p69_segmentos_eventos gauge
p69_segmentos_eventos 15171
# HELP p69_segmentos_memoria_bytes Memoria ETS de los segmentos
# TYPE p69_segmentos_memoria_bytes gauge
p69_segmentos_memoria_bytes 11626312
# HELP p69_dispositivos_total Dispositivos conocidos
# TYPE p69_dispositivos_total gauge
p69_dispositivos_total 300
# HELP p69_camaras_offline Camaras en estado falla
# TYPE p69_camaras_offline gauge
p69_camaras_offline 6
# HELP p69_puertas_offline Puertas en estado falla
# TYPE p69_puertas_offline gauge
p69_puertas_offline 3
# HELP p69_dispositivos_alerta Dispositivos en alerta
# TYPE p69_dispositivos_alerta gauge
p69_dispositivos_alerta 12
p69_eventos_dispositivo{dispositivo="camara-140"} 53
p69_eventos_dispositivo{dispositivo="camara-149"} 59
p69_eventos_dispositivo{dispositivo="camara-073"} 44
p69_eventos_dispositivo{dispositivo="camara-077"} 47
p69_eventos_dispositivo{dispositivo="camara-182"} 41
p69_eventos_dispositivo{dispositivo="camara-150"} 55
p69_eventos_dispositivo{dispositivo="camara-164"} 64
p69_eventos_dispositivo{dispositivo="puerta-025"} 60
p69_eventos_dispositivo{dispositivo="camara-021"} 57
p69_eventos_dispositivo{dispositivo="camara-122"} 63
p69_eventos_dispositivo{dispositivo="camara-033"} 53
p69_eventos_dispositivo{dispositivo="puerta-002"} 57
p69_eventos_dispositivo{dispositivo="camara-048"} 55
p69_eventos_dispositivo{dispositivo="camara-082"} 40
p69_eventos_dispositivo{dispositivo="camara-128"} 52
p69_eventos_dispositivo{dispositivo="puerta-077"} 47
p69_eventos_dispositivo{dispositivo="puerta-021"} 51
p69_eventos_dispositivo{dispositivo="camara-146"} 53
p69_eventos_dispositivo{dispositivo="camara-195"} 50
p69_eventos_dispositivo{dispositivo="camara-020"} 42
p69_eventos_dispositivo{dispositivo="camara-006"} 49
p69_eventos_dispositivo{dispositivo="puerta-035"} 52
p69_eventos_dispositivo{dispositivo="puerta-067"} 49
p69_eventos_dispositivo{dispositivo="camara-041"} 50
p69_eventos_dispositivo{dispositivo="puerta-004"} 56
p69_eventos_dispositivo{dispositivo="puerta-030"} 60
p69_eventos_dispositivo{dispositivo="camara-136"} 47
p69_eventos_dispositivo{dispositivo="camara-179"} 54
p69_eventos_dispositivo{dispositivo="camara-114"} 45
p69_eventos_dispositivo{dispositivo="puerta-070"} 62
p69_eventos_dispositivo{dispositivo="camara-059"} 58
p69_eventos_dispositivo{dispositivo="camara-119"} 53
p69_eventos_dispositivo{dispositivo="camara-026"} 36
p69_eventos_dispositivo{dispositivo="camara-105"} 45
p69_eventos_dispositivo{dispositivo="camara-047"} 48
p69_eventos_dispositivo{dispositivo="puerta-051"} 46
p69_eventos_dispositivo{dispositivo="puerta-069"} 62
p69_eventos_dispositivo{dispositivo="puerta-056"} 51
p69_eventos_dispositivo{dispositivo="camara-008"} 43
p69_eventos_dispositivo{dispositivo="camara-103"} 49
p69_eventos_dispositivo{dispositivo="camara-116"} 58
p69_eventos_dispositivo{dispositivo="puerta-008"} 46
p69_eventos_dispositivo{dispositivo="camara-155"} 39
p69_eventos_dispositivo{dispositivo="camara-045"} 49
p69_eventos_dispositivo{dispositivo="puerta-040"} 57
p69_eventos_dispositivo{dis
```
