# AGENTS.md — Proyecto #69 Cámaras y accesos (Erlang/OTP)

Reglas permanentes para cualquier agente que trabaje en este repo. Sobreviven a la compactación de contexto.

## Contexto
- Proyecto de Programación Lógica y Funcional (5.º semestre). Dominio: Seguridad y ciudad. Bitácora de eventos y búsqueda por rango de tiempo.
- Enunciado: `problema/readme.md`. Diseño sugerido: `README.md`. Prompt de UI: `design/PROMPT_STITCH.md`.
- Stack: Erlang/OTP, rebar3, cowboy 2.x, recon, releases + systemd. Entorno: Ubuntu sobre WSL2.
- Objetivo actual: entregable de la DEMO (rúbrica: solución funcional, montaje en VM, demostración, UIX con Google Stitch, manual en Gist, calidad de código, integración, argumentación técnica).

## Comandos
- `rebar3 compile` y `rebar3 eunit` deben quedar en verde (`warnings_as_errors` activo; no lo desactives).
- `rebar3 shell` para pruebas manuales; `rebar3 as prod release` para el release.

## Convenciones de código
- Prefijo de módulos `p69_camaras_y_accesos_` (o `p69_` consistente). Código en ASCII sin acentos; comentarios en español explicando el porqué.
- `-spec`/`-type` en funciones exportadas. Lógica pura separada de procesos y de I/O.
- Errores explícitos `{ok,_}`/`{error,_}`; "let it crash" con supervisión que lo respalde; sin `catch` genérico.
- Parámetros en `config/sys.config` (`application:get_env`), sin números mágicos.
- Si OTP >= 27 usar el módulo `json` estándar.

## Reglas de honestidad y seguridad
- No declares que algo funciona sin haberlo ejecutado; muestra la salida relevante.
- No inventes cifras, mediciones ni fuentes. Lo no verificado se marca "no verificado".
- Google Stitch lo opera el usuario a mano. NUNCA fabriques una UI y la presentes como hecha con Stitch; la UI final sale del export en `design/`.
- Pregunta antes de: `sudo`, instalar paquetes, `git push`, publicar Gists, borrar archivos, cambiar dependencias.
- No toques nada fuera de este proyecto.

## Seguimiento
- Mantén `docs/PROGRESO.md` (estado, decisiones, pendientes) y `docs/PENDIENTE_USUARIO.md` (todo lo que requiere acción manual del usuario: Stitch, capturas, Gist, confirmar entorno, ensayar demo).
- Commit al terminar cada fase, tras compile + eunit en verde.
