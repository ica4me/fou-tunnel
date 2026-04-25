# How to Add Route via FOU Tunnel

Panduan ini menjelaskan cara menambahkan dan menghapus route dari **server** menuju network yang berada di belakang **client** melalui IP tunnel client.

Contoh topologi:

```text
SERVER
  IP tunnel server: 10.11.12.1
        |
        | FOU / tunnel P2P
        |
CLIENT
  IP tunnel client: 10.11.12.2
  LAN/NAT di belakang client:
    - 172.16.1.0/24
    - 10.10.10.0/24
```

Tujuan:

```text
Server dapat mengakses network 172.16.1.0/24 dan 10.10.10.0/24 lewat IP tunnel client 10.11.12.2
```

> Jalankan perintah sebagai `root` atau gunakan `sudo`.

---

## 1. Cek IP Tunnel

Di server:

```bash
ip a
```

Pastikan IP tunnel server aktif, misalnya:

```text
10.11.12.1
```

Di client:

```bash
ip a
```

Pastikan IP tunnel client aktif, misalnya:

```text
10.11.12.2
```

Test ping dari server ke IP tunnel client:

```bash
ping 10.11.12.2
```

Jika ping berhasil, tunnel P2P sudah aktif.

---

## 2. Menambahkan Route di Server

Tambahkan route di **server** agar traffic menuju network belakang client dikirim lewat IP tunnel client `10.11.12.2`.

### Route ke 172.16.1.0/24

```bash
ip route add 172.16.1.0/24 via 10.11.12.2
```

### Route ke 10.10.10.0/24

```bash
ip route add 10.10.10.0/24 via 10.11.12.2
```

Cek hasilnya:

```bash
ip route
```

Atau cek spesifik:

```bash
ip route get 172.16.1.1
ip route get 10.10.10.1
```

Jika benar, hasilnya akan menunjukkan traffic keluar lewat gateway:

```text
via 10.11.12.2
```

---

## 3. Menambahkan Route dengan Nama Interface

Jika route via IP gateway tidak bekerja, bisa tambahkan route dengan interface tunnel.

Format:

```bash
ip route add NETWORK/CIDR dev NAMA_INTERFACE
```

Contoh jika nama interface tunnel adalah `fou0`:

```bash
ip route add 172.16.1.0/24 dev fou0
ip route add 10.10.10.0/24 dev fou0
```

Atau gabungan via gateway dan interface:

```bash
ip route add 172.16.1.0/24 via 10.11.12.2 dev fou0
ip route add 10.10.10.0/24 via 10.11.12.2 dev fou0
```

Cek nama interface:

```bash
ip a
```

---

## 4. Aktifkan IP Forwarding di Client

Agar client bisa meneruskan traffic dari tunnel ke network belakangnya, aktifkan IP forwarding di client:

```bash
sysctl -w net.ipv4.ip_forward=1
```

Cek statusnya:

```bash
sysctl net.ipv4.ip_forward
```

Hasil yang benar:

```text
net.ipv4.ip_forward = 1
```

---

## 5. Tambahkan Route Balik di Network Belakang Client

Agar koneksi bisa dua arah, host di belakang client harus tahu cara kembali ke network tunnel/server.

Ada dua pilihan:

1. Tambahkan route balik di router LAN belakang client.
2. Gunakan NAT/MASQUERADE di client.

---

## 6. Opsi A: Tambahkan Route Balik di Router LAN Client

Jika router LAN belakang client bisa dikonfigurasi, tambahkan route berikut di router tersebut:

```text
Destination: 10.11.12.0/30
Gateway: IP_LAN_CLIENT
```

Contoh jika IP LAN client adalah `172.16.1.10`:

```text
Destination: 10.11.12.0/30
Gateway: 172.16.1.10
```

Untuk network `10.10.10.0/24`, jika router berbeda, tambahkan juga route balik sesuai posisi client di network tersebut.

Ini adalah opsi yang lebih bersih karena tidak mengubah source IP.

---

## 7. Opsi B: Gunakan NAT di Client

