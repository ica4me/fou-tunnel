#!/bin/bash
set -euo pipefail

# ══════════════════════════════════════════════
#  FOU TUNNEL — SERVER ENTRYPOINT
#  eth2: 202.10.48.182  (IP publik langsung)
#  Menerima koneksi dari client 38.47.95.247
# ══════════════════════════════════════════════

RED='\033[0;31m'; GREEN='\033[0;32m'
YEL='\033[1;33m'; CYN='\033[0;36m'; NC='\033[0m'

log()  { echo -e "${GREEN}[SERVER $(date '+%H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YEL}[WARN   $(date '+%H:%M:%S')]${NC} $*"; }
err()  { echo -e "${RED}[ERROR  $(date '+%H:%M:%S')]${NC} $*"; exit 1; }
info() { echo -e "${CYN}         →${NC} $*"; }

# ────────────────────────────────────────────
#  Validasi variabel wajib
# ────────────────────────────────────────────
[[ -z "${SERVER_IP}"         ]] && err "SERVER_IP tidak diset"
[[ -z "${CLIENT_PUBLIC_IP}"  ]] && err "CLIENT_PUBLIC_IP tidak diset"
[[ -z "${FOU_PORT}"          ]] && err "FOU_PORT tidak diset"

log "╔══════════════════════════════════════╗"
log "║  FOU Tunnel Server — Starting        ║"
log "╚══════════════════════════════════════╝"
info "Server interface : ${SERVER_IFACE}  →  ${SERVER_IP}"
info "Client public IP : ${CLIENT_PUBLIC_IP}"
info "FOU UDP port     : ${FOU_PORT}"
info "Tunnel interface : ${TUNNEL_IF}  (${TUNNEL_PROTO^^})"
info "Tunnel IP server : ${TUNNEL_SERVER_ADDR}"
info "Tunnel IP client : ${TUNNEL_CLIENT_PEER}"

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
sysctl -w net.ipv4.conf."${SERVER_IFACE}".rp_filter=0  >/dev/null 2>&1 || true
log "IP forwarding ON, rp_filter OFF"

# ────────────────────────────────────────────
#  Bersihkan konfigurasi lama
# ────────────────────────────────────────────
log "Cleaning previous config..."
ip link del "${TUNNEL_IF}" 2>/dev/null \
    && warn "removed stale ${TUNNEL_IF}" || true
ip fou del port "${FOU_PORT}" 2>/dev/null \
    && warn "removed stale FOU :${FOU_PORT}" || true
sleep 1

# ────────────────────────────────────────────
#  FOU listener
#  Server mendengarkan di 202.10.48.182:5555
# ────────────────────────────────────────────
log "Starting FOU listener UDP:${FOU_PORT} on ${SERVER_IP}..."
ip fou add port "${FOU_PORT}" ipproto "${IPPROTO}"
info "FOU listener aktif → UDP:${FOU_PORT} (ipproto ${IPPROTO})"

# ────────────────────────────────────────────
#  Buat tunnel IPIP/GRE over FOU
#
#  local  = IP server di eth2     → 202.10.48.182
#  remote = IP publik client      → 38.47.95.247
#
#  encap-sport = FOU_PORT (5555)  ← server reply port
#  encap-dport = FOU_PORT (5555)  ← tujuan di client
# ────────────────────────────────────────────
log "Creating ${TUNNEL_PROTO^^} tunnel ${SERVER_IP} ↔ ${CLIENT_PUBLIC_IP}..."

if [[ "${TUNNEL_PROTO}" == "gre" ]]; then
    ip link add name "${TUNNEL_IF}" type gre \
        local  "${SERVER_IP}"        \
        remote "${CLIENT_PUBLIC_IP}" \
        encap fou                    \
        encap-sport "${FOU_PORT}"    \
        encap-dport "${FOU_PORT}"
else
    # IPIP (default)
    ip link add name "${TUNNEL_IF}" type ipip \
        local  "${SERVER_IP}"        \
        remote "${CLIENT_PUBLIC_IP}" \
        encap fou                    \
        encap-sport "${FOU_PORT}"    \
        encap-dport "${FOU_PORT}"    \
        encap-csum
fi

# ────────────────────────────────────────────
#  Assign IP & bring up
# ────────────────────────────────────────────
ip addr add "${TUNNEL_SERVER_ADDR}" dev "${TUNNEL_IF}"
ip link set  "${TUNNEL_IF}" mtu 1472 up
log "Tunnel ${TUNNEL_IF} UP — IP: ${TUNNEL_SERVER_ADDR}"

# ────────────────────────────────────────────
#  iptables: izinkan traffic FOU masuk
# ────────────────────────────────────────────
iptables -I INPUT -i "${SERVER_IFACE}" -p udp --dport "${FOU_PORT}" \
    -s "${CLIENT_PUBLIC_IP}" -j ACCEPT 2>/dev/null \
    && info "iptables: UDP:${FOU_PORT} dari ${CLIENT_PUBLIC_IP} ← ACCEPT" \
    || warn "iptables rule mungkin sudah ada"

# ── Masquerade (opsional) ─────────────────────
if [[ "${ENABLE_MASQUERADE:-false}" == "true" ]]; then
    iptables -t nat -A POSTROUTING -o "${SERVER_IFACE}" -j MASQUERADE
    log "MASQUERADE aktif di ${SERVER_IFACE}"
fi

# ────────────────────────────────────────────
#  Status akhir
# ────────────────────────────────────────────
log "╔══════════════════════════════════════╗"
log "║  ✅  FOU Server READY                ║"
log "╚══════════════════════════════════════╝"
echo ""
ip addr show "${TUNNEL_IF}"
echo ""
ip fou show
echo ""

# ────────────────────────────────────────────
#  Cleanup handler
# ────────────────────────────────────────────
cleanup() {
    warn "Shutdown — cleaning up..."
    iptables -D INPUT -i "${SERVER_IFACE}" -p udp --dport "${FOU_PORT}" \
        -s "${CLIENT_PUBLIC_IP}" -j ACCEPT 2>/dev/null || true
    ip link del "${TUNNEL_IF}"  2>/dev/null || true
    ip fou  del port "${FOU_PORT}" 2>/dev/null || true
    log "Done."
    exit 0
}
trap cleanup SIGTERM SIGINT

# ────────────────────────────────────────────
#  Monitor loop
# ────────────────────────────────────────────
log "Monitoring... (interval 60s)"
while true; do
    sleep 60
    if ip link show "${TUNNEL_IF}" 2>/dev/null | grep -E -q "state (UP|UNKNOWN)"; then
        log "♥  ${TUNNEL_IF} UP  |  peer ${TUNNEL_CLIENT_PEER}"
        # Ping ke client peer untuk keepalive balik
        ping -c1 -W2 "${TUNNEL_CLIENT_PEER}" &>/dev/null \
            && info "ping ${TUNNEL_CLIENT_PEER} OK" \
            || warn "ping ${TUNNEL_CLIENT_PEER} MISS (client mungkin idle)"
    else
        warn "⚠  ${TUNNEL_IF} DOWN — attempting recovery..."
        ip link set "${TUNNEL_IF}" up 2>/dev/null || true
    fi
done
