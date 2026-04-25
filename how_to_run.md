# How to Run FOU Tunnel

Panduan ini menjelaskan cara menyiapkan Docker, menjalankan project `fou-tunnel`, mengaktifkan forwarding, serta melakukan pengujian kecepatan menggunakan `iperf3`.

## 1. Install Docker

Jalankan perintah berikut di server/client yang akan menjalankan tunnel:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

Pastikan Docker sudah terpasang:

```bash
docker --version
docker compose version
```

## 2. Install iperf3

`iperf3` digunakan untuk melakukan tes kecepatan antar endpoint tunnel.

```bash
apt-get install iperf3 -y
```

## 3. Clone Repository

```bash
git clone https://github.com/ica4me/fou-tunnel.git
cd fou-tunnel
```

## 4. Aktifkan IP Forwarding dan Nonaktifkan rp_filter

Jalankan perintah berikut pada host yang menjalankan tunnel:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.eth2.rp_filter=0
```

> Catatan:  
> Jika nama interface bukan `eth2`, ganti `eth2` sesuai nama interface pada server Anda.
>
> Cek nama interface dengan:
>
> ```bash
> ip link
> ```

Contoh jika interface Anda adalah `ens3`:

```bash
sudo sysctl -w net.ipv4.conf.ens3.rp_filter=0
```

## 5. Jalankan Docker Compose

Jika container sebelumnya sudah berjalan, hentikan dulu:

```bash
docker compose down
```

Build dan jalankan container:

```bash
docker compose up -d --build
```

Cek status container:

```bash
docker compose ps
```

Cek log container:

```bash
docker compose logs -f
```

## 6. Test Speed dengan iperf3

Contoh IP tunnel server pada panduan ini adalah:

```text
10.11.12.1
```

Sesuaikan IP tersebut jika konfigurasi tunnel Anda berbeda.

### 6.1 Jalankan iperf3 Server

Jalankan di sisi server:

```bash
iperf3 -s
```

### 6.2 Test Upload dari Client ke Server

Jalankan di sisi client:

```bash
iperf3 -c 10.11.12.1
```

### 6.3 Test Download dari Server ke Client

Jalankan di sisi client:

```bash
iperf3 -c 10.11.12.1 -R
```

### 6.4 Test Upload UDP 100 Mbps

Jalankan di sisi client:

```bash
iperf3 -c 10.11.12.1 -u -b 100M
```

## 7. Perintah Ringkas

Berikut versi singkat seluruh perintah utama:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

apt-get install iperf3 -y

git clone https://github.com/ica4me/fou-tunnel.git
cd fou-tunnel

sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.eth2.rp_filter=0

docker compose down
docker compose up -d --build
```

## 8. Catatan Penting

- Jika interface bukan `eth2`, ubah bagian berikut:

```bash
sudo sysctl -w net.ipv4.conf.eth2.rp_filter=0
```

menjadi sesuai interface aktif, misalnya:

```bash
sudo sysctl -w net.ipv4.conf.ens3.rp_filter=0
```

- Jika IP tunnel server bukan `10.11.12.1`, ubah perintah test `iperf3` sesuai IP tunnel server.
- Untuk menjalankan di beda server, pastikan konfigurasi `.env` pada sisi server dan client sudah disesuaikan dengan IP publik, IP tunnel, interface, dan port UDP masing-masing.
