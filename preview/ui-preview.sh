#!/usr/bin/env bash
# Preview de la UI del instalador (no instala nada).
#   Envoltorio fino sobre la capa real: lib/ui.sh.
#   Lo que veas aquí es EXACTAMENTE lo que verás en el instalador.
#   Equivale a:  setup_master.sh --preview
set -uo pipefail
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_here/../lib/ui.sh"
export HORUS_UI_PREVIEW=1
HORUS_SDBOOT=1; bootctl is-installed &>/dev/null || HORUS_SDBOOT=0
horus_wizard
