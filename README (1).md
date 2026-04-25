# FOU Tunnel P2P Docker — Panduan Multi Server, Multi Interface, Multi IP, Multi UDP Port

Panduan ini menjelaskan file mana saja yang harus diedit ketika mengganti IP, nama interface, server tujuan, port UDP, atau menjalankan banyak tunnel P2P di server berbeda.

Proyek ini memakai **FOU / Foo-over-UDP** dengan tunnel **P2P**. Default tunnel memakai `ipip` over UDP. Satu pasang server-client membutuhkan:

- 1 interface fisik/lokal di sisi server.
- 1 interface fisik/lokal di sisi client.
- 1 port UDP FOU yang sama di kedua sisi.
- 1 subnet kecil untuk IP tunnel, biasanya `/30`.
- 1 nama interface tunnel unik, misalnya `tun0`, `tun1`, `tun2`.

---

## 1. Ringkasan File yang Harus Diedit

### Paling penting

| Kebutuhan perubahan | File yang diedit | Wajib? | Catatan |
|---|---|---:|---|
| Ganti IP server | `server/.env`, `client/.env` | Ya | `SERVER_IP` harus sama di server dan client. |
| Ganti IP publik client/NAT | `server/.env`, `client/.env` | Ya | Di server wajib `CLIENT_PUBLIC_IP`. Di client hanya informasi/log. |
| Ganti IP lokal client | `client/.env` | Ya | `CLIENT_LOCAL_IP` harus IP yang benar-benar ada di interface client. |
| Ganti nama interface server | `server/.env` | Ya | Ubah `SERVER_IFACE`, contoh `eth0`, `ens3`, `enp1s0`. |
| Ganti nama interface client | `client/.env` | Ya | Ubah `CLIENT_IFACE`. |
| Ganti port UDP | `server/.env`, `client/.env` | Ya | `FOU_PORT` harus sama di kedua sisi untuk satu tunnel. |
| Ganti IP tunnel P2P | `server/.env`, `client/.env` | Ya | Gunakan pasangan `/30`, contoh `10.11.13.1/30` dan `10.11.13.2/30`. |
| Banyak tunnel di host yang sama | `.env` dan `docker-compose.yml` | Ya | `TUNNEL_IF`, `FOU_PORT`, `container_name`, dan label harus unik. |
| Ubah teks hardcoded/dokumentasi | `README.md`, `CARA JALANKAN.txt`, komentar di file | Tidak | Tidak memengaruhi fungsi, hanya agar tidak membingungkan. |

### File yang biasanya tidak perlu diedit

| File | Perlu diedit? | Keterangan |
|---|---:|---|
| `server/entrypoint.sh` | Tidak, kecuali menambah fitur | Script sudah membaca variabel dari `.env`. |
| `client/entrypoint.sh` | Tidak, kecuali menambah fitur | Script sudah membaca variabel dari `.env`. |
| `client/keepalive.sh` | Tidak | Membaca `TUNNEL_SERVER_PEER`, `KEEPALIVE_INTERVAL`, dan `TUNNEL_IF` dari `.env`. |
| `server/healthcheck.sh` | Tidak | Membaca `TUNNEL_IF` dan peer dari `.env`. |
| `client/healthcheck.sh` | Tidak | Membaca `TUNNEL_IF` dan peer dari `.env`. |
| `Dockerfile` | Tidak | Label di Dockerfile hanya deskripsi. Boleh diedit agar sesuai, tetapi tidak wajib. |
| `example.env` | Opsional | Template saja. Bila ingin template ikut benar, edit juga. |

---

## 2. Variabel Penting di `server/.env`

Contoh isi sisi server:

```env
SERVER_IFACE=eth2
SERVER_IP=202.10.48.182

CLIENT_PUBLIC_IP=38.47.95.247

FOU_PORT=5555
IPPROTO=4
TUNNEL_PROTO=ipip

TUNNEL_IF=tun0
TUNNEL_SERVER_ADDR=10.11.12.1/30
TUNNEL_CLIENT_PEER=10.11.12.2

ENABLE_MASQUERADE=false
```

Penjelasan:

