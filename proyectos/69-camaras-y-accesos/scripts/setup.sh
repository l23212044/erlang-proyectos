#!/usr/bin/env bash
# Deja la maquina lista para compilar, probar y generar el release.
# Es idempotente: se puede ejecutar cuantas veces haga falta.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

log() { printf '[setup] %s\n' "$*"; }

if ! command -v erl >/dev/null 2>&1 || ! command -v rebar3 >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    log "Erlang/rebar3 no encontrados; instalando con apt (requiere sudo)"
    sudo apt-get update
    sudo apt-get install -y erlang rebar3
  else
    log "ERROR: instala Erlang/OTP 27+ y rebar3 manualmente y vuelve a ejecutar"
    exit 1
  fi
fi

log "OTP: $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().') / rebar3: $(rebar3 version | head -1)"

log "Compilando"
rebar3 compile

log "Ejecutando pruebas"
rebar3 eunit

log "Generando release de produccion"
rebar3 as prod release

log "Listo. Arranque manual: _build/prod/rel/p69_camaras_y_accesos/bin/p69_camaras_y_accesos foreground"
