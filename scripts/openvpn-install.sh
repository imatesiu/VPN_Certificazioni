#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$APP_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "File .env non trovato in $APP_DIR" >&2
  exit 1
fi

cd "$APP_DIR"

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

OPENVPN_SERVER="${OPENVPN_SERVER:-sseapid.isti.cnr.it}"
OPENVPN_PORT="${OPENVPN_PORT:-1194}"
OPENVPN_SUBNET="${OPENVPN_SUBNET:-10.9.0.0/24}"
OPENVPN_DNS="${OPENVPN_DNS:-10.9.0.5}"
OPENVPN_POOL_START="${OPENVPN_POOL_START:-10.9.0.10}"
OPENVPN_POOL_END="${OPENVPN_POOL_END:-10.9.0.254}"
OPENVPN_CLIENTS="${OPENVPN_CLIENTS:-client1,dns1}"

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

ensure_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    run_as_root apt-get update
    run_as_root apt-get install -y docker.io docker-compose-plugin
  elif command -v dnf >/dev/null 2>&1; then
    run_as_root dnf install -y docker docker-compose-plugin
  elif command -v yum >/dev/null 2>&1; then
    run_as_root yum install -y docker docker-compose-plugin
  else
    echo "Package manager non supportato. Installa Docker e Docker Compose plugin manualmente." >&2
    exit 1
  fi

  if command -v systemctl >/dev/null 2>&1; then
    run_as_root systemctl enable --now docker
  fi
}

open_firewall() {
  if command -v ufw >/dev/null 2>&1; then
    run_as_root ufw allow "${OPENVPN_PORT}/udp"
    return
  fi

  if command -v firewall-cmd >/dev/null 2>&1; then
    run_as_root firewall-cmd --add-port="${OPENVPN_PORT}/udp" --permanent
    run_as_root firewall-cmd --reload
    return
  fi

  echo "Firewall automatico non configurato: apri manualmente UDP ${OPENVPN_PORT}."
}

ensure_openvpn_config() {
  mkdir -p "$APP_DIR/openvpn-data/conf" "$APP_DIR/clients/openvpn/generated"
  docker_compose pull openvpn

  if [ -f "$APP_DIR/openvpn-data/conf/openvpn.conf" ]; then
    echo "Configurazione OpenVPN gia' presente: openvpn-data/conf/openvpn.conf"
  else
    docker_compose run --rm openvpn ovpn_genconfig \
      -u "udp://${OPENVPN_SERVER}:${OPENVPN_PORT}" \
      -s "${OPENVPN_SUBNET}" \
      -p "redirect-gateway def1 bypass-dhcp" \
      -p "dhcp-option DNS ${OPENVPN_DNS}"
  fi

  if [ ! -f "$APP_DIR/openvpn-data/conf/pki/ca.crt" ]; then
    docker_compose run --rm -e EASYRSA_BATCH=1 openvpn ovpn_initpki nopass
  fi

  mkdir -p "$APP_DIR/openvpn-data/conf/ccd"
  printf 'ifconfig-push %s 255.255.255.0\n' "$OPENVPN_DNS" > "$APP_DIR/openvpn-data/conf/ccd/dns1"

  if ! grep -q '^client-config-dir /etc/openvpn/ccd' "$APP_DIR/openvpn-data/conf/openvpn.conf"; then
    printf '\nclient-config-dir /etc/openvpn/ccd\n' >> "$APP_DIR/openvpn-data/conf/openvpn.conf"
  fi

  if ! grep -q '^ifconfig-pool ' "$APP_DIR/openvpn-data/conf/openvpn.conf"; then
    printf 'ifconfig-pool %s %s 255.255.255.0\n' "$OPENVPN_POOL_START" "$OPENVPN_POOL_END" >> "$APP_DIR/openvpn-data/conf/openvpn.conf"
  fi
}

generate_client() {
  CLIENT_NAME="$1"
  CLIENT_CERT="$APP_DIR/openvpn-data/conf/pki/issued/${CLIENT_NAME}.crt"
  CLIENT_PROFILE="$APP_DIR/clients/openvpn/generated/${CLIENT_NAME}.ovpn"

  case "$CLIENT_NAME" in
    *[!A-Za-z0-9_-]*)
      echo "Nome client OpenVPN non valido: $CLIENT_NAME" >&2
      exit 1
      ;;
  esac

  if [ ! -f "$CLIENT_CERT" ]; then
    docker_compose run --rm -e EASYRSA_BATCH=1 openvpn easyrsa build-client-full "$CLIENT_NAME" nopass
  fi

  docker_compose run --rm openvpn ovpn_getclient "$CLIENT_NAME" > "$CLIENT_PROFILE"
  chmod 600 "$CLIENT_PROFILE"
  echo "Profilo client generato: $CLIENT_PROFILE"
}

generate_clients() {
  OLD_IFS="$IFS"
  IFS=','
  for RAW_CLIENT in $OPENVPN_CLIENTS; do
    CLIENT_NAME="$(printf '%s' "$RAW_CLIENT" | tr -d '[:space:]')"
    [ -z "$CLIENT_NAME" ] && continue
    generate_client "$CLIENT_NAME"
  done
  IFS="$OLD_IFS"
}

ensure_docker
open_firewall
ensure_openvpn_config
generate_clients
docker_compose up -d openvpn

echo
echo "Server OpenVPN Docker avviato."
echo "Endpoint: ${OPENVPN_SERVER}:${OPENVPN_PORT}/udp"
echo "Profili client in: clients/openvpn/generated/"
