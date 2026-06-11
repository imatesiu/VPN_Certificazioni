# VPN_v2 - OpenVPN con server pubblico Docker

Architettura corretta per il caso in cui il PC `192.168.1.146` non sia raggiungibile da Internet:

```text
Android LTE  ─┐
              ├─ OpenVPN server pubblico Docker ── tunnel ── PC 192.168.1.146
PC 192.168.1.146 ─┘
```

Android e PC sono entrambi client OpenVPN. Sulla VPN, il server pubblico `gram.isti.cnr.it` intercetta il traffico destinato a `146.48.84.211` e lo redirige al PC `pc1` sull'indirizzo VPN `10.8.0.5`.

## Nota critica sugli IP

`VPN_SERVER_PUBLIC_HOST` deve essere un IP pubblico o DNS raggiungibile da Android. In questa versione il valore predefinito e':

```text
gram.isti.cnr.it
```

Se `146.48.84.211` e' l'IP applicativo che Android deve continuare a usare, l'endpoint OpenVPN non deve coincidere con `146.48.84.211`. Android instrada per IP di destinazione, non per porta: non puo' mandare `146.48.84.211:1194` fuori dal tunnel e contemporaneamente `146.48.84.211:<porta_app>` dentro il tunnel in modo affidabile.

Quindi serve:

```text
VPN_SERVER_PUBLIC_HOST = gram.isti.cnr.it
PUBLIC_SERVICE_IP      = 146.48.84.211
```

con valori diversi.

## File principali

- `.env.example`: variabili da copiare in `.env`.
- `docker-compose.yml`: server OpenVPN Docker.
- `scripts/init.sh`: genera CA, certificati, configurazione server e profili client.
- `scripts/start.sh`: avvia o ricrea il container OpenVPN.
- `scripts/init-and-start.sh`: wrapper di compatibilita' che esegue `init.sh` e poi `start.sh`.
- `scripts/common.sh`: funzioni condivise dagli script.
- `scripts/container-up.sh`: regole iptables dentro il container.
- `scripts/pc-client-linux-setup.sh`: preparazione minima del PC Linux client.
- `clients/android1.ovpn`: generato dallo script.
- `clients/pc1.ovpn`: generato dallo script.
- `clients/pc2.ovpn`: generato dallo script.

## Piano IP VPN

```text
Subnet VPN:     10.8.0.0/24
Server OpenVPN: 10.8.0.1
Android:        DHCP OpenVPN, dal pool implicito del server
PC1 client:     10.8.0.5
PC2 client:     DHCP OpenVPN, dal pool implicito del server
```

## Routing Internet

La configurazione e' split tunnel: i client VPN non usano `gram.isti.cnr.it` come uscita Internet generale.

Nella VPN passa solo il traffico verso:

```text
146.48.84.211/32
```

Tutto il resto continua a uscire dalla rete normale del client, per esempio LTE su Android o LAN/Wi-Fi sui PC.

Questo e' ottenuto evitando `redirect-gateway` e spingendo solo:

```text
push "route 146.48.84.211 255.255.255.255"
```

In piu', i profili client generati da `init.sh` includono:

```text
route-nopull
route 146.48.84.211 255.255.255.255
```

Questo evita che eventuali direttive di rotta generiche o profili vecchi trasformino la VPN in default gateway.

## Configurazione

Sulla macchina `gram.isti.cnr.it`:

```bash
cd VPN_v2
cp .env.example .env
```

Modifica `.env`:

```dotenv
VPN_SERVER_PUBLIC_HOST=gram.isti.cnr.it
VPN_PORT=1194
VPN_SUBNET=10.8.0.0/24
PC_VPN_IP=10.8.0.5
PUBLIC_SERVICE_IP=146.48.84.211
```

Apri sul firewall del server pubblico:

```text
UDP 1194
```

## Generazione chiavi e profili

Sulla macchina `gram.isti.cnr.it`:

```bash
./scripts/init.sh
```

Lo script:

