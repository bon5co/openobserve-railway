# OpenObserve for Railway.
#
# Upstream ships a distroless image with no shell, so a Railway start command
# cannot carry any boot logic. This wrapper puts the same pinned binary on a
# slim Debian base and adds an entrypoint that:
#   * honours Railway's injected $PORT (upstream always binds 5080),
#   * refuses to boot on a missing or policy-violating root password,
#   * re-applies the root credential on every boot, so a redeploy is a
#     working password reset.
FROM openobserve/openobserve:v0.92.2 AS upstream

FROM debian:13-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY --from=upstream /openobserve /openobserve
COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh \
 && /openobserve --version

# Single-node mode: embedded SQLite meta-store plus Parquet files, all under
# the mounted volume. Baked rather than published as template variables,
# because a literal default is dropped by templateGenerate and would publish
# as a blank required field.
ENV ZO_LOCAL_MODE=true \
    ZO_LOCAL_MODE_STORAGE=disk \
    ZO_DATA_DIR=/data \
    ZO_TELEMETRY=false \
    ZO_HTTP_IPV6_ENABLED=true

EXPOSE 5080
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
