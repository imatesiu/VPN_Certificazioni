#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
. "$SCRIPT_DIR/common.sh"

load_env
cd "$APP_DIR"

mkdir -p data/conf clients generated

docker compose pull openvpn

if [ ! -f data/conf/openvpn.conf ]; then
  docker compose run --rm openvpn ovpn_genconfig \
    -u "${VPN_PROTO:-udp}://${VPN_SERVER_PUBLIC_HOST}:${VPN_PORT:-1194}" \
    -s "${VPN_SUBNET:-10.8.0.0/24}" \
    -p "route ${PUBLIC_SERVICE_IP} 255.255.255.255"
elif ! grep -q '10\.8\.0\.0 255\.255\.255\.0' data/conf/openvpn.conf; then
  cat >&2 <<EOF
ERRORE: data/conf/openvpn.conf esiste gia' ma non usa la subnet 10.8.0.0/24.

Questo succede quando la configurazione e' stata generata in precedenza con
un'altra subnet, per esempio il default kylemanna/openvpn 192.168.254.0/24.

Per rigenerare da zero:
  1. ferma il container: docker compose down
  2. salva eventuali profili/certificati che ti servono
  3. rimuovi o rinomina data/conf
  4. rilancia ./scripts/init.sh
EOF
  exit 1
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

if [ ! -f data/conf/pki/issued/pc2.crt ]; then
  docker compose run --rm -e EASYRSA_BATCH=1 openvpn easyrsa build-client-full pc2 nopass
fi

run_as_root mkdir -p data/conf/ccd

run_as_root rm -f data/conf/ccd/android1 data/conf/ccd/pc2

write_file data/conf/ccd/pc1 <<EOF
ifconfig-push ${PC_VPN_IP:-10.8.0.5} 255.255.255.0
iroute ${PC_LAN_IP} 255.255.255.255
EOF

install_runtime_hooks

delete_config_lines '/^ifconfig-pool /d'
add_config_line "topology subnet"
add_config_line "client-config-dir /etc/openvpn/ccd"
add_config_line "route ${PC_LAN_IP} 255.255.255.255"
add_config_line "script-security 2"
add_config_line "up /etc/openvpn/scripts/container-up.sh"
add_config_line "down /etc/openvpn/scripts/container-down.sh"

docker compose run --rm openvpn ovpn_getclient android1 | write_file clients/android1.ovpn
docker compose run --rm openvpn ovpn_getclient pc1 | write_file clients/pc1.ovpn
docker compose run --rm openvpn ovpn_getclient pc2 | write_file clients/pc2.ovpn
run_as_root chmod 600 clients/android1.ovpn clients/pc1.ovpn clients/pc2.ovpn

cat <<EOF

Inizializzazione OpenVPN completata.

Profili generati:
  $APP_DIR/clients/android1.ovpn
  $APP_DIR/clients/pc1.ovpn
  $APP_DIR/clients/pc2.ovpn

Avvia il server con:
  ./scripts/start.sh
EOF
