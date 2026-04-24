# FOU Tunnel over Docker — Alpine
### Foo-over-UDP | Server ↔ Client (behind CGNAT/NAT)

---

## Topologi

```
┌─────────────────────────────────────────────────────────────┐
│  CLIENT (behind NAT/CGNAT)                                  │
│                                                             │
│  eth2: 172.16.3.200  ──►  NAT  ──►  38.47.95.247 (publik)  │
│                                                             │
│  ┌─────────────────────┐                                    │
│  │   fou-client        │  bind local: 172.16.3.200          │
│  │   Alpine            │  encap-sport: 5555 (fixed)         │
│  │   tun0: 10.10.10.2  │  encap-dport: 5555                 │
│  └─────────────────────┘                                    │
└─────────────────┬───────────────────────────────────────────┘
                  │  UDP:5555  (IPIP-in-UDP / FOU)
                  │  Paket dari: 38.47.95.247:5555 (post-NAT)
                  ▼
┌─────────────────────────────────────────────────────────────┐
│  SERVER (IP Publik Langsung)                                │
│                                                             │
│  eth2: 202.10.48.182  ← IP publik di interface              │
│                                                             │
│  ┌─────────────────────┐                                    │
│  │   fou-server        │  FOU listener UDP:5555             │
│  │   Alpine            │  local:  202.10.48.182             │
│  │   tun0: 10.10.10.1  │  remote: 38.47.95.247              │
│  └─────────────────────┘                                    │
└─────────────────────────────────────────────────────────────┘

Tunnel virtual:
  Server  10.10.10.1/30
  Client  10.10.10.2/30
```

---

## Kenapa `local` Client = 172.16.3.200 bukan 38.47.95.247?

| IP | Keterangan |
|---|---|
| `172.16.3.200` | IP nyata di interface eth2 — bisa di-bind |
| `38.47.95.247` | IP publik hasil NAT/CGNAT — **tidak ada di interface** |

Client hanya bisa bind ke IP yang ada di interface-nya sendiri.  
Router/CGNAT yang menerjemahkan `172.16.3.200:5555` → `38.47.95.247:5555`.

---

## Prasyarat Host (kedua sisi)

```bash
# 1. Load modul kernel di HOST (bukan di container)
sudo modprobe fou
sudo modprobe ipip

# Auto-load saat boot
echo -e "fou\nipip" | sudo tee /etc/modules-load.d/fou.conf

# 2. IP forwarding
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

---

## Deploy Server (202.10.48.182)

```bash
cd fou-tunnel/server/

# Buka port UDP di firewall
sudo ufw allow 5555/udp
# Atau iptables:
# iptables -I INPUT -p udp --dport 5555 -s 38.47.95.247 -j ACCEPT

# Build & jalankan
docker compose up -d --build

# Cek log
docker compose logs -f fou-server
```

---

## Deploy Client (172.16.3.200)

```bash
cd fou-tunnel/client/

# Build & jalankan
docker compose up -d --build

# Cek log
docker compose logs -f fou-client
```

---

## Verifikasi

```bash
# ── Di server ──────────────────────────────
# Lihat tunnel interface
docker exec fou-server ip addr show tun0
docker exec fou-server ip fou show

# Ping ke client peer
docker exec fou-server ping -c4 10.10.10.2

# ── Di client ──────────────────────────────
# Ping ke server peer
docker exec fou-client ping -c4 10.10.10.1

# Cek keepalive berjalan
docker exec fou-client ps aux | grep keepalive

# ── Health status ──────────────────────────
docker inspect --format='{{.State.Health.Status}}' fou-server
docker inspect --format='{{.State.Health.Status}}' fou-client
```

---

## Konfigurasi .env Ringkas

### Server `.env`

| Variable | Nilai | Keterangan |
|---|---|---|
| `SERVER_IFACE` | `eth2` | Interface publik server |
| `SERVER_IP` | `202.10.48.182` | IP publik server |
| `CLIENT_PUBLIC_IP` | `38.47.95.247` | IP publik client (post-NAT) |
| `FOU_PORT` | `5555` | UDP port FOU |
| `TUNNEL_SERVER_ADDR` | `10.10.10.1/30` | IP virtual server |
| `ENABLE_MASQUERADE` | `false` | NAT untuk routing internet |

### Client `.env`

| Variable | Nilai | Keterangan |
|---|---|---|
| `CLIENT_IFACE` | `eth2` | Interface lokal client |
| `CLIENT_LOCAL_IP` | `172.16.3.200` | IP lokal (di-bind) |
| `CLIENT_PUBLIC_IP` | `38.47.95.247` | Info saja, tidak di-bind |
| `SERVER_IP` | `202.10.48.182` | Tujuan tunnel |
| `FOU_PORT` | `5555` | UDP port FOU |
| `TUNNEL_CLIENT_ADDR` | `10.10.10.2/30` | IP virtual client |
| `KEEPALIVE_INTERVAL` | `20` | Detik antar ping (< 30!) |

---

## CGNAT — Kenapa Keepalive Wajib?

```
CGNAT NAT table:
  172.16.3.200:5555  →  38.47.95.247:5555
  (entry ini hilang setelah ~30 detik tanpa traffic)

Solusi: kirim UDP/ping setiap 20 detik
  → NAT entry tetap hidup
  → Server bisa balas ke 38.47.95.247:5555
```

---

## Enable Full Routing (Opsional)

Jika ingin semua traffic client lewat VPS:

```bash
# client/.env
ADD_DEFAULT_ROUTE=true

# server/.env
ENABLE_MASQUERADE=true
```

---

## Troubleshooting

**Module tidak ter-load:**
```bash
lsmod | grep -E "^fou|^ipip"
# Jika kosong:
sudo modprobe fou && sudo modprobe ipip
```

**Tunnel UP tapi ping gagal:**
```bash
# Cek rp_filter di host server
sysctl net.ipv4.conf.eth2.rp_filter
# Harus 0
sudo sysctl -w net.ipv4.conf.eth2.rp_filter=0
```

**CGNAT drop koneksi terus:**
```bash
# Turunkan KEEPALIVE_INTERVAL ke 15 di client .env
# Lalu restart:
docker compose restart fou-client
```

**Lihat paket UDP masuk di server:**
```bash
sudo tcpdump -i eth2 udp port 5555 -n
# Harusnya terlihat traffic dari 38.47.95.247
```
