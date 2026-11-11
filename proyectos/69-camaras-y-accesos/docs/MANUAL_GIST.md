# Manual de uso — Sentinel Urbano (#69 Camaras y accesos)

Sistema de bitacora de eventos de camaras y controles de acceso. Permite
recibir eventos, buscarlos por rango de tiempo y filtros, ver el estado de los
nodos en tiempo real y verificar que la bitacora no fue alterada.

> Este documento esta pensado para publicarse como Gist. Las capturas de la app
> real estan enlazadas desde la carpeta `Evidencias/`.

## 1. Que hace el sistema

- Ingesta eventos: `movimiento`, `alarma`, `puerta_abierta`, `tarjeta_leida`,
  `online`, `offline`.
- Organiza cada evento por dispositivo, edificio, tipo, persona y tiempo.
- Corrige el reloj de dispositivos desfasados.
- Busca por rango de tiempo y filtros sin recorrer toda la bitacora.
- Aplica retencion por dias y conserva la verificacion de integridad.
- Muestra dashboard, bitacora y detalle de nodo en el navegador.
- Expone REST, WebSocket y metricas.

## 2. Requisitos

- Ubuntu con systemd (para el servicio) o cualquier Linux/Windows con WSL2.
- Erlang/OTP 27+ y rebar3 si se ejecuta desde fuente.
- Navegador moderno.

## 3. Instalacion en la VM

```bash
git clone https://github.com/l23212044/erlang-proyectos.git
cd erlang-proyectos/proyectos/69-camaras-y-accesos
export PATH="$HOME/.local/opt/erlang-p69/bin:$HOME/.local/bin:$PATH"
rebar3 compile
rebar3 eunit
rebar3 as prod release
```

Si Erlang/rebar3 no estan instalados:

```bash
sudo apt-get update
sudo apt-get install -y erlang rebar3
```

Para dejarlo como servicio:

```bash
sudo scripts/instalar_servicio.sh
```

El servicio se llama `p69-camaras-y-accesos` y guarda los datos en
`/var/lib/p69-camaras-y-accesos`.

## 4. Iniciar y detener

Servicio systemd:

```bash
sudo systemctl start p69-camaras-y-accesos
sudo systemctl stop p69-camaras-y-accesos
sudo systemctl restart p69-camaras-y-accesos
systemctl status p69-camaras-y-accesos
journalctl -u p69-camaras-y-accesos -f
```

Modo desarrollo:

```bash
rebar3 shell
```

El puerto por defecto es `8080`.

## 5. Acceso a la interfaz

- Dashboard: <http://localhost:8080/>
- Bitacora: <http://localhost:8080/bitacora.html>
- Detalle de nodo: <http://localhost:8080/nodo.html>

Si la VM es WSL2, abre esas direcciones desde el navegador de Windows.

Evidencias de la app real (release y UI):

- Indice: <https://github.com/l23212044/erlang-proyectos/blob/main/proyectos/69-camaras-y-accesos/Evidencias/README.md>
- Capturas: <https://github.com/l23212044/erlang-proyectos/tree/main/proyectos/69-camaras-y-accesos/Evidencias/capturas>