| Variabel | Fungsi | Contoh |
|---|---|---|
| `SERVER_IFACE` | Nama interface fisik server yang menghadap jaringan/publik | `eth0`, `eth2`, `ens3` |
| `SERVER_IP` | IP server yang dipakai sebagai endpoint FOU | `202.10.48.182` |
| `CLIENT_PUBLIC_IP` | IP publik client yang terlihat dari server, biasanya IP NAT/CGNAT | `38.47.95.247` |
| `FOU_PORT` | Port UDP FOU | `5555` |
| `IPPROTO` | Protokol dalam FOU. `4` untuk IPIP, `47` untuk GRE | `4` |
| `TUNNEL_PROTO` | Jenis tunnel Linux | `ipip` atau `gre` |
| `TUNNEL_IF` | Nama interface tunnel virtual | `tun0` |
| `TUNNEL_SERVER_ADDR` | IP tunnel sisi server | `10.11.12.1/30` |
| `TUNNEL_CLIENT_PEER` | IP peer tunnel sisi client tanpa prefix | `10.11.12.2` |
| `ENABLE_MASQUERADE` | Aktifkan NAT internet keluar via server | `false` atau `true` |

---

## 3. Variabel Penting di `client/.env`

Contoh isi sisi client:

```env
CLIENT_IFACE=eth2
CLIENT_LOCAL_IP=172.16.3.200
CLIENT_PUBLIC_IP=38.47.95.247

SERVER_IP=202.10.48.182

FOU_PORT=5555
IPPROTO=4
TUNNEL_PROTO=ipip

TUNNEL_IF=tun0
TUNNEL_CLIENT_ADDR=10.11.12.2/30
TUNNEL_SERVER_PEER=10.11.12.1

ENABLE_KEEPALIVE=true
KEEPALIVE_INTERVAL=20

ADD_DEFAULT_ROUTE=false
ADD_CUSTOM_ROUTES=
```

Penjelasan:

| Variabel | Fungsi | Contoh |
|---|---|---|
| `CLIENT_IFACE` | Nama interface lokal client | `eth0`, `eth2`, `ens18` |
| `CLIENT_LOCAL_IP` | IP yang benar-benar ada di interface client | `172.16.3.200` |
| `CLIENT_PUBLIC_IP` | IP publik setelah NAT/CGNAT. Umumnya hanya untuk informasi/log | `38.47.95.247` |
| `SERVER_IP` | IP endpoint server | `202.10.48.182` |
| `FOU_PORT` | Port UDP FOU, harus sama dengan server untuk tunnel ini | `5555` |
| `TUNNEL_IF` | Nama interface tunnel virtual | `tun0` |
| `TUNNEL_CLIENT_ADDR` | IP tunnel sisi client | `10.11.12.2/30` |
| `TUNNEL_SERVER_PEER` | IP peer tunnel sisi server tanpa prefix | `10.11.12.1` |
| `ENABLE_KEEPALIVE` | Keepalive agar NAT UDP tidak mati | `true` |
| `KEEPALIVE_INTERVAL` | Interval ping keepalive dalam detik | `15` atau `20` |
| `ADD_DEFAULT_ROUTE` | Semua traffic client lewat tunnel | `false` atau `true` |
| `ADD_CUSTOM_ROUTES` | Route jaringan tertentu lewat tunnel | `192.168.50.0/24,10.0.0.0/8` |

> Penting: `CLIENT_LOCAL_IP` **bukan** IP publik NAT. Nilainya harus IP yang benar-benar muncul di output `ip addr show` pada host client.

---

## 4. Cara Cek Nama Interface dan IP

Jalankan di masing-masing host:

```bash
ip -br addr
ip route
```

Contoh output:

```text
lo      UNKNOWN 127.0.0.1/8
eth0    UP      202.10.48.182/24
```

Maka di server:

```env
SERVER_IFACE=eth0
SERVER_IP=202.10.48.182
```

Di client, jika output:

```text
eth1    UP      172.16.3.200/24
```

Maka:

```env
CLIENT_IFACE=eth1
CLIENT_LOCAL_IP=172.16.3.200
```

---

## 5. Cara Menentukan IP Publik Client

Di host client:

```bash
curl -4 ifconfig.me
# atau
curl -4 https://api.ipify.org
```

Masukkan hasilnya ke sisi server:

```env
CLIENT_PUBLIC_IP=<hasil-ip-publik-client>
```

Di sisi client, `CLIENT_PUBLIC_IP` boleh diisi sama agar log mudah dibaca, tetapi script tidak melakukan bind ke IP publik NAT tersebut.

