FROM alpine:3.19

LABEL description="FOU Tunnel Server — 202.10.48.182 (eth2 publik)"

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

COPY entrypoint.sh    /usr/local/bin/entrypoint.sh
COPY healthcheck.sh   /usr/local/bin/healthcheck.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
             /usr/local/bin/healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
