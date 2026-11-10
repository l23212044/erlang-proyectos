#!/usr/bin/env bash
# Prueba de caos reproducible. Imprime Markdown con resultados medidos.
# Uso: scripts/caos.sh [--eventos N] [--semilla N] [--datos DIR]
# Para la entrega se recomienda --eventos 1000000 (carga millones de eventos).
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

if [ -d "$HOME/.local/opt/erlang-p69/bin" ]; then
  export PATH="$HOME/.local/opt/erlang-p69/bin:$HOME/.local/bin:$PATH"
fi

rebar3 compile >&2
exec erl -noshell -kernel logger_level critical -pa _build/default/lib/*/ebin -config config/sys \
  -eval 'p69_caos:cli(init:get_plain_arguments())' -extra "$@"