Jika tidak bisa menambahkan route balik di router LAN, gunakan NAT di client.

Misalnya interface LAN client adalah `eth1`.

Cek nama interface LAN:

```bash
ip a
```

Tambahkan NAT untuk traffic dari tunnel menuju LAN `172.16.1.0/24`:

```bash
iptables -t nat -A POSTROUTING -s 10.11.12.0/30 -d 172.16.1.0/24 -o eth1 -j MASQUERADE
```

Tambahkan NAT untuk traffic dari tunnel menuju LAN `10.10.10.0/24`:

```bash
iptables -t nat -A POSTROUTING -s 10.11.12.0/30 -d 10.10.10.0/24 -o eth1 -j MASQUERADE
```

Cek rule NAT:

```bash
iptables -t nat -S
```

Catatan:

- Ganti `eth1` sesuai nama interface LAN client.
- NAT membuat host di belakang client melihat traffic berasal dari IP client, bukan dari IP tunnel server.
- Opsi ini praktis jika router belakang client tidak bisa diedit.

---

## 8. Menghapus Route di Server

Hapus route ke `172.16.1.0/24`:

```bash
ip route del 172.16.1.0/24 via 10.11.12.2
```

Hapus route ke `10.10.10.0/24`:

```bash
ip route del 10.10.10.0/24 via 10.11.12.2
```

Jika sebelumnya route dibuat dengan interface:

```bash
ip route del 172.16.1.0/24 dev fou0
ip route del 10.10.10.0/24 dev fou0
```

Jika sebelumnya route dibuat dengan gateway dan interface:

```bash
ip route del 172.16.1.0/24 via 10.11.12.2 dev fou0
ip route del 10.10.10.0/24 via 10.11.12.2 dev fou0
```

Cek hasilnya:

```bash
ip route
```

---

## 9. Menghapus NAT di Client

Lihat rule NAT:

```bash
iptables -t nat -S
```

Hapus rule NAT sesuai rule yang pernah ditambahkan.

Contoh:

```bash
iptables -t nat -D POSTROUTING -s 10.11.12.0/30 -d 172.16.1.0/24 -o eth1 -j MASQUERADE
iptables -t nat -D POSTROUTING -s 10.11.12.0/30 -d 10.10.10.0/24 -o eth1 -j MASQUERADE
```

Pastikan rule sudah hilang:

```bash
iptables -t nat -S
```

---

## 10. Membuat Route Persisten Setelah Reboot

Perintah `ip route add` bersifat sementara dan akan hilang setelah reboot.

Agar route otomatis aktif setelah reboot, ada beberapa pilihan.

---

### Opsi A: Tambahkan ke Script Startup Project

Buat file script, misalnya:

```bash
nano add-routes.sh
```

Isi:

```bash
#!/bin/bash

ip route replace 172.16.1.0/24 via 10.11.12.2
ip route replace 10.10.10.0/24 via 10.11.12.2
```

Buat executable:

```bash
chmod +x add-routes.sh
```

Jalankan manual:

```bash
./add-routes.sh
```

Gunakan `replace` agar aman dijalankan berulang kali.

---

### Opsi B: Tambahkan ke `/etc/rc.local`

Jika sistem masih menggunakan `rc.local`, tambahkan:

```bash
ip route replace 172.16.1.0/24 via 10.11.12.2
ip route replace 10.10.10.0/24 via 10.11.12.2
```

---

### Opsi C: Gunakan systemd Service

Buat service:

```bash
nano /etc/systemd/system/fou-routes.service
```

Isi:

```ini
[Unit]
Description=Add routes for FOU tunnel
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/sbin/ip route replace 172.16.1.0/24 via 10.11.12.2
ExecStart=/sbin/ip route replace 10.10.10.0/24 via 10.11.12.2
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Aktifkan:

```bash
systemctl daemon-reload
systemctl enable fou-routes.service
systemctl start fou-routes.service
```

Cek status:

```bash
systemctl status fou-routes.service
```

---

## 11. Contoh Lengkap di Server

Jalankan di server:

```bash
ip route replace 172.16.1.0/24 via 10.11.12.2
ip route replace 10.10.10.0/24 via 10.11.12.2