---

## 6. Syarat Port UDP

Untuk satu tunnel P2P:

- `server/.env` dan `client/.env` harus memakai `FOU_PORT` yang sama.
- Firewall server harus membuka port UDP tersebut.
- Jika banyak tunnel pada host yang sama, setiap tunnel sebaiknya memakai port UDP berbeda.

Contoh buka port di server:

```bash
sudo ufw allow 5555/udp
```

Atau dengan iptables:

```bash
sudo iptables -I INPUT -p udp --dport 5555 -j ACCEPT
```

---

## 7. Menjalankan Tunnel Pertama

### 7.1 Instal Docker

Di server dan client:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### 7.2 Load modul kernel

Di server dan client:

```bash
sudo modprobe fou
sudo modprobe ipip
sudo modprobe ip_gre
```

Agar otomatis saat boot:

```bash
echo -e "fou\nipip\nip_gre" | sudo tee /etc/modules-load.d/fou-tunnel.conf
```

### 7.3 Aktifkan IP forwarding dan matikan rp_filter

Di server:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.all.rp_filter=0
sudo sysctl -w net.ipv4.conf.eth2.rp_filter=0
```

Ganti `eth2` sesuai `SERVER_IFACE`.

Di client:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.all.rp_filter=0
sudo sysctl -w net.ipv4.conf.eth2.rp_filter=0
```

Ganti `eth2` sesuai `CLIENT_IFACE`.

### 7.4 Jalankan sisi server

```bash
cd fou-tunnel/server
cp example.env .env
nano .env

docker compose down
docker compose up -d --build
docker compose logs -f fou-server
```

### 7.5 Jalankan sisi client

```bash
cd fou-tunnel/client
cp example.env .env
nano .env

docker compose down
docker compose up -d --build
docker compose logs -f fou-client
```

---

## 8. Contoh Konfigurasi Banyak Tunnel P2P

Misal satu server menerima 3 client berbeda.

| Tunnel | Server IP | Client Public IP | UDP Port | Tunnel IF Server | Tunnel IF Client | Tunnel IP Server | Tunnel IP Client |
|---|---|---|---:|---|---|---|---|
| A | `202.10.48.182` | `38.47.95.247` | `5555` | `tun0` | `tun0` | `10.11.12.1/30` | `10.11.12.2/30` |
| B | `202.10.48.182` | `103.10.10.20` | `5556` | `tun1` | `tun0` | `10.11.13.1/30` | `10.11.13.2/30` |
| C | `202.10.48.182` | `114.5.6.7` | `5557` | `tun2` | `tun0` | `10.11.14.1/30` | `10.11.14.2/30` |

Catatan:

- Di server yang sama, `TUNNEL_IF` dan `FOU_PORT` harus unik per tunnel.
- Di client yang berbeda server/host, `TUNNEL_IF=tun0` masih boleh sama karena host-nya berbeda.
- Jika beberapa tunnel berjalan di host client yang sama, `TUNNEL_IF` dan `FOU_PORT` juga harus unik di client tersebut.

---

## 9. Cara Menjalankan Banyak Tunnel di Host yang Sama

Karena `docker-compose.yml` memakai `container_name` tetap, jangan menjalankan banyak instance dari folder yang sama tanpa mengubah nama container.

Struktur yang disarankan di server:

```text
fou-tunnel/
├── server-client-a/
├── server-client-b/
└── server-client-c/
```

Buat copy folder server:

```bash
cp -a fou-tunnel/server fou-tunnel/server-client-a
cp -a fou-tunnel/server fou-tunnel/server-client-b
cp -a fou-tunnel/server fou-tunnel/server-client-c
```

Lalu edit masing-masing:

```bash
nano fou-tunnel/server-client-a/.env
nano fou-tunnel/server-client-a/docker-compose.yml

nano fou-tunnel/server-client-b/.env
nano fou-tunnel/server-client-b/docker-compose.yml

nano fou-tunnel/server-client-c/.env
nano fou-tunnel/server-client-c/docker-compose.yml
```

### Yang wajib unik di `.env`

Contoh `server-client-b/.env`:

