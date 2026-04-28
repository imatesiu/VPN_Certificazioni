#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$APP_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "File .env non trovato in $APP_DIR" >&2
  exit 1
fi

cd "$APP_DIR"

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

install_packages() {
  NEED_DOCKER=0

  if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    NEED_DOCKER=1
  fi

  if [ "$NEED_DOCKER" -eq 0 ]; then
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    run_as_root apt-get update
    run_as_root apt-get install -y docker.io docker-compose-plugin
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    run_as_root dnf install -y docker docker-compose-plugin
    return
  fi

  if command -v yum >/dev/null 2>&1; then
    run_as_root yum install -y docker docker-compose-plugin
    return
  fi

  echo "Package manager non supportato. Installa Docker e Docker Compose plugin manualmente." >&2
  exit 1
}

enable_docker() {
  if command -v systemctl >/dev/null 2>&1; then
    run_as_root systemctl enable --now docker
  fi
}

open_firewall() {
  SERVERPORT="$(grep '^SERVERPORT=' "$ENV_FILE" | cut -d= -f2-)"
  SERVERPORT="${SERVERPORT:-51820}"

  if command -v ufw >/dev/null 2>&1; then
    run_as_root ufw allow "${SERVERPORT}/udp"
    return
  fi

  if command -v firewall-cmd >/dev/null 2>&1; then
    run_as_root firewall-cmd --add-port="${SERVERPORT}/udp" --permanent
    run_as_root firewall-cmd --reload
    return
  fi

  echo "Firewall automatico non configurato: apri manualmente UDP ${SERVERPORT}."
}

install_packages
enable_docker
open_firewall
mkdir -p "$APP_DIR/wireguard/config"

echo
echo "Installazione completata."
echo "Avvia la VPN con:"
echo "  ./scripts/start.sh"