- scarica l'immagine Docker `kylemanna/openvpn`;
- genera configurazione server OpenVPN;
- crea CA e certificati;
- crea i client `android1`, `pc1` e `pc2`;
- configura `ccd` solo per `pc1`, che resta statico a `10.8.0.5`;
- lascia `android1` e `pc2` in DHCP OpenVPN usando il pool implicito creato dalla direttiva `server`;
- aggiunge gli hook che faranno DNAT sulla VPN `146.48.84.211 -> 10.8.0.5`;
- rimuove eventuali vecchie direttive `redirect-gateway`, cosi' il traffico Internet generico resta sulla rete normale del client;
- rimuove eventuali rotte residue verso `192.168.254.0/24`;
- genera profili client con `route-nopull` e sola rotta `146.48.84.211/32`;
- genera i profili client.

## Avvio server

Sulla macchina `gram.isti.cnr.it`:

```bash
./scripts/start.sh
```

Lo script copia gli hook runtime aggiornati dentro `data/conf/scripts` e ricrea il container con:

```bash
docker compose up -d --force-recreate
```

Nota: alcuni file dentro `data/conf` vengono creati dal container come `root`. Lo script usa `sudo` quando deve aggiornare `ccd`, script di hook e profili generati.

Se su `gram.isti.cnr.it` avevi gia' generato `data/conf/openvpn.conf` con una subnet diversa, `init.sh` si ferma. Il messaggio `Processing Route Config: '192.168.254.0/24'` indica quasi sempre una configurazione OpenVPN gia' presente generata con il default dell'immagine `kylemanna/openvpn`, non con il nostro `VPN_SUBNET=10.8.0.0/24`.

Per rigenerare da zero:

```bash
docker compose down
sudo mv data/conf data/conf.backup.$(date +%Y%m%d-%H%M%S)
./scripts/init.sh
./scripts/start.sh
```

Questa operazione rigenera CA, certificati e profili client. Conserva prima eventuali profili gia' distribuiti se devi ancora usarli.

Se il container esce con errori su IPv6 forwarding o `net.ipv4.ip_forward`, rilancia `./scripts/start.sh`: la configurazione Docker passa i sysctl necessari al container e lo ricrea con `--force-recreate`.

Se il container esce con `--server already defines an ifconfig-pool`, rilancia prima `./scripts/init.sh`: lo script rimuove eventuali righe `ifconfig-pool` aggiunte in precedenza, perche' OpenVPN le considera incompatibili con la direttiva `server`.

Profili generati:

```text
VPN_v2/clients/android1.ovpn
VPN_v2/clients/pc1.ovpn
VPN_v2/clients/pc2.ovpn
```

## PC 192.168.1.146

Il PC non deve ricevere connessioni da Internet. Deve solo collegarsi in uscita al server OpenVPN pubblico usando:

```text
VPN_v2/clients/pc1.ovpn
```

Su Linux, prima di avviare il client:

```bash
sudo bash VPN_v2/scripts/pc-client-linux-setup.sh
sudo openvpn --config VPN_v2/clients/pc1.ovpn
```

Il servizio locale deve ascoltare su `10.8.0.5` oppure su `0.0.0.0`.

## Secondo PC

Il secondo PC usa:

```text
VPN_v2/clients/pc2.ovpn
```

`pc2` riceve l'indirizzo dal pool DHCP OpenVPN e non riceve la redirezione destinata a `10.8.0.5`.

## Android

Importa sul terminale Android:

```text
VPN_v2/clients/android1.ovpn
```

Quando Android invia messaggi a:

```text
146.48.84.211
```

il server OpenVPN pubblico applica DNAT sulla VPN e inoltra il traffico verso:

```text
10.8.0.5
```

## Test

Su `gram.isti.cnr.it`:

```bash
docker compose logs -f openvpn
docker exec -it vpn-v2-openvpn iptables -t nat -S
```

Sul PC:

```bash
ip addr
ip route
```

Il client `pc1` deve essere connesso prima che Android inizi a inviare messaggi.
