#!/bin/bash
IF="${TUNNEL_IF:-tun0}"
PEER="${TUNNEL_SERVER_PEER:-10.10.10.1}"

# Cek interface UP
ip link show "$IF" 2>/dev/null | grep -E -q "state (UP|UNKNOWN)" || {
    echo "FAIL: $IF DOWN"; exit 1
}

# Cek ping ke server peer
ping -c1 -W3 -I "$IF" "$PEER" &>/dev/null || {
    echo "FAIL: $PEER unreachable via $IF"; exit 1
}

echo "OK: $IF UP, $PEER reachable"
exit 0
