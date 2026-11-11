# #69 — Camaras y accesos

**Dominio:** Seguridad y ciudad

Bitacora de eventos y busqueda por rango de tiempo para camaras y controles de
acceso, con API REST, WebSocket, panel en vivo y verificacion de integridad.

## Equipo

| Rol | Integrante |
|---|---|
| Backend (OTP) | |
| Frontend (Stitch + cowboy) | |
| Ops/QA | |

## Arranque de desarrollo

```bash
export PATH="$HOME/.local/opt/erlang-p69/bin:$HOME/.local/bin:$PATH"
rebar3 compile
rebar3 eunit
rebar3 shell
```

La app queda en `http://localhost:8080/`:

- Dashboard: `/`
- Bitacora: `/bitacora.html`
- Detalle de nodo: `/nodo.html`
- API: `/api/salud`, `/api/eventos`, `/api/dispositivos`, `/api/alertas`
- WebSocket: `/ws/eventos`
- Metricas: `/metrics`

Dentro de `rebar3 shell` se puede cargar el escenario del simulador:

```erlang
p69_simulador:historico(#{eventos => 2000, horas => 1, dias_atras => 0}).
{ok, Pid} = p69_simulador:carga(#{duracion_s => 60, tasa => 20}).
```

## Release y systemd

```bash
rebar3 as prod release
sudo scripts/instalar_servicio.sh
```

Detalle completo en [`docs/DESPLIEGUE.md`](docs/DESPLIEGUE.md).

## Documentacion

- [`problema/readme.md`](problema/readme.md): enunciado.
- [`docs/PROGRESO.md`](docs/PROGRESO.md): estado por fase y decisiones.
- [`docs/CAOS.md`](docs/CAOS.md): mediciones reales de carga y caos.
- [`docs/PENDIENTE_USUARIO.md`](docs/PENDIENTE_USUARIO.md): acciones manuales.
- [`design/PROMPT_STITCH.md`](design/PROMPT_STITCH.md): prompt de UI.

## Arquitectura OTP

- Un `gen_server` por camara/lector; supervisores por edificio.
- Bitacora aislada y duena de ETS/WAL, con hashes SHA-256 encadenados.
- Consultas efimeras para no bloquear la ingesta.
- Retencion por segmentos con pines de consulta y checkpoints.
- Cowboy para REST, WebSocket y estaticos; recon para diagnostico.
