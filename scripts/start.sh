#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$APP_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "File .env non trovato in $APP_DIR" >&2
  exit 1
fi

cd "$APP_DIR"
mkdir -p "$APP_DIR/wireguard/config"

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

docker_compose() {
  if docker ps >/dev/null 2>&1; then
    docker compose "$@"
  else
    run_as_root docker compose "$@"
  fi
}

docker_compose pull
docker_compose up -d --force-recreate

echo
echo "VPN WireGuard avviata."
echo "Le configurazioni sono nel volume locale:"
echo "  wireguard/config/"
echo "Mostra il QR Android con:"
echo "  ./scripts/show-android-qr.sh android1"
