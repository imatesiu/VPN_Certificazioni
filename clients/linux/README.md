# Linux

Installa WireGuard sul client Linux e usa il profilo reale generato dal container:

```text
wireguard/config/peer_linux1/peer_linux1.conf
```

Esempio di attivazione:

```bash
sudo cp wireguard/config/peer_linux1/peer_linux1.conf /etc/wireguard/sseapid.conf
sudo systemctl enable --now wg-quick@sseapid
```

Il file `sseapid-wireguard.conf` mostra la configurazione attesa, ma non contiene chiavi private reali.

