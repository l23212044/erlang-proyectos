# Despliegue en VM (release + systemd)

Este documento cubre el montaje de la demo en una VM Ubuntu con systemd.
El release se construye en la maquina de desarrollo; no requiere `sudo` hasta
el momento de instalar el servicio.

## Requisitos

- Ubuntu con systemd (`systemctl` funcional).
- El proyecto compilado y con pruebas en verde:
  `rebar3 compile` y `rebar3 eunit`.
- `sudo` con TTY para crear el usuario `p69`, copiar el release e instalar la
  unidad de systemd.

## 1. Construir el release de produccion

```bash
cd proyectos/69-camaras-y-accesos
export PATH="$HOME/.local/opt/erlang-p69/bin:$HOME/.local/bin:$PATH"
rebar3 as prod release
```

El artefacto queda en:

```text
_build/prod/rel/p69_camaras_y_accesos/
```

El perfil `prod` usa `config/sys.config.prod`:

- puerto `8080`
- datos persistentes en `/var/lib/p69-camaras-y-accesos`
- retencion de 30 dias

## 2. Instalar el servicio

Desde la raiz del proyecto:

```bash
sudo scripts/instalar_servicio.sh
```

El script:

1. crea el usuario de sistema `p69` si no existe;
2. crea `/var/lib/p69-camaras-y-accesos` con permisos `0750`;
3. copia el release a `/opt/p69-camaras-y-accesos`;
4. instala `deploy/p69-camaras-y-accesos.service`;
5. ejecuta `systemctl daemon-reload` y `systemctl enable --now`.

Si el puerto `8080` ya esta ocupado por `rebar3 shell`, deten el shell de
desarrollo antes de instalar o cambia el puerto en `config/sys.config.prod`
y vuelve a construir el release.

## 3. Verificar

```bash
systemctl status p69-camaras-y-accesos
journalctl -u p69-camaras-y-accesos -f
curl -sS http://127.0.0.1:8080/api/salud
curl -sS http://127.0.0.1:8080/api/bitacora/verificar
```

Abrir la UI (desde la VM o desde Windows si es WSL2 con reenvio de puertos):

```text
http://localhost:8080/
http://localhost:8080/bitacora.html
http://localhost:8080/nodo.html
```

## 4. Datos y persistencia

- La bitacora vive en `/var/lib/p69-camaras-y-accesos/bitacora.wal`.
- El servicio corre como usuario `p69`.
- La unidad usa `StateDirectory` y `ProtectSystem=strict`; solo el directorio de
  datos es escribible.
- Para una demo con datos frescos, carga eventos con el simulador en la consola
  remota o mediante `POST /api/eventos`.

## 5. Actualizar el release

```bash
rebar3 as prod release
sudo scripts/instalar_servicio.sh
```

El script reemplaza solo `/opt/p69-camaras-y-accesos`; los datos en
`/var/lib/p69-camaras-y-accesos` se conservan.

## 6. Detener o desinstalar

```bash
sudo systemctl disable --now p69-camaras-y-accesos
sudo rm -f /etc/systemd/system/p69-camaras-y-accesos.service
sudo systemctl daemon-reload
sudo rm -rf /opt/p69-camaras-y-accesos
# Los datos NO se borran automaticamente:
# sudo rm -rf /var/lib/p69-camaras-y-accesos
```

## Nota de verificacion

El release se probo de forma real en esta maquina con un `sys.config`
temporal en el puerto `18081`: arranque, UI, `/api/salud`, `POST /api/eventos`,
WebSocket (`101 Switching Protocols`) y recuperacion del WAL tras reiniciar.
La instalacion systemd completa requiere `sudo` interactivo, que el agente no
puede ejecutar en este entorno; queda pendiente de verificacion en la VM.
