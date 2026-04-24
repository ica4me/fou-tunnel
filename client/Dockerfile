FROM alpine:3.19

LABEL description="FOU Tunnel Client — eth2:172.16.3.200 publik:38.47.95.247"

RUN apk add --no-cache \
    iproute2 \
    iproute2-tc \
    iptables \
    ip6tables \
    bash \
    curl \
    iputils \
    procps \
    kmod

COPY entrypoint.sh   /usr/local/bin/entrypoint.sh
COPY healthcheck.sh  /usr/local/bin/healthcheck.sh
COPY keepalive.sh    /usr/local/bin/keepalive.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
             /usr/local/bin/healthcheck.sh \
             /usr/local/bin/keepalive.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
