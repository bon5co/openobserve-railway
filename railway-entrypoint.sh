#!/bin/sh
# Boot wrapper for OpenObserve on Railway.
set -eu

log() { echo "[railway-entrypoint] $*"; }

# --- port -------------------------------------------------------------------
# OpenObserve reads ZO_HTTP_PORT and ignores $PORT, so a stock image always
# binds 5080 while Railway's HTTP healthcheck dials the port it injected.
ZO_HTTP_PORT="${PORT:-5080}"
export ZO_HTTP_PORT
log "listening on ${ZO_HTTP_PORT}"

# --- credentials ------------------------------------------------------------
if [ -z "${ZO_ROOT_USER_EMAIL:-}" ]; then
  log "FATAL: ZO_ROOT_USER_EMAIL is empty. OpenObserve panics at boot without a root user."
  exit 1
fi
if [ -z "${ZO_ROOT_USER_PASSWORD:-}" ]; then
  log "FATAL: ZO_ROOT_USER_PASSWORD is empty. OpenObserve panics at boot without a root user."
  exit 1
fi

# OpenObserve 0.92 rejects a password that is not 8-128 characters with at
# least one lowercase letter, one uppercase letter, one digit and one special
# character, and the rejection is a panic in a background job rather than a
# readable error. Fail here instead, with a message that names the rule.
pw="${ZO_ROOT_USER_PASSWORD}"
pw_len=$(printf '%s' "$pw" | wc -c)
weak=""
[ "$pw_len" -ge 8 ] || weak="${weak} length>=8"
printf '%s' "$pw" | grep -q '[a-z]' || weak="${weak} lowercase"
printf '%s' "$pw" | grep -q '[A-Z]' || weak="${weak} uppercase"
printf '%s' "$pw" | grep -q '[0-9]' || weak="${weak} digit"
printf '%s' "$pw" | grep -q '[^A-Za-z0-9]' || weak="${weak} special-character"
if [ -n "$weak" ]; then
  log "FATAL: ZO_ROOT_USER_PASSWORD does not satisfy OpenObserve's password policy (missing:${weak})."
  exit 1
fi

# --- data dir ---------------------------------------------------------------
mkdir -p "${ZO_DATA_DIR}"

# --- credential rotation ----------------------------------------------------
# The root account is created from the environment only on the very first boot.
# Changing the variable afterwards does nothing on a stock image, so a deployer
# who loses the password has no recovery path (reset is an emailed link and a
# fresh deploy has no SMTP). Re-apply it on every later boot instead.
if [ -f "${ZO_DATA_DIR}/db/metadata.sqlite" ]; then
  log "existing meta-store found; re-applying root credential"
  if /openobserve reset -c root; then
    log "root credential re-applied"
  else
    log "WARNING: could not re-apply the root credential; the previous one still applies"
  fi
else
  log "fresh volume; root user will be created from the environment"
fi

exec /openobserve "$@"
