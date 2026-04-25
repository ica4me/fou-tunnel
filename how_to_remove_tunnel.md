# How to Remove FOU Tunnel

Panduan ini menjelaskan cara mematikan tunnel Docker dan menghapus total interface tunnel yang masih muncul di hasil perintah `ip a`.

> Jalankan perintah sebagai `root` atau gunakan `sudo`.

---

## 1. Masuk ke Folder Project

```bash
cd fou-tunnel
```

Jika project berada di lokasi lain, sesuaikan path foldernya.

---

## 2. Matikan Docker Compose

```bash
docker compose down
```

Perintah ini akan menghentikan dan menghapus container, network Docker Compose, serta resource default yang dibuat oleh Compose.

Jika ingin memastikan container benar-benar berhenti:

```bash
docker ps
docker ps -a
```

---

## 3. Matikan dan Hapus dengan Volume Opsional

Jika ingin menghapus container beserta volume yang dibuat Compose:

```bash
docker compose down -v
```

Jika image hasil build juga ingin dihapus:

```bash
docker compose down -v --rmi local
```

Jika ingin menghapus semua image yang terkait Compose, gunakan dengan hati-hati:

```bash
docker compose down -v --rmi all
```

---

## 4. Cek Interface Tunnel yang Masih Aktif

Lihat semua interface:

```bash
ip a
```

Atau filter interface tunnel tertentu, contoh:

```bash
ip a | grep -E "fou|tun|gre|gretap|ipip"
```

Contoh nama interface yang mungkin muncul:

```text
fou0
tun0
gre1
gretap1
ipip1
```

Nama interface sebenarnya tergantung konfigurasi `.env`, misalnya nilai:

```bash
TUNNEL_IF=
```

---

## 5. Hapus Interface Tunnel Secara Manual

Gunakan format berikut:

```bash
ip link delete NAMA_INTERFACE
```

Contoh:

```bash
ip link delete fou0
```

Atau jika nama interface-nya `tun0`:

```bash
ip link delete tun0
```

Jika muncul error seperti `Cannot find device`, berarti interface tersebut sudah tidak ada.

---

## 6. Hapus Beberapa Interface Sekaligus

Contoh jika ada banyak interface tunnel:

```bash
ip link delete fou0
ip link delete fou1
ip link delete tun0
ip link delete gre1
```

Sesuaikan nama interface dengan hasil dari:

```bash
ip a
```

---

## 7. Bersihkan Konfigurasi FOU / UDP Encapsulation

Cek konfigurasi FOU yang masih aktif:

```bash
ip fou show
```

Jika ada port FOU yang masih muncul, hapus dengan format:

```bash
ip fou del port PORT protocol 4
```

Contoh:

```bash
ip fou del port 5555 protocol 4
```

Jika menggunakan protocol lain, cek dulu hasil dari:

```bash
ip fou show
```

---

## 8. Bersihkan Route Tambahan Jika Ada

Cek route:

```bash
ip route
```

Jika ada route yang mengarah ke interface tunnel, hapus dengan format:

```bash
ip route del NETWORK/CIDR dev NAMA_INTERFACE
```

Contoh:

```bash
ip route del 10.11.12.0/30 dev fou0
```

Atau jika ada route default lewat tunnel:

```bash
ip route del default dev fou0
```

Gunakan perintah ini dengan hati-hati agar tidak memutus koneksi SSH.

---

## 9. Nonaktifkan IP Forwarding Jika Tidak Dibutuhkan

Jika sebelumnya mengaktifkan IP forwarding:

```bash
sysctl -w net.ipv4.ip_forward=1
```

Dan server tidak lagi digunakan untuk routing, bisa dimatikan:

```bash
sysctl -w net.ipv4.ip_forward=0
```

---

## 10. Kembalikan rp_filter Jika Sebelumnya Diubah

Jika sebelumnya menjalankan:

```bash
sysctl -w net.ipv4.conf.eth2.rp_filter=0
```

Kembalikan ke mode standar:

```bash
sysctl -w net.ipv4.conf.eth2.rp_filter=1
```

Sesuaikan `eth2` dengan nama interface publik server Anda.

Cek nama interface:

```bash
ip a
```

---

## 11. Verifikasi Akhir

Pastikan container sudah mati:

```bash
docker ps
```

Pastikan interface tunnel sudah hilang:

```bash
ip a
```

Pastikan FOU sudah bersih:

```bash
ip fou show
```

Pastikan route tunnel sudah hilang:

```bash
ip route
```

---

## 12. Perintah Cepat

Contoh perintah cepat untuk menghentikan Docker dan menghapus interface bernama `fou0`:

```bash
cd fou-tunnel
docker compose down -v
ip link delete fou0
ip fou show
ip route
ip a
```

Jika port FOU masih muncul, hapus manual:

```bash
ip fou del port 5555 protocol 4
```

---

## 13. Troubleshooting

### Interface masih muncul setelah Docker dimatikan

Hapus manual:

```bash
ip link delete NAMA_INTERFACE
```

### FOU port masih muncul

Cek:

```bash
ip fou show
```

Hapus:

```bash
ip fou del port PORT protocol 4
```

### Tidak tahu nama interface tunnel

Cek semua interface:

```bash
ip a
```

Atau cek konfigurasi project:

```bash
cat server/.env
cat client/.env
```

Cari nilai:

```bash
TUNNEL_IF=
FOU_PORT=
```

### Koneksi SSH putus setelah menghapus route

Kemungkinan route yang dihapus sedang dipakai untuk akses SSH. Hindari menghapus `default route` jika server sedang diakses dari jaringan tersebut.

---

## Catatan Penting

- `docker compose down` hanya menghapus resource Docker.
- Interface tunnel yang dibuat di host network kadang tetap tersisa di host.
- Interface tersebut harus dihapus manual dengan `ip link delete`.
- Port FOU yang masih aktif harus dibersihkan dengan `ip fou del`.
- Pastikan nama interface dan port sesuai dengan konfigurasi `.env`.
