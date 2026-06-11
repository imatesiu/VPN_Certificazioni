#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
. "$SCRIPT_DIR/common.sh"

load_env
cd "$APP_DIR"

if [ ! -f data/conf/openvpn.conf ]; then
  echo "Configurazione OpenVPN non trovata. Esegui prima ./scripts/init.sh" >&2
  exit 1
fi

install_runtime_hooks
docker compose up -d --force-recreate

cat <<EOF

Server OpenVPN avviato.

Log:
  docker compose logs -f openvpn
EOF
