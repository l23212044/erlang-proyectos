#!/usr/bin/env bash
# Prepara una demo reproducible usando el release de produccion sin systemd.
# Uso:
#   scripts/demo.sh [--limpiar] [--puerto N] [--sin-carga]
#   scripts/demo.sh --detener
set -euo pipefail

SERVICIO="p69-camaras-y-accesos"
APP="p69_camaras_y_accesos"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE="${RAIZ}/_build/prod/rel/${APP}"
BIN="${RELEASE}/bin/${APP}"
PUERTO="${P69_DEMO_PUERTO:-8080}"
DATOS="${P69_DEMO_DATOS:-/tmp/p69-demo}"
CONFIG="/tmp/p69-demo-sys.config"
LOG="/tmp/p69-demo.log"
LIMPIAR=0
CARGA=1

while [ $# -gt 0 ]; do
  case "$1" in
    --limpiar) LIMPIAR=1 ;;
    --sin-carga) CARGA=0 ;;
    --puerto) PUERTO="$2"; shift ;;
    --detener)
      if [ -x "$BIN" ]; then
        "$BIN" stop >/dev/null 2>&1 || true
      fi
      echo "Demo detenida."
      exit 0
      ;;
    *) echo "Opcion desconocida: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ ! -x "$BIN" ]; then
  echo "ERROR: no existe el release. Construyelo antes:" >&2
  echo "  rebar3 as prod release" >&2
  exit 1
fi

if curl -sS --max-time 1 "http://127.0.0.1:${PUERTO}/api/salud" >/dev/null 2>&1; then
  echo "ERROR: el puerto ${PUERTO} ya tiene la app corriendo." >&2
  exit 1
fi

if [ "$LIMPIAR" = "1" ]; then
  case "$DATOS" in
    /tmp/*) rm -rf "$DATOS" ;;
    *) echo "ERROR: --limpiar solo borra rutas bajo /tmp (${DATOS})." >&2; exit 1 ;;
  esac
fi

cat >"$CONFIG" <<EOF
[
  {p69_camaras_y_accesos, [
    {puerto, ${PUERTO}},
    {interfaz, {0, 0, 0, 0}},
    {num_aceptores, 50},
    {datos_dir, "${DATOS}"},
    {retencion_dias, 30},
    {retencion_intervalo_seg, 3600},
    {segmento_segundos, 86400},
    {ingesta_max_cola, 100000},
    {ingesta_umbral_429, 80000},
    {umbral_reloj_seg, 60},
    {reloj_max_muestras, 15},
    {dispositivo_timeout_seg, 120}
  ]},
  {kernel, [{logger_level, info}]}
].
EOF

setsid bash -c "exec '${BIN}' foreground -config '${CONFIG}'" >"$LOG" 2>&1 </dev/null &
disown

echo "Esperando a que la app responda en el puerto ${PUERTO}..."
for _ in $(seq 1 30); do
  if curl -sS --max-time 1 "http://127.0.0.1:${PUERTO}/api/salud" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -sS --max-time 2 "http://127.0.0.1:${PUERTO}/api/salud" >/dev/null 2>&1; then
  echo "ERROR: la app no respondio. Revisa ${LOG}." >&2
  exit 1
fi

if [ "$CARGA" = "1" ]; then
  echo "Cargando historico reciente (5,000 eventos de la ultima hora)..."
  "$BIN" rpc p69_simulador historico \
    "[#{eventos => 5000, horas => 1, dias_atras => 0, lote => 500}]."
  echo "Arrancando flujo en vivo (5 minutos, picos de 200 ev/s)..."
  "$BIN" rpc p69_simulador carga \
    "[#{duracion_s => 300, tasa => 30, pico => 200, pico_cada_s => 30, pico_duracion_s => 5}]."
fi

echo
echo "Demo lista:"
echo "  Dashboard : http://localhost:${PUERTO}/"
echo "  Bitacora  : http://localhost:${PUERTO}/bitacora.html"
echo "  Nodo      : http://localhost:${PUERTO}/nodo.html"
echo "  Salud     : http://localhost:${PUERTO}/api/salud"
echo "  Log       : ${LOG}"
echo "  Datos     : ${DATOS}"
echo
echo "Detener con: scripts/demo.sh --detener --puerto ${PUERTO}"
