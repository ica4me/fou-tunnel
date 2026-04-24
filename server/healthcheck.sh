#!/bin/bash
IF="${TUNNEL_IF:-tun0}"
PEER="${TUNNEL_CLIENT_PEER:-10.10.10.2}"

ip link show "$IF" 2>/dev/null | grep -E -q "state (UP|UNKNOWN)" \
    && exit 0 || exit 1
