# Pendiente de tu accion — #69 Camaras y accesos

Todo lo que requiere intervencion manual del usuario. Se actualiza al final de cada fase.

## Ahora (Fase 3 terminada)

- [ ] Instalar Erlang/rebar3 a nivel sistema. El agente no puede autenticar `sudo` sin TTY.
      Comando en tu terminal:
      `sudo apt-get update && sudo apt-get install -y erlang rebar3`
      (No es bloqueante: ya hay un toolchain local en `~/.local/opt/erlang-p69`).
- [ ] Revisar el directorio duplicado `/home/zero/erlang-proyectos/erlang-proyectos/`.
      El proyecto real es `/home/zero/erlang-proyectos/proyectos/69-camaras-y-accesos/`;
      se copio `AGENTS.md` aqui. Puedes borrar el duplicado cuando quieras.

## Fase 3 (API ya estable) - accion inmediata del usuario

- [ ] Abrir Google Stitch y pegar el contenido de `design/PROMPT_STITCH.md`.
      Pedir las 4 pantallas en escritorio y movil: panel en vivo, bitacora,
      dispositivos y detalle, integridad y salud.
- [ ] Exportar el zip de Stitch (con `DESIGN.md`) y descomprimirlo dentro de
      `design/`.
- [ ] Guardar capturas de pantalla de Stitch para la entrega.
- [ ] Opcional: probar `http://localhost:8080/` desde el navegador de Windows con
      el proyecto arrancado para confirmar el acceso.

Mientras esperas el diseno, puedes probar el simulador y el caos:

- [ ] `scripts/simular.sh --modo completo --duracion 60` (arranca la app con
      puerto efimero y carga ~1.08M de eventos historicos; tarda unos segundos).
- [ ] `scripts/caos.sh --eventos 1000000` y revisar la tabla de `docs/CAOS.md`.
- [ ] Detener el servicio/release antes de simular si usa la misma carpeta `data/`
      para no abrir el mismo WAL desde dos nodos.

No hace falta que hagas nada mas para que el agente continue: al recibir el export
en `design/` se integrara en Fase 5.

## Fase 5 (integracion de la UI)

## Fase 7 (Manual y entrega)

- [ ] Tomar capturas de la app real.
- [ ] Revisar y publicar el Gist (no se publicara sin tu confirmacion).
- [ ] Ensayar la demo completa en la VM.