```env
SERVER_IFACE=eth2
SERVER_IP=202.10.48.182
CLIENT_PUBLIC_IP=103.10.10.20

FOU_PORT=5556
IPPROTO=4
TUNNEL_PROTO=ipip

TUNNEL_IF=tun1
TUNNEL_SERVER_ADDR=10.11.13.1/30
TUNNEL_CLIENT_PEER=10.11.13.2

ENABLE_MASQUERADE=false
```

### Yang wajib unik di `docker-compose.yml`

Ubah minimal bagian berikut:

```yaml
services:
  fou-server-b:
    image: fou-server-b:alpine
    container_name: fou-server-b
```

Jika tetap memakai nama `fou-server`, container akan bentrok dengan instance lain.

Label boleh disesuaikan agar mudah dibaca:

```yaml
labels:
  - "foutunnel.role=server"
  - "foutunnel.name=client-b"
  - "foutunnel.port=5556"
```

Jalankan:

```bash
cd fou-tunnel/server-client-b
docker compose up -d --build
```

---

## 10. Contoh Client untuk Server Berbeda

Misal client ingin connect ke server B.

`client/.env`:

```env
CLIENT_IFACE=eth2
CLIENT_LOCAL_IP=172.16.3.200
CLIENT_PUBLIC_IP=103.10.10.20

SERVER_IP=202.10.48.182

FOU_PORT=5556
IPPROTO=4
TUNNEL_PROTO=ipip

TUNNEL_IF=tun0
TUNNEL_CLIENT_ADDR=10.11.13.2/30
TUNNEL_SERVER_PEER=10.11.13.1

ENABLE_KEEPALIVE=true
KEEPALIVE_INTERVAL=20

ADD_DEFAULT_ROUTE=false
ADD_CUSTOM_ROUTES=
```

Jika client ini menjalankan lebih dari satu tunnel pada host yang sama, gunakan nama unik:

```env
TUNNEL_IF=tun1
FOU_PORT=5557
TUNNEL_CLIENT_ADDR=10.11.14.2/30
TUNNEL_SERVER_PEER=10.11.14.1
```

Dan ubah `docker-compose.yml`:

```yaml
services:
  fou-client-c:
    image: fou-client-c:alpine
    container_name: fou-client-c
```

---

## 11. Checklist Saat Ganti IP, Interface, Server, atau Port

### A. Ganti IP server

Edit:

- `server/.env`
- `client/.env`

Ubah:

```env
SERVER_IP=<ip-server-baru>
```

Lalu restart kedua sisi:

```bash
docker compose down
docker compose up -d --build
```

### B. Ganti IP publik client

Edit:

- `server/.env`
- opsional `client/.env`

Ubah di server:

```env
CLIENT_PUBLIC_IP=<ip-publik-client-baru>
```

Restart server dan client.

### C. Ganti IP lokal client

Edit:

- `client/.env`

Ubah:

```env
CLIENT_IFACE=<interface-client>
CLIENT_LOCAL_IP=<ip-lokal-client>
```

Pastikan IP tersebut muncul di:

```bash
ip addr show <interface-client>
```

### D. Ganti nama interface server

Edit:

- `server/.env`

Ubah:

```env
SERVER_IFACE=<nama-interface-server>
```

Jika sebelumnya menjalankan sysctl manual, ulangi:

```bash
sudo sysctl -w net.ipv4.conf.<nama-interface-server>.rp_filter=0
```

### E. Ganti port UDP

Edit:

- `server/.env`
- `client/.env`

Ubah:

```env
FOU_PORT=<port-baru>
```

Buka firewall server:

```bash
sudo ufw allow <port-baru>/udp
```

Restart kedua sisi.

### F. Ganti IP tunnel P2P

Edit:

- `server/.env`
- `client/.env`

Contoh untuk tunnel baru `10.11.13.0/30`:

Server:

```env
TUNNEL_SERVER_ADDR=10.11.13.1/30
TUNNEL_CLIENT_PEER=10.11.13.2
```

Client:

```env
TUNNEL_CLIENT_ADDR=10.11.13.2/30
TUNNEL_SERVER_PEER=10.11.13.1
```

---

## 12. Restart dan Verifikasi

### Restart

Di folder server atau client masing-masing:

```bash
docker compose down
docker compose up -d --build
```

### Cek container

```bash
docker ps
```

### Cek log

Server:

```bash
docker compose logs -f fou-server
```

Client:

```bash
docker compose logs -f fou-client
```

Jika nama service sudah diubah, sesuaikan. Contoh:

