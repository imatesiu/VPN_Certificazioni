#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$APP_DIR/.env"

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

cd "$APP_DIR"

mkdir -p data/conf clients generated

docker compose pull openvpn

if [ ! -f data/conf/openvpn.conf ]; then
  docker compose run --rm openvpn ovpn_genconfig \
    -u "${VPN_PROTO:-udp}://${VPN_SERVER_PUBLIC_HOST}:${VPN_PORT:-1194}" \
    -s "${VPN_SUBNET:-10.84.0.0/24}" \
    -p "route ${PUBLIC_SERVICE_IP} 255.255.255.255"
fi

if [ ! -f data/conf/pki/ca.crt ]; then
  docker compose run --rm -e EASYRSA_BATCH=1 openvpn ovpn_initpki nopass
fi

if [ ! -f data/conf/pki/issued/android1.crt ]; then
  docker compose run --rm -e EASYRSA_BATCH=1 openvpn easyrsa build-client-full android1 nopass
fi

if [ ! -f data/conf/pki/issued/pc1.crt ]; then
  docker compose run --rm -e EASYRSA_BATCH=1 openvpn easyrsa build-client-full pc1 nopass
fi

mkdir -p data/conf/ccd data/conf/scripts

cat > data/conf/ccd/android1 <<EOF
ifconfig-push ${ANDROID_VPN_IP:-10.84.0.2} 255.255.255.0
push "route ${PUBLIC_SERVICE_IP} 255.255.255.255"
EOF

cat > data/conf/ccd/pc1 <<EOF
ifconfig-push ${PC_VPN_IP:-10.84.0.10} 255.255.255.0
iroute ${PC_LAN_IP} 255.255.255.255
EOF

cp scripts/container-up.sh data/conf/scripts/container-up.sh
cp scripts/container-down.sh data/conf/scripts/container-down.sh
chmod +x data/conf/scripts/container-up.sh data/conf/scripts/container-down.sh

add_config_line() {
  local line="$1"
  grep -qxF "$line" data/conf/openvpn.conf || printf '%s\n' "$line" >> data/conf/openvpn.conf
}

add_config_line "topology subnet"
add_config_line "client-config-dir /etc/openvpn/ccd"
add_config_line "route ${PC_LAN_IP} 255.255.255.255"
add_config_line "script-security 2"
add_config_line "up /etc/openvpn/scripts/container-up.sh"
add_config_line "down /etc/openvpn/scripts/container-down.sh"

docker compose run --rm openvpn ovpn_getclient android1 > clients/android1.ovpn
docker compose run --rm openvpn ovpn_getclient pc1 > clients/pc1.ovpn
chmod 600 clients/android1.ovpn clients/pc1.ovpn

docker compose up -d

cat <<EOF

Server OpenVPN avviato.

Profili generati:
  $APP_DIR/clients/android1.ovpn
  $APP_DIR/clients/pc1.ovpn

Installa pc1.ovpn sul PC 192.168.1.146 e android1.ovpn sul terminale Android.
EOF
