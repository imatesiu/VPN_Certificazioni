#!/usr/bin/env bash

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$APP_DIR/.env"

load_env() {
  if [ ! -f "$ENV_FILE" ]; then
    cp "$APP_DIR/.env.example" "$ENV_FILE"
    echo "Creato $ENV_FILE"
    echo "Verifica i valori in $ENV_FILE e riesegui lo script."
    exit 1
  fi

  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a

  : "${VPN_SERVER_PUBLIC_HOST:?Imposta VPN_SERVER_PUBLIC_HOST in VPN_v2/.env}"

  if [ "$VPN_SERVER_PUBLIC_HOST" = "$PUBLIC_SERVICE_IP" ]; then
    cat >&2 <<EOF
ERRORE: VPN_SERVER_PUBLIC_HOST coincide con PUBLIC_SERVICE_IP ($PUBLIC_SERVICE_IP).

Android non puo' usare lo stesso IP sia come endpoint OpenVPN sia come IP
applicativo da instradare nel tunnel. Serve un secondo IP pubblico/DDNS
per il server VPN oppure un altro server pubblico raggiungibile.
EOF
    exit 1
  fi
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

write_file() {
  local target_file="$1"
  if [ "$(id -u)" -eq 0 ]; then
    tee "$target_file" >/dev/null
  else
    sudo tee "$target_file" >/dev/null
  fi
}

append_file() {
  local target_file="$1"
  if [ "$(id -u)" -eq 0 ]; then
    tee -a "$target_file" >/dev/null
  else
    sudo tee -a "$target_file" >/dev/null
  fi
}

delete_config_lines() {
  local expression="$1"
  if [ "$(id -u)" -eq 0 ]; then
    sed -i.bak -E "$expression" "$APP_DIR/data/conf/openvpn.conf"
  else
    sudo sed -i.bak -E "$expression" "$APP_DIR/data/conf/openvpn.conf"
  fi
}

add_config_line() {
  local line="$1"
  grep -qxF "$line" "$APP_DIR/data/conf/openvpn.conf" || printf '%s\n' "$line" | append_file "$APP_DIR/data/conf/openvpn.conf"
}

install_runtime_hooks() {
  cd "$APP_DIR"
  run_as_root mkdir -p data/conf/scripts
  run_as_root cp scripts/container-up.sh data/conf/scripts/container-up.sh
  run_as_root cp scripts/container-down.sh data/conf/scripts/container-down.sh
  run_as_root chmod +x data/conf/scripts/container-up.sh data/conf/scripts/container-down.sh
}
