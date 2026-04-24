#!/bin/bash
# ══════════════════════════════════════════════
#  KEEPALIVE — Kritis untuk CGNAT
#
#  CGNAT (Carrier-grade NAT) menghapus UDP mapping
#  setelah ~30 detik idle. Script ini mengirim ping
#  berkala agar NAT state tetap hidup.
#
#  172.16.3.200 → NAT(38.47.95.247) → 202.10.48.182
# ══════════════════════════════════════════════

PEER="${TUNNEL_SERVER_PEER:-10.11.12.1}"
INTERVAL="${KEEPALIVE_INTERVAL:-20}"
IF="${TUNNEL_IF:-tun0}"

echo "[KEEPALIVE] Start — ping ${PEER} via ${IF} every ${INTERVAL}s"

FAIL=0
while true; do
    if ping -c1 -W3 -I "${IF}" "${PEER}" &>/dev/null; then
        FAIL=0
        echo "[KEEPALIVE] ♥ $(date '+%H:%M:%S')  ${PEER} OK"
    else
        FAIL=$((FAIL + 1))
        echo "[KEEPALIVE] ✗ $(date '+%H:%M:%S')  ${PEER} MISS (fail ${FAIL})"
        if [[ $FAIL -ge 5 ]]; then
            echo "[KEEPALIVE] ⚠ 5 consecutive fails — tunnel mungkin broken"
            FAIL=0
        fi
    fi
    sleep "${INTERVAL}"
done
