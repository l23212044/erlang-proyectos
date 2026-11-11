# Evidencia de backend

Pruebas ejecutadas contra el release real, no contra mocks.

- [`pruebas/eunit.txt`](pruebas/eunit.txt): `rebar3 compile` y `rebar3 eunit`
  (51 pruebas, 0 fallos).
- [`pruebas/api.md`](pruebas/api.md): release en ejecucion y respuestas reales
  de salud, dispositivos, eventos, verificacion de integridad y metricas.
- [`../docs/CAOS.md`](../docs/CAOS.md): prueba de caos con 1,000,000 de eventos y
  recuperacion tras fallos inducidos.

Capturas de la UI en [`Capturas.md`](Capturas.md).
