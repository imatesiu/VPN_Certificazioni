# Configurazioni WireGuard

I file reali vengono generati dal container WireGuard quando avvii:

```bash
./scripts/start.sh
```

Percorsi generati:

- `wireguard/config/wg_confs/wg0.conf`: configurazione server usata dal container.
- `wireguard/config/peer_android1/peer_android1.conf`: profilo Android.
- `wireguard/config/peer_android1/peer_android1.png`: QR code Android generato dal container.

Configurazioni versionate:

- `wireguard/wg0.conf`: struttura reale della configurazione server WireGuard.
- `wireguard/android-client.conf`: struttura reale del profilo Android.

I file dentro `wireguard/config/` contengono chiavi private e sono esclusi da Git.
