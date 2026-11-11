# Pendiente de tu accion — #69 Camaras y accesos

Todo lo que requiere intervencion manual del usuario. Se actualiza al final de cada fase.

## Ahora (Fase 6 terminada)

- [ ] Instalar Erlang/rebar3 a nivel sistema. El agente no puede autenticar `sudo` sin TTY.
      Comando en tu terminal:
      `sudo apt-get update && sudo apt-get install -y erlang rebar3`
      (No es bloqueante: ya hay un toolchain local en `~/.local/opt/erlang-p69`).
- [ ] Revisar el directorio duplicado `/home/zero/erlang-proyectos/erlang-proyectos/`.
      El proyecto real es `/home/zero/erlang-proyectos/proyectos/69-camaras-y-accesos/`;
      se copio `AGENTS.md` aqui. Puedes borrar el duplicado cuando quieras.

## Fase 5 (UI integrada) - accion del usuario

- [x] Export de Google Stitch integrado en `priv/www/` (dashboard, bitacora y nodo).
- [ ] Abrir `http://localhost:8080/` desde el navegador de Windows con la app
      arrancada y revisar escritorio y movil.
- [ ] Guardar capturas de pantalla de la **app real** para la entrega.
- [ ] Reportar cualquier detalle visual que no coincida con el export de Stitch.

## Fase 6 (release y systemd) - accion del usuario

- [ ] Construir el release: `rebar3 as prod release`.
- [ ] Instalar el servicio en la VM: `sudo scripts/instalar_servicio.sh`.
      (El agente no puede ejecutar `sudo` interactivo.)
- [ ] Verificar: `systemctl status p69-camaras-y-accesos` y
      `curl -sS http://127.0.0.1:8080/api/salud`.
- [ ] Detener `rebar3 shell` antes de instalar si usa el puerto `8080`.
- [ ] Seguir `docs/DESPLIEGUE.md` para actualizar o desinstalar.

Para probar el backend con carga y caos:

- [ ] `scripts/simular.sh --modo completo --duracion 60` (arranca la app con
      puerto efimero y carga ~1.08M de eventos historicos; tarda unos segundos).
- [ ] `scripts/caos.sh --eventos 1000000` y revisar la tabla de `docs/CAOS.md`.
- [ ] Detener el servicio/release antes de simular si usa la misma carpeta `data/`
      para no abrir el mismo WAL desde dos nodos.

Para ver el dashboard con datos frescos, arranca la app y carga eventos recientes;
los datos historicos muy antiguos aparecen como `falla` por falta de latido.

## Fase 7 (Manual y entrega)

- [ ] Tomar capturas de la app real.
- [ ] Revisar y publicar el Gist (no se publicara sin tu confirmacion).
- [ ] Ensayar la demo completa en la VM.
