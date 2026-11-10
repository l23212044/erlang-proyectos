# Prueba de caos - resultados medidos

Fecha: 2026-11-09 23:40:58
Entorno: OTP 27, 20 nucleos, Ubuntu sobre WSL2.
Datos: `/tmp/p69_caos_1794296416` (eventos base=1000000).
Comando reproducible:

```bash
scripts/caos.sh --eventos 1000000
```

El script arranca la aplicacion con una carpeta temporal, puerto efimero,
retencion desactivada y segmentos de una hora; carga los eventos con el
simulador real, ejecuta las fallas y escribe esta tabla con los numeros de la
corrida. No usa valores precargados ni estimaciones.

| Escenario | Que se esperaba | Que ocurrio | Medicion |
|---|---|---|---|
| Carga base | eventos aceptados y seq monotona | seq=1000000 presentes=1000000 | 12144 ms (82345.2 ev/s) |
| Consulta durante la ingesta | la consulta responde mientras la ingesta sigue | 20 consultas (10 durante la ingesta); loader vivo al final=false; seq final=1300000 | inactiva=314198 us; durante prom=353367.3 us; ingesta=4209 ms |
| Matar un dispositivo | el supervisor del sitio lo reinicia y sigue aceptando eventos | nuevo pid <0.467.0>; evento posterior ok | 5 ms |
| Matar un sitio_sup | se reinicia el sitio y se recrean sus dispositivos | nuevo sitio <0.468.0>; evento posterior ok | 5 ms |
| Matar p69_retencion | el supervisor lo reinicia | reinicio={ok,<0.470.0>} | 5 ms |
| Matar un proceso de consulta | el llamador recibe error y la bitacora sigue viva | consulta={error,{consulta_fallo,killed}} | captura={ok,<0.474.0>}; 6 ms |
| Matar la bitacora (duena de ETS/WAL) | recupera el WAL, conserva seq y la verificacion queda ok | seq 1300002 -> 1300002; presentes 1300002 -> 1300002; verif={ok,#{eventos => 1300002,ultimo_seq => 1300002,checkpoints => 0,eliminados => 0}} | recuperacion=11619 ms; verificacion=4854 ms; dependientes=[{p69_http,<0.481.0>},{p69_sitios,<0.478.0>},{p69_retencion,<0.480.0>},{p69_eventos_pub,<0.476.0>}] |
| Retencion con consulta en curso | en_uso durante el pin, borrado al cerrar, cadena sigue ok | con pin={498366,en_uso} sigue=true; sin pin={498366,ok} borrado=true; verif={ok,#{eventos => 1300002,ultimo_seq => 1302002,checkpoints => 2,eliminados => 2000}} | 1 ms + 0 ms |
| Verificacion final | cadena integra despues de retencion | {ok,#{eventos => 1300002,ultimo_seq => 1302002,checkpoints => 2,eliminados => 2000}} | - |

## Interpretacion honesta

- **Carga base**: 1,000,000 de eventos aceptados, `seq` y eventos presentes
  coinciden. La tasa medida fue 82,345 ev/s en esta corrida (incluye generar,
  escribir el WAL, sincronizar y actualizar ETS). No es una cifra teorica.
- **Consulta durante la ingesta**: se midio una consulta en reposo (314 ms) y 20
  consultas mientras se cargaban otros 300,000 eventos. 10 de las 20 ocurrieron
  con el proceso de ingesta todavia vivo; el promedio fue 353 ms, ~12 % mas que
  en reposo. La ingesta no se detuvo: termino en 4,209 ms y el `seq` llego a
  1,300,000. Las ultimas consultas ya corrieron despues de que el loader
  terminara, por eso `loader vivo al final=false`.
- **Dispositivo y sitio**: los reinicios fueron inmediatos (5 ms). Tras matar el
  sitio, un evento nuevo recreo el dispositivo; esto valida la correccion de la
  cache de sitios muertos agregada en esta fase.
- **Retencion**: el proceso se reinicio en 5 ms. La prueba con pin demuestra que
  el segmento con una consulta activa responde `en_uso` y no se borra; al cerrar
  la consulta se borra y la verificacion sigue siendo `ok`.
- **Consulta**: al matar el worker de consulta, el llamador recibe
  `{error,{consulta_fallo,killed}}`; la bitacora sigue operando.
- **Bitacora**: se mato con `kill` al proceso dueno de ETS/WAL despues de que los
  ACK ya estaban sincronizados. El supervisor raiz reinicio la bitacora y sus
  dependientes; la recuperacion desde el WAL tardo 11,619 ms, conservo el mismo
  `seq` (1,300,002) y los mismos eventos presentes, y la verificacion de la
  cadena tardo 4,854 ms y quedo `ok`.
- **Limites**: el WAL no se trunca en esta version y el libro de hashes conserva
  una entrada por evento; con millones de eventos el arranque crece de forma
  lineal. El reinicio del dispositivo pierde su estado efimero (contadores y
  ultimos 20 eventos en memoria), no los eventos de la bitacora.

## Detalle de la corrida

```text
#{durante => 10,
  carga => {ok,#{eventos => 300000, duracion_ms => 4209,
                 desde => 1794289229381891, hasta => 1794296429381891}},
  latencias_us => [365496,367725,446293,476415,432597,481655,423041,
                   415531,424571,374297,284575,320198,268394,292301,
                   320693,279360,262911,292601,268567,270126],
  promedio_us => 353367.35,
  vivo_al_terminar => false}
```

Estado final:

```text
#{seq => 1300002, segmentos => 3, cola_ingesta => 0, cp_seq => 0,
  pines => 0, relojes => 300,
  ultimo_hash => <<249,184,40,115,192,176,163,3,57,235,35,168,196,84,244,
                   232,74,88,195,236,166,83,109,106,108,159,59,195,73,124,
                   150,65>>}
```

Verificacion final: `{ok,#{eventos => 1300002, ultimo_seq => 1302002,
checkpoints => 2, eliminados => 2000}}`.
