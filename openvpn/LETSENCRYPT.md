# Let's Encrypt e OpenVPN

Per questa configurazione OpenVPN e' consigliato usare una PKI dedicata con Easy-RSA.

Il certificato Let's Encrypt di `sseapid.isti.cnr.it` puo' essere usato per autenticare il server TLS, ma non sostituisce tutta la PKI OpenVPN:

- OpenVPN richiede comunque certificati client se usi autenticazione mTLS.
- La chiave `tls-crypt` e' separata e non c'entra con Let's Encrypt.
- Il rinnovo automatico Let's Encrypt richiede reload del servizio OpenVPN.
- Mischiare CA pubblica Let's Encrypt per il server e CA privata per i client complica gestione e revoca.

Per una VPN interna, la soluzione piu' ordinata resta:

```text
CA OpenVPN dedicata con Easy-RSA
certificato server OpenVPN firmato dalla CA OpenVPN
certificati client OpenVPN firmati dalla CA OpenVPN
tls-crypt separato
```

Se vuoi comunque usare il certificato Let's Encrypt solo lato server, devi modificare `openvpn/server.conf` puntando a file come:

```text
cert /etc/letsencrypt/live/sseapid.isti.cnr.it/fullchain.pem
key /etc/letsencrypt/live/sseapid.isti.cnr.it/privkey.pem
```

Ma devi mantenere una CA/certificati client OpenVPN oppure cambiare modello di autenticazione. Per questo repository manteniamo Easy-RSA come default.

