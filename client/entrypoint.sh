#!/bin/bash
set -euo pipefail

# ══════════════════════════════════════════════
#  FOU TUNNEL — CLIENT ENTRYPOINT
#
#  eth2 lokal   : 172.16.3.200
#  IP publik    : 38.47.95.247  (NAT/CGNAT keluar)
#  Server tujuan: 202.10.48.182
#
#  Catatan CGNAT:
#  - Client TIDAK bind ke 38.47.95.247 (bukan milik interface)
#  - Client bind ke 172.16.3.200 (eth2 lokal)
#  - Paket keluar di-NAT ke 38.47.95.247 oleh router
#  - Keepalive WAJIB agar NAT mapping tidak expire
# ══════════════════════════════════════════════

RED='\033[0;31m'; GREEN='\033[0;32m'
YEL='\033[1;33m'; CYN='\033[0;36m'; NC='\033[0m'

log()  { echo -e "${GREEN}[CLIENT $(date '+%H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YEL}[WARN   $(date '+%H:%M:%S')]${NC} $*"; }
err()  { echo -e "${RED}[ERROR  $(date '+%H:%M:%S')]${NC} $*"; exit 1; }
info() { echo -e "${CYN}         →${NC} $*"; }

# ────────────────────────────────────────────
#  Validasi
# ────────────────────────────────────────────
[[ -z "${SERVER_IP}"       ]] && err "SERVER_IP tidak diset"
[[ -z "${CLIENT_LOCAL_IP}" ]] && err "CLIENT_LOCAL_IP tidak diset"
[[ -z "${FOU_PORT}"        ]] && err "FOU_PORT tidak diset"

log "╔══════════════════════════════════════╗"
log "║  FOU Tunnel Client — Starting        ║"
log "╚══════════════════════════════════════╝"
info "Client interface : ${CLIENT_IFACE}  →  ${CLIENT_LOCAL_IP}"
info "Client publik    : ${CLIENT_PUBLIC_IP}  (via NAT/CGNAT)"
info "Server target    : ${SERVER_IP}:${FOU_PORT}"
info "Tunnel interface : ${TUNNEL_IF}  (${TUNNEL_PROTO^^})"
info "Tunnel IP client : ${TUNNEL_CLIENT_ADDR}"
info "Tunnel IP server : ${TUNNEL_SERVER_PEER}"
info "Keepalive        : ${ENABLE_KEEPALIVE} (${KEEPALIVE_INTERVAL}s)"

# ────────────────────────────────────────────
#  Tunggu interface eth2 dan koneksi ke server
# ────────────────────────────────────────────
log "Waiting for ${CLIENT_IFACE} (${CLIENT_LOCAL_IP})..."
for i in $(seq 1 15); do
    if ip addr show "${CLIENT_IFACE}" 2>/dev/null \
            | grep -q "${CLIENT_LOCAL_IP}"; then
        log "✓ ${CLIENT_IFACE} ready"
        break
    fi
    warn "  attempt ${i}/15 — interface belum ready..."
    sleep 2
done

log "Testing route to server ${SERVER_IP}..."
for i in $(seq 1 10); do
    if ping -c1 -W3 "${SERVER_IP}" &>/dev/null; then
        log "✓ ${SERVER_IP} reachable"
        break
    fi
    warn "  attempt ${i}/10 — server belum reachable..."
    sleep 3
done

# ────────────────────────────────────────────
#  Load kernel modules
# ────────────────────────────────────────────
log "Loading kernel modules..."
modprobe fou    2>/dev/null && info "fou    ✓" || warn "fou already loaded"
modprobe ipip   2>/dev/null && info "ipip   ✓" || warn "ipip already loaded"
modprobe ip_gre 2>/dev/null && info "ip_gre ✓" || warn "ip_gre already loaded"

# ────────────────────────────────────────────
#  Sysctl
# ────────────────────────────────────────────
sysctl -w net.ipv4.ip_forward=1                        >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.all.rp_filter=0                >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf."${CLIENT_IFACE}".rp_filter=0  >/dev/null 2>&1 || true
log "IP forwarding ON"

# ────────────────────────────────────────────
#  Bersihkan konfigurasi lama
# ────────────────────────────────────────────
log "Cleaning previous config..."
ip link del "${TUNNEL_IF}"    2>/dev/null && warn "removed stale ${TUNNEL_IF}" || true
ip fou  del port "${FOU_PORT}" 2>/dev/null && warn "removed stale FOU :${FOU_PORT}" || true
sleep 1

# ────────────────────────────────────────────
#  FOU encapsulation config
# ────────────────────────────────────────────
log "Configuring FOU encapsulation..."
ip fou add port "${FOU_PORT}" ipproto "${IPPROTO}"
info "FOU UDP:${FOU_PORT} siap (ipproto ${IPPROTO})"

# ────────────────────────────────────────────
#  Buat tunnel IPIP/GRE over FOU
#
#  local        = IP lokal eth2  → 172.16.3.200
#                 (BUKAN 38.47.95.247 — itu IP NAT, bukan interface)
#  remote       = IP server      → 202.10.48.182
#
#  encap-sport  = FOU_PORT (5555) — fixed agar NAT mapping stabil
#  encap-dport  = FOU_PORT (5555) — port server
# ────────────────────────────────────────────
log "Creating ${TUNNEL_PROTO^^} tunnel ${CLIENT_LOCAL_IP} → ${SERVER_IP}..."

