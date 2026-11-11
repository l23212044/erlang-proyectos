#!/usr/bin/env bash
# Instala el release de produccion y el servicio systemd.
# Uso: sudo scripts/instalar_servicio.sh
# Requiere haber construido el release: rebar3 as prod release
set -euo pipefail

SERVICIO="p69-camaras-y-accesos"
APP="p69_camaras_y_accesos"
DESTINO="/opt/${SERVICIO}"
DATOS="/var/lib/${SERVICIO}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE="${RAIZ}/_build/prod/rel/${APP}"
UNIDAD="${RAIZ}/deploy/${SERVICIO}.service"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: ejecuta este script con sudo." >&2
  exit 1
fi

if [ ! -x "${RELEASE}/bin/${APP}" ]; then
  echo "ERROR: no existe el release. Ejecuta antes:" >&2
  echo "  rebar3 as prod release" >&2
  exit 1
fi

if ! id p69 >/dev/null 2>&1; then
  useradd --system --home "${DATOS}" --shell /usr/sbin/nologin p69
fi

install -d -m 0750 -o p69 -g p69 "${DATOS}"

if [ "${DESTINO}" != "/opt/${SERVICIO}" ]; then
  echo "ERROR: ruta destino inesperada: ${DESTINO}" >&2
  exit 1
fi
rm -rf "${DESTINO}"
cp -a "${RELEASE}" "${DESTINO}"
chown -R root:root "${DESTINO}"

install -m 0644 "${UNIDAD}" "/etc/systemd/system/${SERVICIO}.service"
systemctl daemon-reload
systemctl enable --now "${SERVICIO}.service"
systemctl --no-pager --full status "${SERVICIO}.service" || true

echo
echo "Servicio instalado. Prueba:"
echo "  curl -sS http://127.0.0.1:8080/api/salud"
echo "  journalctl -u ${SERVICIO} -f"
