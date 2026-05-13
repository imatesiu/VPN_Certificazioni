# Client WireGuard

Questa directory contiene configurazioni client WireGuard leggibili per macOS, Windows e Linux.

Contiene anche un profilo client OpenVPN in:

```text
clients/openvpn/sseapid-client.ovpn
```

Il profilo OpenVPN e' solo client: la configurazione server attuale resta WireGuard in Docker.

I file in questa directory non contengono chiavi private reali. Le configurazioni operative con chiavi vere vengono generate dal container in:

```text
wireguard/config/peer_<nome_peer>/peer_<nome_peer>.conf
```

Peer configurati in `.env`:

- `macos1`
- `windows1`
- `linux1`

Dopo aver avviato il servizio con:

```bash
./scripts/start.sh
```

troverai i profili reali qui:

```text
wireguard/config/peer_macos1/peer_macos1.conf
wireguard/config/peer_windows1/peer_windows1.conf
wireguard/config/peer_linux1/peer_linux1.conf
```

Per aggiungere altri client desktop, aggiungi il nome in `PEERS` dentro `.env`, poi rilancia:

```bash
./scripts/start.sh
```
