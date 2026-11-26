# Supuestos del gemelo — Situacion 1

Reglas y umbrales que el estudiante declaro para la Situacion 1 (el tecnico y
la escolta). Son **supuestos propios del ejercicio**, no cifras verificadas.

## Escenario modelado

- Edificio B: unica puerta de salida con lector es la lateral.
- La escolta `escolta1` paso la tarjeta en el muelle a la 1:50 (minuto 110).
- El lector lateral lleva 60 minutos sin reportar al minuto 130.
- El tecnico `tecnico` pide entrar a la boveda al minuto 130.

## Umbrales declarados

| Supuesto | Valor | Por que |
|---|---|---|
| `umbral_silencio` | 30 min | silencio que vuelve dudoso a un lector de salida |
| `margen_reloj` | 5 min | margen para decidir si un evento es antes o despues |
| `nivel_boveda` | 3 (B-3) | nivel exacto para entrar a la boveda |
| `max_contratistas_escolta` | 2 | contratistas que responde una escolta |

## Reglas de presencia

- **Presente:** hay entrada y no hay salida, con los lectores de salida sanos
  (ninguno supera el umbral de silencio).
- **Ausente:** hay una salida registrada despues de la entrada (con el margen).
- **No se sabe:** hay entrada sin salida y el unico lector de salida supera el
  umbral de silencio. Si el lector vuelve y registra la salida, pasa a ausente.

No se concluye "presente" por negacion de fallo: la ausencia de evento de salida
con un lector caido no prueba que la persona siga adentro. Para declarar presente
se exige el hecho positivo `en_linea(Lector)` y que ese lector no supere el
umbral; el `\+` solo descalifica, nunca establece salud.

## Decision del tecnico

- Exige credencial vigente, nivel exactamente B-3, capacitacion vigente y turno.
- Exige escolta de planta con nivel B-3, vigente, presente y con cupo.
- Si la escolta esta en duda: `aplazar(salida_registrada(Escolta, b))`.
- `condicionar` queda reservado para cuando el dato que resuelve la duda ya esta
  disponible; hoy no se usa.

## Diferencias contra `gemelo/PROBLEMA.md`

- La regla (a) dice "nivel B-3" y en ningun punto admite un nivel superior; por
  eso se implemento nivel **exactamente B-3**. Un nivel 4 no sustituye al B-3.
- La regla (b) no pide turno vigente para la escolta; por eso no se exige turno
  de la escolta, solo su nivel, vigencia y presencia.
- El criterio "con lector en linea que confirma la salida, se niega" se cumple:
  al agregar la salida registrada, `consta_dentro` pasa a `ausente` y la
  decision a `negar`.

## Como correr las pruebas

```bash
cd gemelo
swipl -g run_tests -t halt tests/reglas_tests.pl
```

Estado: 5 pruebas de la Situacion 1 en verde.
