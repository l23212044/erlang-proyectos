#!/usr/bin/env bash
# Simulador del escenario: 100 puertas + 200 camaras, picos y fallas.
# Uso: scripts/simular.sh [--modo historico|carga|completo] [opciones]
# Opciones: --eventos N --horas H --dias-atras D --tasa N --pico N
#           --pico-cada-s N --pico-duracion-s N --duracion S --semilla N
#           --datos DIR --retencion D --puerto P --tasa N
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

if [ -d "$HOME/.local/opt/erlang-p69/bin" ]; then
  export PATH="$HOME/.local/opt/erlang-p69/bin:$HOME/.local/bin:$PATH"
fi

rebar3 compile >&2
exec erl -noshell -kernel logger_level critical -pa _build/default/lib/*/ebin -config config/sys \
  -eval 'p69_simulador:cli(init:get_plain_arguments())' -extra "$@"
