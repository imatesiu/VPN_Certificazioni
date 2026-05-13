# OpenVPN server Docker

Questa e' la modalita' consigliata in questo repository per avviare OpenVPN: il server gira in Docker e la PKI viene generata dentro il container.

Non usa certificati Let's Encrypt.

## Configurazione

Le variabili sono in `.env`:

```dotenv
OPENVPN_SERVER=sseapid.isti.cnr.it
OPENVPN_PORT=1194
OPENVPN_SUBNET=10.9.0.0/24
OPENVPN_DNS=10.9.0.5
OPENVPN_POOL_START=10.9.0.10
OPENVPN_POOL_END=10.9.0.254
OPENVPN_CLIENTS=client1,dns1
```

Il DNS OpenVPN e' `10.9.0.5`. Lo script riserva quell'indirizzo al client `dns1` tramite CCD.

## Installazione e avvio

Sul server:

```bash
./scripts/openvpn-install.sh
```

Lo script:

- installa Docker e Docker Compose plugin se mancanti;
- apre UDP `1194` con `ufw` o `firewalld`, se presenti;
- scarica l'immagine `kylemanna/openvpn`;
- genera configurazione server e PKI;
- genera i profili client indicati in `OPENVPN_CLIENTS`;
- avvia il servizio `openvpn` nel `docker-compose.yml`.

## File generati

Configurazione e PKI server:

```text
openvpn-data/conf/
```

Profili client:

```text
clients/openvpn/generated/client1.ovpn
clients/openvpn/generated/dns1.ovpn
```

Questi file contengono segreti e sono esclusi da Git.

## Avvio e log

Riavvia solo OpenVPN:

```bash
docker compose restart openvpn
```

Log:

```bash
docker compose logs -f openvpn
```

## Aggiungere client

Modifica `.env`, per esempio:

```dotenv
OPENVPN_CLIENTS=client1,dns1,android-openvpn1
```

Poi rilancia:

```bash
./scripts/openvpn-install.sh
```

Lo script non rigenera la PKI esistente; crea solo i client mancanti e aggiorna i profili `.ovpn`.
