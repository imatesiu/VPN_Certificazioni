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

Lo script modifica la direttiva OpenVPN generata da:

```text
server 10.9.0.0 255.255.255.0
```

a:

```text
topology subnet
server 10.9.0.0 255.255.255.0 nopool
ifconfig-pool 10.9.0.10 10.9.0.254 255.255.255.0
```

`topology subnet` e' necessaria per usare una netmask esplicita in `ifconfig-pool` e per assegnare `10.9.0.5` a `dns1` con `ifconfig-push`. Questo evita che `10.9.0.5` venga assegnato a client casuali dal pool dinamico.

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
clients/openvpn/generated/android-openvpn1.ovpn
```

Questi file contengono segreti e sono esclusi da Git.

`dns1.ovpn` e' il profilo del client/servizio che riceve l'IP statico `10.9.0.5`.

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

## Permessi del volume

Il container crea alcuni file in `openvpn-data/conf/` come root. Lo script usa `sudo` quando deve aggiornare `openvpn.conf` o `ccd/dns1`.

Se l'esecuzione era stata interrotta prima di questa correzione, rilancia semplicemente:

```bash
./scripts/openvpn-install.sh
```

Lo script ricrea il container OpenVPN per applicare anche i `sysctls` richiesti dal container.