if [[ "${TUNNEL_PROTO}" == "gre" ]]; then
    ip link add name "${TUNNEL_IF}" type gre \
        local  "${CLIENT_LOCAL_IP}" \
        remote "${SERVER_IP}"       \
        encap fou                   \
        encap-sport "${FOU_PORT}"   \
        encap-dport "${FOU_PORT}"
else
    # IPIP (default)
    ip link add name "${TUNNEL_IF}" type ipip \
        local  "${CLIENT_LOCAL_IP}" \
        remote "${SERVER_IP}"       \
        encap fou                   \
        encap-sport "${FOU_PORT}"   \
        encap-dport "${FOU_PORT}"   \
        encap-csum
fi

# ────────────────────────────────────────────
#  Assign IP & bring up
# ────────────────────────────────────────────
ip addr add "${TUNNEL_CLIENT_ADDR}" dev "${TUNNEL_IF}"
ip link set  "${TUNNEL_IF}" mtu 1472 up
log "Tunnel ${TUNNEL_IF} UP — IP: ${TUNNEL_CLIENT_ADDR}"

# ────────────────────────────────────────────
#  Custom routes (opsional)
# ────────────────────────────────────────────
if [[ -n "${ADD_CUSTOM_ROUTES:-}" ]]; then
    log "Adding custom routes via tunnel..."
    IFS=',' read -ra ROUTES <<< "${ADD_CUSTOM_ROUTES}"
    for route in "${ROUTES[@]}"; do
        route="${route// /}"
        ip route add "${route}" via "${TUNNEL_SERVER_PEER}" dev "${TUNNEL_IF}" 2>/dev/null \
            && info "route ${route} ✓" \
            || warn "route ${route} already exists"
    done
fi

if [[ "${ADD_DEFAULT_ROUTE:-false}" == "true" ]]; then
    warn "Adding DEFAULT route via tunnel (semua traffic → VPS)"
    ip route replace default via "${TUNNEL_SERVER_PEER}" dev "${TUNNEL_IF}"
    log "✓ Default route via ${TUNNEL_IF}"
fi

# ────────────────────────────────────────────
#  Test koneksi
# ────────────────────────────────────────────
log "Testing tunnel to server peer ${TUNNEL_SERVER_PEER}..."
sleep 2
if ping -c3 -W3 "${TUNNEL_SERVER_PEER}" &>/dev/null; then
    log "✅ Ping ${TUNNEL_SERVER_PEER} SUCCESS — tunnel aktif!"
else
    warn "⚠  Ping ${TUNNEL_SERVER_PEER} FAILED"
    warn "   Kemungkinan: server belum terima paket pertama (normal di CGNAT)"
    warn "   Keepalive akan terus mencoba..."
fi

# ────────────────────────────────────────────
#  Status
# ────────────────────────────────────────────
log "╔══════════════════════════════════════╗"
log "║  ✅  FOU Client READY                ║"
log "╚══════════════════════════════════════╝"
echo ""
ip addr show "${TUNNEL_IF}"
echo ""
ip fou show
echo ""

# ────────────────────────────────────────────
#  Cleanup
# ────────────────────────────────────────────
cleanup() {
    warn "Shutdown — cleaning up..."
    ip link del "${TUNNEL_IF}"    2>/dev/null || true
    ip fou  del port "${FOU_PORT}" 2>/dev/null || true
    log "Done."
    exit 0
}
trap cleanup SIGTERM SIGINT

# ────────────────────────────────────────────
#  Keepalive background — WAJIB untuk CGNAT
#  NAT mapping expire ~30 detik tanpa traffic
# ────────────────────────────────────────────
if [[ "${ENABLE_KEEPALIVE:-true}" == "true" ]]; then
    log "Starting keepalive ping every ${KEEPALIVE_INTERVAL}s → ${TUNNEL_SERVER_PEER}"
    /usr/local/bin/keepalive.sh &
    KEEPALIVE_PID=$!
    info "Keepalive PID: ${KEEPALIVE_PID}"
fi

# ────────────────────────────────────────────
#  Monitor loop
# ────────────────────────────────────────────
log "Monitoring tunnel (interval 30s)..."
FAIL_COUNT=0
while true; do
    sleep 30
    if ip link show "${TUNNEL_IF}" 2>/dev/null | grep -E -q "state (UP|UNKNOWN)"; then
        FAIL_COUNT=0
        log "♥  ${TUNNEL_IF} UP  |  $(date '+%Y-%m-%d %H:%M:%S')"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        warn "⚠  ${TUNNEL_IF} DOWN (fail #${FAIL_COUNT}) — attempting recovery..."
        ip link set "${TUNNEL_IF}" up 2>/dev/null || true
        if [[ $FAIL_COUNT -ge 3 ]]; then
            err "Tunnel down 3x berturut — container restart diperlukan"
        fi
    fi
done