```bash
docker compose logs -f fou-server-b
```

### Cek tunnel interface

```bash
ip addr show tun0
ip fou show
```

Atau jika memakai `tun1`:

```bash
ip addr show tun1
```

### Test ping tunnel

Dari server:

```bash
ping -c4 10.11.12.2
```

Dari client:

```bash
ping -c4 10.11.12.1
```

---

## 13. Test Speed dengan iperf3

Install di server dan client:

```bash
sudo apt-get update
sudo apt-get install -y iperf3
```

Di server:

```bash
iperf3 -s
```

Di client test upload:

```bash
iperf3 -c 10.11.12.1
```

Di client test download:

```bash
iperf3 -c 10.11.12.1 -R
```

Test UDP 100 Mbps:

```bash
iperf3 -c 10.11.12.1 -u -b 100M
```

Sesuaikan IP `10.11.12.1` dengan `TUNNEL_SERVER_PEER` untuk tunnel yang sedang diuji.

---

## 14. Troubleshooting

### Tunnel tidak muncul

Cek modul:

```bash
lsmod | grep -E '^fou|^ipip|^ip_gre'
```

Load ulang:

```bash
sudo modprobe fou
sudo modprobe ipip
sudo modprobe ip_gre
```

### Error karena nama tunnel bentrok

Jika menjalankan banyak tunnel di host yang sama, pastikan setiap tunnel memiliki:

```env
TUNNEL_IF=tun0/tun1/tun2/dst
FOU_PORT=5555/5556/5557/dst
```

Lalu pastikan `container_name` di `docker-compose.yml` berbeda.

### Port UDP bentrok

Cek FOU port aktif:

```bash
ip fou show
```

Cek UDP listener/traffic:

```bash
sudo ss -lunp | grep 5555
sudo tcpdump -i eth2 udp port 5555 -n
```

Ganti `eth2` dan `5555` sesuai konfigurasi.

### Ping tunnel gagal

Cek hal berikut:

1. `SERVER_IP` sama di server dan client.
2. `CLIENT_PUBLIC_IP` di server benar.
3. `FOU_PORT` sama di server dan client.
4. Firewall server membuka UDP port tersebut.
5. `CLIENT_LOCAL_IP` benar-benar ada di interface client.
6. `rp_filter` sudah `0` di interface fisik.
7. Keepalive client aktif jika client berada di belakang NAT/CGNAT.

Cek log:

```bash
docker compose logs --tail=100
```

### NAT/CGNAT sering putus

Turunkan interval keepalive:

```env
KEEPALIVE_INTERVAL=15
```

Restart client:

```bash
docker compose restart
```

---

## 15. Pola Aman untuk Banyak Tunnel

Gunakan pola berikut agar tidak bentrok:

| Instance | Folder | Service | Container | UDP Port | Tunnel IF | Tunnel Subnet |
|---|---|---|---|---:|---|---|
| 1 | `server-client-a` | `fou-server-a` | `fou-server-a` | `5555` | `tun0` | `10.11.12.0/30` |
| 2 | `server-client-b` | `fou-server-b` | `fou-server-b` | `5556` | `tun1` | `10.11.13.0/30` |
| 3 | `server-client-c` | `fou-server-c` | `fou-server-c` | `5557` | `tun2` | `10.11.14.0/30` |

Untuk setiap instance baru, pastikan unik:

```text
FOU_PORT
TUNNEL_IF
TUNNEL_SERVER_ADDR
TUNNEL_CLIENT_PEER
container_name
service name di docker-compose.yml
image name jika ingin rapi
```

---

## 16. Catatan Penting

- Tunnel tetap P2P: satu server endpoint berpasangan dengan satu client endpoint.
- Untuk banyak client, buat banyak instance tunnel.
- Untuk banyak server tujuan, buat banyak instance tunnel di client.
- Jangan memakai subnet tunnel yang sama untuk dua tunnel berbeda di host yang sama.
- Jangan memakai `TUNNEL_IF` yang sama untuk dua tunnel di host yang sama.
- Jangan memakai `FOU_PORT` yang sama untuk dua tunnel FOU berbeda di host yang sama, kecuali Anda benar-benar paham konsekuensi routing/encapsulation kernel.
- Bila client di belakang NAT/CGNAT, keepalive sebaiknya tetap aktif.
