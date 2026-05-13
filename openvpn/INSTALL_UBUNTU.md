# OpenVPN server su Ubuntu

Questa guida installa un server OpenVPN nativo su Ubuntu, separato dal servizio WireGuard Docker gia' presente.

Endpoint OpenVPN:

```text
sseapid.isti.cnr.it:1194/udp
```

Rete OpenVPN:

```text
192.168.4.0/24
```

DNS consegnato ai client OpenVPN:

```text
192.168.4.146
```

Il DNS `192.168.4.146` deve essere raggiungibile dai client OpenVPN. In questa configurazione l'indirizzo viene riservato a un client/servizio OpenVPN chiamato `dns1`.

## Certificato Let's Encrypt

Il certificato Let's Encrypt di `sseapid.isti.cnr.it` non viene usato come default per OpenVPN.

OpenVPN usa una PKI propria per autenticare server e client. Let's Encrypt puo' autenticare il server TLS, ma non sostituisce i certificati client OpenVPN ne' la chiave `tls-crypt`. Per una VPN interna e' piu' semplice e robusto usare Easy-RSA come CA dedicata.

Vedi anche:

```text
openvpn/LETSENCRYPT.md
```

## 1. Installazione pacchetti

```bash
sudo apt update
sudo apt install -y openvpn easy-rsa
```

## 2. Preparazione PKI

```bash
sudo make-cadir /etc/openvpn/server/easy-rsa
cd /etc/openvpn/server/easy-rsa
```

Inizializza la PKI:

```bash
sudo ./easyrsa init-pki
sudo ./easyrsa build-ca
```

Genera certificato e chiave server:

```bash
sudo ./easyrsa build-server-full server nopass
```

Genera il primo client:

```bash
sudo ./easyrsa build-client-full client1 nopass
```

Se il DNS OpenVPN deve stare su `192.168.4.146`, genera anche un certificato client con Common Name `dns1`:

```bash
sudo ./easyrsa build-client-full dns1 nopass
```

Genera la chiave `tls-crypt`:

```bash
sudo openvpn --genkey secret /etc/openvpn/server/easy-rsa/pki/ta.key
```

## 3. Copia configurazione server

Dal repository:

```bash
sudo cp openvpn/server.conf /etc/openvpn/server/server.conf
```

Copia anche la configurazione statica del client DNS:

```bash
sudo mkdir -p /etc/openvpn/server/ccd
sudo cp openvpn/ccd/dns1 /etc/openvpn/server/ccd/dns1
```

La configurazione punta ai file in:

```text
/etc/openvpn/server/pki/
```

Se Easy-RSA ha generato la PKI in `/etc/openvpn/server/easy-rsa/pki`, copia o sincronizza i file:

```bash
sudo mkdir -p /etc/openvpn/server/pki
sudo cp -a /etc/openvpn/server/easy-rsa/pki/ca.crt /etc/openvpn/server/pki/
sudo cp -a /etc/openvpn/server/easy-rsa/pki/issued /etc/openvpn/server/pki/
sudo cp -a /etc/openvpn/server/easy-rsa/pki/private /etc/openvpn/server/pki/
sudo cp -a /etc/openvpn/server/easy-rsa/pki/ta.key /etc/openvpn/server/pki/
```

Proteggi le chiavi:

```bash
sudo chmod 600 /etc/openvpn/server/pki/private/*.key
sudo chmod 600 /etc/openvpn/server/pki/ta.key
```

## 4. Abilita forwarding IP

Crea un file sysctl dedicato:

```bash
sudo tee /etc/sysctl.d/99-openvpn-forwarding.conf >/dev/null <<'EOF'
net.ipv4.ip_forward=1
EOF
```

Applica:

```bash
sudo sysctl --system
```

## 5. Firewall e NAT

Apri la porta OpenVPN:

```bash
sudo ufw allow 1194/udp
```

Se usi UFW, aggiungi NAT in `/etc/ufw/before.rules`, prima della sezione `*filter`.

Sostituisci `eth0` con l'interfaccia pubblica reale del server se diversa:

```text
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 192.168.4.0/24 -o eth0 -j MASQUERADE
COMMIT
```

Consenti forwarding in `/etc/default/ufw`:

```text
DEFAULT_FORWARD_POLICY="ACCEPT"
```

Ricarica UFW:

```bash
sudo ufw reload
```

Se non usi UFW, puoi applicare temporaneamente NAT con:

```bash
sudo iptables -t nat -A POSTROUTING -s 192.168.4.0/24 -o eth0 -j MASQUERADE
```

## 6. Avvio servizio

```bash
sudo systemctl enable --now openvpn-server@server
```

Controlla stato e log:

```bash
sudo systemctl status openvpn-server@server
sudo journalctl -u openvpn-server@server -f
```

## 7. Creazione profilo client

Parti dal template:

```text
openvpn/client-template.ovpn
```

Inserisci inline:

- `/etc/openvpn/server/pki/ca.crt` dentro `<ca>`
- `/etc/openvpn/server/pki/issued/client1.crt` dentro `<cert>`
- `/etc/openvpn/server/pki/private/client1.key` dentro `<key>`
- `/etc/openvpn/server/pki/ta.key` dentro `<tls-crypt>`

Salva il file finale come:

```text
clients/openvpn/client1.private.ovpn
```

I file `*.private.ovpn` sono esclusi da Git.

## 8. Note su WireGuard e OpenVPN insieme

WireGuard e OpenVPN possono convivere sulla stessa macchina:

```text
WireGuard: sseapid.isti.cnr.it:51820/udp
OpenVPN:   sseapid.isti.cnr.it:1194/udp
```

Sono pero' due VPN diverse. Un client OpenVPN non puo' collegarsi al server WireGuard e un client WireGuard non puo' collegarsi al server OpenVPN.

Se i client OpenVPN devono usare DNS `192.168.4.146`, il client o servizio DNS con certificato `dns1` deve essere collegato alla VPN e deve ascoltare su `192.168.4.146`.
