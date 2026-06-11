#!/bin/sh
set -eu

VPN_IF="${dev:-tun0}"
PUBLIC_SERVICE_IP="${PUBLIC_SERVICE_IP:-146.48.84.211}"
PC_VPN_IP="${PC_VPN_IP:-10.8.0.5}"

iptables -t nat -D PREROUTING -i "$VPN_IF" -d "$PUBLIC_SERVICE_IP" -j DNAT --to-destination "$PC_VPN_IP" 2>/dev/null || true
iptables -D FORWARD -i "$VPN_IF" -d "$PC_VPN_IP" -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -o "$VPN_IF" -s "$PC_VPN_IP" -j ACCEPT 2>/dev/null || true
