# openobserve-railway

Wrapper image for deploying [OpenObserve](https://github.com/openobserve/openobserve)
(logs, metrics and traces in one place) on Railway.

Upstream `openobserve/openobserve` is a distroless image with no shell, so a
Railway start command cannot carry any boot logic. This wrapper copies the same
pinned `v0.92.2` binary onto `debian:13-slim` and adds an entrypoint that:

* **honours Railway's injected `$PORT`.** OpenObserve reads `ZO_HTTP_PORT` and
  ignores `PORT`, so a stock image binds 5080 while Railway's HTTP healthcheck
  dials the port it injected.
* **refuses to boot on an empty or policy-violating root password.**
  OpenObserve 0.92 requires 8-128 characters with a lowercase letter, an
  uppercase letter, a digit and a special character, and enforces it by
  panicking inside a background job: `ZO_ROOT_USER_PASSWORD is too weak`. A
  32-character alphanumeric generated secret does not satisfy it.
* **re-applies the root credential on every boot** via
  `openobserve reset -c root`, so a redeploy is a working password reset. On a
  stock image the account is created from the environment only on the first
  boot and changing the variable afterwards has no effect.

Single-node settings (`ZO_LOCAL_MODE`, `ZO_DATA_DIR=/data`, telemetry off) are
baked into the image rather than published as template variables, because
Railway's `templateGenerate` drops literal defaults and would publish them as
blank required fields.

Licence: OpenObserve is AGPL-3.0. This repository only wraps the published
binary.
