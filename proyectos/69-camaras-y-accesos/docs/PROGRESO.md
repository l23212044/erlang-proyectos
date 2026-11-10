# Progreso — #69 Camaras y accesos

Bitacora de trabajo para poder retomar la sesion si se corta. Se actualiza al final de cada fase.

## Estado general

- Fase 1 (Entorno): **completada** (toolchain local; ver nota).
- Fases 2 a 7: pendientes.

## Entorno verificado

- Ubuntu 26.04.1 LTS sobre WSL2, PID 1 = systemd (`/etc/wsl.conf` con `systemd=true`).
- `nproc` = 20 nucleos.
- OTP 27.3.4.6 y rebar3 3.26.0.
- Nota: `sudo` de este entorno pide autenticacion interactiva y el shell del agente no
  tiene TTY, por lo que no se pudo instalar con `apt`. Se extrajeron los paquetes
  oficiales de Ubuntu en `~/.local/opt/erlang-p69` y `~/.local/bin/rebar3` para poder
  trabajar. El `scripts/setup.sh` sigue usando `apt` para una VM normal.

Para usar el toolchain local en esta maquina:

```bash
export PATH="$HOME/.local/opt/erlang-p69/bin:$HOME/.local/bin:$PATH"
```

## Decisiones tomadas

- Zona horaria de almacenamiento: UTC (la API acepta ISO-8601 con offset).
- Puerto HTTP por defecto: 8080; interfaz 0.0.0.0 para alcanzar la UI desde Windows.
- Retencion por defecto: 30 dias; segmentos diarios.
- Cookie de Erlang generada aleatoriamente (no queda `cambiar_en_produccion`).
- Uso del modulo estandar `json` de OTP 27 (menos dependencias).

## Pendientes reales

- Instalar Erlang/rebar3 con `apt` a nivel sistema cuando haya TTY/sudo (necesario para
  desplegar el servicio systemd con rutas estandar; el release puede incluir su propio ERTS).
- Mejorar `design/PROMPT_STITCH.md` (Fase 3) y esperar el export del usuario (Fase 5).
- Simulador, caos, UI, release/systemd, manual (Fases 4 a 7).

## Registro de fases

### Fase 1 — Entorno

- `rebar3 compile`: OK.
- `rebar3 eunit`: 2 tests, 0 fallos.
- `scripts/setup.sh` creado (idempotente).
- `config/vm.args` ajustado a 20 nucleos y cookie aleatoria.
- `config/sys.config` con parametros base (puerto, datos, retencion, umbrales de ingesta).
