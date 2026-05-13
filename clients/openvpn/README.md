# OpenVPN client

Questa directory contiene un profilo client OpenVPN per `sseapid.isti.cnr.it`.

File:

- `sseapid-client.ovpn`: profilo client OpenVPN senza certificati reali inline.

Il profilo non contiene segreti. Per renderlo operativo devi inserire:

- CA pubblica in `<ca>...</ca>`
- certificato client in `<cert>...</cert>`
- chiave privata client in `<key>...</key>`
- chiave `tls-crypt` in `<tls-crypt>...</tls-crypt>`

Il server OpenVPN deve essere attivo su:

```text
sseapid.isti.cnr.it:1194/udp
```

Il DNS consegnato dal server OpenVPN ai client e':

```text
192.168.4.146
```

La configurazione Docker puo' avviare anche OpenVPN con:

```bash
./scripts/openvpn-install.sh
```

I profili reali generati sono in:

```text
clients/openvpn/generated/
```