![Captura de la app 1](https://github.com/user-attachments/assets/13f97931-a7f3-4fe3-a14a-3ff24e49d889)

![Captura de la app 2](https://github.com/user-attachments/assets/a65ea5cc-4939-4e0b-b1eb-d293eea4ded1)

## 6. Recorrido de la UI

### Dashboard

- KPIs de nodos operativos, en alerta y en falla.
- Estado de conexion WebSocket y latencia del ping.
- Tarjetas de nodos: ultimo latido, offset de reloj, eventos y acceso al detalle.
- Eventos recientes de la ultima hora.

### Bitacora

- Presets de rango: 15 min, 1 h, 8 h, hoy.
- Rango personalizado con fecha y hora.
- Filtros por severidad (`ok`, `alerta`, `critico`) y por tipo.
- Busqueda por dispositivo, edificio, tipo, persona o hash.
- Exportacion CSV y copia del hash de cada evento.
- Indicador de integridad SHA-256.

### Detalle de nodo

- Estado, ultimo latido, offset y contador de eventos.
- Eventos de las ultimas 24 horas.
- Boton para verificar la cadena.
- Los controles fisicos/PTZ aparecen deshabilitados con aviso: esta demo no
  expone esa API.

## 7. Ejemplos de API

Salud:

```bash
curl -sS http://localhost:8080/api/salud
```

Alta de un evento (usa una marca de tiempo reciente):

```bash
TS=$(($(date +%s) * 1000000))
curl -sS -X POST http://localhost:8080/api/eventos \
  -H 'content-type: application/json' \
  -d "{\"dispositivo_id\":\"camara-101\",\"tipo_dispositivo\":\"camara\",\"edificio\":\"A\",\"tipo_evento\":\"movimiento\",\"ts_evento\":$TS,\"ts_recepcion\":$TS}"
```

Busqueda por rango:

```bash
curl -sS "http://localhost:8080/api/eventos?desde=2026-11-10T00:00:00Z&hasta=2026-11-10T23:59:59Z&edificio=A&limite=50"
```

Dispositivos y alertas:

```bash
curl -sS "http://localhost:8080/api/dispositivos?edificio=A"
curl -sS http://localhost:8080/api/alertas
```

Verificacion de integridad:

```bash
curl -sS http://localhost:8080/api/bitacora/verificar
```

Metricas:

```bash
curl -sS http://localhost:8080/metrics
```

WebSocket: conectar a `ws://localhost:8080/ws/eventos`; envia un resumen
periodico y cada evento nuevo. El cliente puede enviar `ping` y recibe `pong`.

## 8. Colores y estados

- **OK / verde**: el nodo reporta latido reciente y sin alarmas.
- **ALERTA / ambar**: alarma o reloj desfasado.
- **FALLA / rojo**: sin latido dentro de `dispositivo_timeout_seg` (120 s).
- **ACTIVIDAD**: evento informativo (movimiento, acceso, puerta abierta).

## 9. Retencion

Por defecto se conservan 30 dias (`retencion_dias`). Los segmentos vencidos se
borran sin cortar consultas en curso; cada borrado queda registrado como
checkpoint y la verificacion sigue siendo valida.

## 10. Solucion de problemas

### El puerto 8080 esta ocupado

```bash
ss -ltnp | grep :8080
```

Deten el `rebar3 shell` o el servicio anterior, o cambia `puerto` en
`config/sys.config` (desarrollo) / `config/sys.config.prod` (produccion) y
reconstruye el release.

### systemd no arranca en WSL2

Comprueba que systemd esta habilitado en `/etc/wsl.conf`:

```ini
[boot]
systemd=true
```

Luego reinicia WSL desde Windows con `wsl --shutdown` y vuelve a entrar.

### El servicio arranca pero la UI no carga

```bash
systemctl status p69-camaras-y-accesos
journalctl -u p69-camaras-y-accesos -n 100
curl -sS http://127.0.0.1:8080/api/salud
```

### Los dispositivos aparecen en falla

Los eventos historicos muy antiguos no cuentan como latido reciente. Carga
eventos nuevos con el simulador o por `POST /api/eventos`.

### Error `fuera_de_retencion`

El evento es mas antiguo que la retencion configurada. Usa una marca de tiempo
reciente o ajusta `retencion_dias`.

### Cookie o nodo de Erlang

El release usa la cookie de `config/vm.args`. No la cambies entre arranques si
necesitas `remote_console`; para produccion genera una nueva antes de desplegar.

## 11. Capturas y evidencias

La evidencia completa esta en `Evidencias/README.md`:

- Capturas locales: `Evidencias/capturas/dashboard.png`,
  `Evidencias/capturas/bitacora.png`,
  `Evidencias/capturas/bitacora-camara-017.png` y
  `Evidencias/capturas/nodo-camara-017.png`.
- Pruebas de compilacion y eunit: `Evidencias/pruebas/eunit.txt` (51 pruebas,
  0 fallos).
- Respuestas reales de API: `Evidencias/pruebas/api.md`.
- Prueba de caos: `docs/CAOS.md`.

Las capturas se tomaron del release real con `scripts/demo.sh --limpiar`. El
detalle de `camara-017` muestra el reloj desfasado 240 s inyectado por el
simulador. Las pantallas originales de Google Stitch estan en
`design/stitch_sistema_de_seguridad_ciudadana/`.
