# VPN_v2 - OpenVPN con server pubblico Docker

Architettura corretta per il caso in cui il PC `192.168.1.146` non sia raggiungibile da Internet:

```text
Android LTE  ─┐
              ├─ OpenVPN server pubblico Docker ── tunnel ── PC 192.168.1.146
PC 192.168.1.146 ─┘
```

Android e PC sono entrambi client OpenVPN. Il server pubblico `gram.isti.cnr.it` intercetta il traffico Android destinato a `146.48.84.211` e lo inoltra al PC tramite il tunnel.

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
- `scripts/init-and-start.sh`: genera CA, certificati, profili client e avvia Docker.
- `scripts/container-up.sh`: regole iptables dentro il container.
- `scripts/pc-client-linux-setup.sh`: preparazione minima del PC Linux client.
- `clients/android1.ovpn`: generato dallo script.
- `clients/pc1.ovpn`: generato dallo script.

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
PUBLIC_SERVICE_IP=146.48.84.211
PC_LAN_IP=192.168.1.146
```

Apri sul firewall del server pubblico:

```text
UDP 1194
```

## Generazione chiavi, profili e avvio server

Sulla macchina `gram.isti.cnr.it`:

```bash
./scripts/init-and-start.sh
```

Lo script:

- scarica l'immagine Docker `kylemanna/openvpn`;
- genera configurazione server OpenVPN;
- crea CA e certificati;
- crea i client `android1` e `pc1`;
- configura `ccd` con IP statici;
- aggiunge DNAT `146.48.84.211 -> 192.168.1.146`;
- avvia il container.

Nota: alcuni file dentro `data/conf` vengono creati dal container come `root`. Lo script usa `sudo` quando deve aggiornare `ccd`, script di hook e profili generati.

Se il container esce con errori su IPv6 forwarding o `net.ipv4.ip_forward`, rilancia questo script: la configurazione Docker passa i sysctl necessari al container e lo ricrea con `--force-recreate`.

Profili generati:

```text
VPN_v2/clients/android1.ovpn
VPN_v2/clients/pc1.ovpn
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

Il servizio locale deve ascoltare su `192.168.1.146` oppure su `0.0.0.0`.

## Android

Importa sul terminale Android:

```text
VPN_v2/clients/android1.ovpn
```

Quando Android invia messaggi a:

```text
146.48.84.211
```

il server OpenVPN pubblico applica DNAT e inoltra il traffico nel tunnel verso:

```text
192.168.1.146
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
