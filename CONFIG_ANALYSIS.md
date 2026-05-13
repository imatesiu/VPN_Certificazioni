# Analisi configurazione VPN

## Stato attuale

La configurazione server attuale e' basata su WireGuard in Docker:

- servizio: `wireguard` in `docker-compose.yml`
- immagine: `lscr.io/linuxserver/wireguard:latest`
- porta pubblica: UDP `51820`
- dominio pubblico: `sseapid.isti.cnr.it`
- subnet VPN: `192.168.4.0/24`
- IP WireGuard del server: `192.168.4.1`

## Client WireGuard

I peer configurati in `.env` sono:

```text
android1,android2,android3,macos1,windows1,linux1
```

Con questa configurazione gli IP attesi sono:

```text
android1  -> 192.168.4.150
android2  -> 192.168.4.151
android3  -> 192.168.4.152
macos1    -> 192.168.4.146
windows1  -> 192.168.4.154
linux1    -> 192.168.4.155
```

Il DNS consegnato ai client e':

```text
192.168.4.146
```

Quindi `macos1` deve essere davvero il resolver DNS locale, oppure l'indirizzo `192.168.4.146` va riservato a un servizio DNS dedicato.

## Routing

I profili client usano full tunnel:

```text
AllowedIPs = 0.0.0.0/0, ::/0
```

Questo instrada tutto il traffico client nella VPN.

## OpenVPN

E' stato aggiunto un profilo client OpenVPN in:

```text
clients/openvpn/sseapid-client.ovpn
```

E' stata aggiunta una configurazione server OpenVPN Docker:

```text
docker-compose.yml
scripts/openvpn-install.sh
openvpn/INSTALL_DOCKER.md
```

Il volume locale con PKI e configurazione generate e':

```text
openvpn-data/conf/
```

I profili client generati finiscono in:

```text
clients/openvpn/generated/
```

E' disponibile anche una configurazione server OpenVPN nativa per Ubuntu:

```text
openvpn/server.conf
openvpn/INSTALL_UBUNTU.md
```

La rete OpenVPN proposta e':

```text
192.168.4.0/24
```

Il DNS OpenVPN configurato e':

```text
192.168.4.146
```

L'indirizzo `192.168.4.146` e' riservato al client/servizio `dns1` tramite:

```text
openvpn/ccd/dns1
```

Il compose ora contiene sia WireGuard sia OpenVPN. OpenVPN puo' essere inizializzato con `./scripts/openvpn-install.sh`.

WireGuard e OpenVPN possono convivere:

```text
WireGuard: 51820/udp
OpenVPN:   1194/udp
```
