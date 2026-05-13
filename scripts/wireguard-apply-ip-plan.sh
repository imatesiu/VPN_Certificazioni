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

WIREGUARD_SERVER_IP="${WIREGUARD_SERVER_IP:-192.168.4.1}"
WIREGUARD_PEER_IPS="${WIREGUARD_PEER_IPS:-dns1=192.168.4.146,android1=192.168.4.150,android2=192.168.4.151,android3=192.168.4.152,macos1=192.168.4.153,windows1=192.168.4.154,linux1=192.168.4.155}"
PEERDNS="${PEERDNS:-192.168.4.146}"

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

WG_SERVER_CONF="$APP_DIR/wireguard/config/wg_confs/wg0.conf"

if [ ! -f "$WG_SERVER_CONF" ]; then
  echo "Configurazione WireGuard non ancora generata: $WG_SERVER_CONF" >&2
  echo "Avvia prima il container WireGuard almeno una volta." >&2
  exit 1
fi

run_as_root sed -i.bak -E "s#^Address = .*#Address = ${WIREGUARD_SERVER_IP}/24#" "$WG_SERVER_CONF"

OLD_IFS="$IFS"
IFS=','
for ENTRY in $WIREGUARD_PEER_IPS; do
  PEER_NAME="${ENTRY%%=*}"
  PEER_IP="${ENTRY#*=}"
  PEER_NAME="$(printf '%s' "$PEER_NAME" | tr -d '[:space:]')"
  PEER_IP="$(printf '%s' "$PEER_IP" | tr -d '[:space:]')"

  [ -z "$PEER_NAME" ] && continue
  [ -z "$PEER_IP" ] && continue

  case "$PEER_NAME" in
    *[!A-Za-z0-9_-]*)
      echo "Nome peer WireGuard non valido: $PEER_NAME" >&2
      exit 1
      ;;
  esac

  PEER_CONF="$APP_DIR/wireguard/config/peer_${PEER_NAME}/peer_${PEER_NAME}.conf"

  if [ -f "$PEER_CONF" ]; then
    run_as_root sed -i.bak -E "s#^Address = .*#Address = ${PEER_IP}/32#" "$PEER_CONF"
    if grep -q '^DNS = ' "$PEER_CONF"; then
      run_as_root sed -i.bak -E "s#^DNS = .*#DNS = ${PEERDNS}#" "$PEER_CONF"
    else
      printf 'DNS = %s\n' "$PEERDNS" | run_as_root tee -a "$PEER_CONF" >/dev/null
    fi
  else
    echo "Profilo peer non trovato, salto: $PEER_CONF"
  fi

  run_as_root perl -0pi.bak -e "s/(# peer_${PEER_NAME}\\n(?:[^\\n]*\\n){0,6}?AllowedIPs = )[^\\n]+/\${1}${PEER_IP}\\/32/g" "$WG_SERVER_CONF"
done
IFS="$OLD_IFS"

echo "Piano IP WireGuard applicato a wireguard/config/."
