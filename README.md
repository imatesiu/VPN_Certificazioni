# VPN server sseapid.isti.cnr.it

Configurazione reale per creare un servizio VPN WireGuard su `sseapid.isti.cnr.it`. WireGuard e' la scelta piu' semplice per dispositivi Android perche' i profili si importano tramite QR code.

Il certificato Let's Encrypt eventualmente gia' presente a bordo non serve a WireGuard, perche' WireGuard non usa TLS: usa chiavi pubbliche/private proprie. Il certificato resta utile per servizi HTTPS sulla stessa macchina o per un eventuale portale di distribuzione profili, ma non entra nella configurazione VPN WireGuard.

## Struttura

- `docker-compose.yml`: servizio WireGuard pronto per Docker.
- `.env`: configurazione reale del servizio.
- `wireguard/wg0.conf`: configurazione server WireGuard, senza chiavi private hardcoded.
- `wireguard/android-client.conf`: configurazione Android WireGuard, senza chiavi private hardcoded.
- `clients/`: configurazioni client per macOS, Windows e Linux, senza chiavi private hardcoded.
- `scripts/install.sh`: installa i pacchetti necessari e prepara firewall/directory.
- `scripts/start.sh`: scarica l'immagine WireGuard e avvia il servizio containerizzato.
- `scripts/show-android-qr.sh`: mostra a terminale il QR code di un profilo Android generato.

## Installazione e avvio

La configurazione reale e' gia' in `.env`:

```dotenv
SERVERURL=sseapid.isti.cnr.it
SERVERPORT=51820
PEERS=android1,android2,android3,macos1,windows1,linux1
PEERDNS=10.8.0.1
```

Sul server esegui prima l'installazione:

```bash
./scripts/install.sh
```

Lo script installa solo Docker e Docker Compose plugin se mancanti, abilita Docker e apre UDP `51820` se trova `ufw` o `firewalld`.

Poi avvia la VPN:

```bash
./scripts/start.sh
```

Lo script di avvio scarica l'immagine WireGuard e avvia il servizio. La generazione delle configurazioni reali avviene dentro il container e viene salvata nel volume locale `wireguard/config/`.

Se la macchina e' dietro NAT o firewall perimetrale, inoltra UDP `51820` verso `sseapid.isti.cnr.it`.

I profili client vengono generati nella directory:

```text
wireguard/config/peer_<nome_peer>/
```

La configurazione server usata dal container viene generata qui:

```text
wireguard/config/wg_confs/wg0.conf
```

Non serve installare `wireguard-tools` o `qrencode` sull'host: sono responsabilita' del container.

Nel repository restano anche le configurazioni WireGuard leggibili:

```text
wireguard/wg0.conf
wireguard/android-client.conf
clients/macos/sseapid-wireguard.conf
clients/windows/sseapid-wireguard.conf
clients/linux/sseapid-wireguard.conf
```

I valori di chiave in questi file non sono hardcoded per sicurezza. Le versioni con chiavi reali vengono generate dal container in `wireguard/config/`.

## Android

Installa l'app ufficiale **WireGuard** da Google Play o F-Droid.

Per mostrare il QR code del primo dispositivo Android:

```bash
./scripts/show-android-qr.sh android1
```

Poi dall'app Android:

1. premi `+`;
2. scegli `Scansiona da codice QR`;
3. scansiona il QR mostrato sul terminale;
4. salva e attiva la VPN.

Per aggiungere altri telefoni, modifica `PEERS` in `.env`, per esempio:

```dotenv
PEERS=android1,android2,android3,android4,macos1,windows1,linux1
```

poi ricrea il container:

```bash
./scripts/start.sh
```

## Desktop

Sono configurati anche tre peer desktop:

```dotenv
PEERS=android1,android2,android3,macos1,windows1,linux1
```

Dopo `./scripts/start.sh`, i profili reali saranno disponibili qui:

```text
wireguard/config/peer_macos1/peer_macos1.conf
wireguard/config/peer_windows1/peer_windows1.conf
wireguard/config/peer_linux1/peer_linux1.conf
```

Nel repository ci sono anche configurazioni leggibili senza chiavi reali:

```text
clients/macos/sseapid-wireguard.conf
clients/windows/sseapid-wireguard.conf
clients/linux/sseapid-wireguard.conf
```

## DNS locale

I dispositivi Android collegati alla VPN useranno il DNS indicato da `PEERDNS` in `.env`.

La configurazione attuale usa:

```dotenv
PEERDNS=10.8.0.1
```

Usa questo valore se il resolver DNS locale gira direttamente su `sseapid.isti.cnr.it` ed e' configurato per ascoltare anche sull'interfaccia WireGuard. Se invece il DNS locale e' su una rete interna, sostituisci il valore con il suo IP, per esempio:

```dotenv
PEERDNS=192.168.1.53
```

Dopo la modifica rigenera i profili:

```bash
docker compose down
./scripts/start.sh
```

Se stai usando split tunnel, l'IP del DNS deve essere incluso in `ALLOWEDIPS`, per esempio:

```dotenv
PEERDNS=192.168.1.53
ALLOWEDIPS=10.8.0.0/24,192.168.1.53/32
```

## Rotte e accesso

La configurazione client proposta instrada tutto il traffico nella VPN:

```text
AllowedIPs = 0.0.0.0/0, ::/0
```

Per usare la VPN solo verso la rete VPN, sostituisci `AllowedIPs` con:

```text
AllowedIPs = 10.8.0.0/24
```

Se devi raggiungere reti interne dietro `sseapid.isti.cnr.it`, aggiungi anche quelle subnet, per esempio:

```text
AllowedIPs = 10.8.0.0/24, 192.168.1.0/24
```

## Note sicurezza

- `.env` contiene la configurazione reale ma non deve contenere chiavi private.
- Non committare chiavi private o profili client reali generati in `wireguard/config/`.
- Il dominio pubblico configurato e' `sseapid.isti.cnr.it`.
- Limita sul firewall solo le porte necessarie: UDP `51820` per WireGuard.
- Revoca/rimuovi subito un peer se un dispositivo viene perso.
