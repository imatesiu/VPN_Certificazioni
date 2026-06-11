#!/usr/bin/env bash
set -euo pipefail

sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.rp_filter=0
sysctl -w net.ipv4.conf.default.rp_filter=0

echo "PC pronto a ricevere traffico VPN verso 192.168.1.146."
echo "Avvia il client OpenVPN con il profilo VPN_v2/clients/pc1.ovpn."
