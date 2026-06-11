#!/bin/sh
set -eu

VPN_IF="${dev:-tun0}"
PUBLIC_SERVICE_IP="${PUBLIC_SERVICE_IP:-146.48.84.211}"
PC_LAN_IP="${PC_LAN_IP:-192.168.1.146}"

sysctl -w net.ipv4.ip_forward=1 >/dev/null

iptables -t nat -C PREROUTING -i "$VPN_IF" -d "$PUBLIC_SERVICE_IP" -j DNAT --to-destination "$PC_LAN_IP" 2>/dev/null || \
  iptables -t nat -A PREROUTING -i "$VPN_IF" -d "$PUBLIC_SERVICE_IP" -j DNAT --to-destination "$PC_LAN_IP"

iptables -C FORWARD -i "$VPN_IF" -d "$PC_LAN_IP" -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i "$VPN_IF" -d "$PC_LAN_IP" -j ACCEPT

iptables -C FORWARD -o "$VPN_IF" -s "$PC_LAN_IP" -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -o "$VPN_IF" -s "$PC_LAN_IP" -j ACCEPT