ip route get 172.16.1.1
ip route get 10.10.10.1
```

Test koneksi:

```bash
ping 172.16.1.1
ping 10.10.10.1
```

Jika host tujuan membuka port tertentu, bisa test dengan:

```bash
nc -vz 172.16.1.1 80
nc -vz 10.10.10.1 22
```

---

## 12. Contoh Lengkap di Client dengan NAT

Jalankan di client:

```bash
sysctl -w net.ipv4.ip_forward=1

iptables -t nat -A POSTROUTING -s 10.11.12.0/30 -d 172.16.1.0/24 -o eth1 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.11.12.0/30 -d 10.10.10.0/24 -o eth1 -j MASQUERADE
```

Ganti `eth1` dengan interface LAN client yang benar.

---

## 13. Troubleshooting

### Server tidak bisa ping 10.11.12.2

Tunnel belum aktif atau konfigurasi IP tunnel salah.

Cek:

```bash
ip a
docker ps
docker compose logs
```

---

### Server bisa ping 10.11.12.2, tetapi tidak bisa ping 172.16.1.1

Kemungkinan penyebab:

- Route di server belum ditambahkan.
- IP forwarding di client belum aktif.
- Firewall client memblokir forwarding.
- Host `172.16.1.1` tidak mengizinkan ICMP.
- Belum ada route balik dari LAN ke tunnel.
- NAT di client belum dibuat.

Cek:

```bash
ip route
sysctl net.ipv4.ip_forward
iptables -t nat -S
iptables -S
```

---

### Bisa ping dari server ke LAN, tetapi tidak bisa akses service

Kemungkinan service tujuan tidak listen atau firewall menolak koneksi.

Cek dari client:

```bash
ping 172.16.1.1
nc -vz 172.16.1.1 80
nc -vz 172.16.1.1 22
```

---

### Route sudah ada dan muncul error `File exists`

Gunakan `replace`:

```bash
ip route replace 172.16.1.0/24 via 10.11.12.2
ip route replace 10.10.10.0/24 via 10.11.12.2
```

---

### Menghapus semua route yang lewat IP tunnel client

Lihat route:

```bash
ip route | grep 10.11.12.2
```

Hapus satu per satu sesuai hasil:

```bash
ip route del 172.16.1.0/24 via 10.11.12.2
ip route del 10.10.10.0/24 via 10.11.12.2
```

---

## 14. Ringkasan Perintah Utama

Di server:

```bash
ip route replace 172.16.1.0/24 via 10.11.12.2
ip route replace 10.10.10.0/24 via 10.11.12.2
```

Hapus route di server:

```bash
ip route del 172.16.1.0/24 via 10.11.12.2
ip route del 10.10.10.0/24 via 10.11.12.2
```

Di client:

```bash
sysctl -w net.ipv4.ip_forward=1
```

NAT di client jika tidak ada route balik:

```bash
iptables -t nat -A POSTROUTING -s 10.11.12.0/30 -d 172.16.1.0/24 -o eth1 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.11.12.0/30 -d 10.10.10.0/24 -o eth1 -j MASQUERADE
```

Hapus NAT:

```bash
iptables -t nat -D POSTROUTING -s 10.11.12.0/30 -d 172.16.1.0/24 -o eth1 -j MASQUERADE
iptables -t nat -D POSTROUTING -s 10.11.12.0/30 -d 10.10.10.0/24 -o eth1 -j MASQUERADE
```

---

## Catatan Penting

- Route dari server ke network belakang client memakai gateway IP tunnel client, contoh `10.11.12.2`.
- Client harus mengaktifkan IP forwarding.
- Agar koneksi balik berhasil, gunakan salah satu:
  - route balik di router LAN belakang client, atau
  - NAT/MASQUERADE di client.
- Gunakan `ip route replace` untuk konfigurasi yang aman dijalankan ulang.
- Jangan menghapus default route saat sedang mengakses server via SSH.
