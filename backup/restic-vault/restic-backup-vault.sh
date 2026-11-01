#!/bin/bash
set -euo pipefail

ENV_FILE="${RESTIC_ENV_FILE:-/etc/restic/vault.env}"
LOG_FILE="${RESTIC_LOG_FILE:-/var/log/restic-vault.log}"
LOCK_FILE="${RESTIC_LOCK_FILE:-/run/restic-vault.lock}"

KEEP_DAILY="${RESTIC_KEEP_DAILY:-7}"
KEEP_WEEKLY="${RESTIC_KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${RESTIC_KEEP_MONTHLY:-6}"

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

if [[ ! -r "$ENV_FILE" ]]; then
  log "Missing or unreadable $ENV_FILE (copy vault.env.example and edit on the server)" >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

if [[ -z "${RESTIC_REPOSITORY:-}" || "$RESTIC_REPOSITORY" == *'uXXXXX'* ]]; then
  log "Set RESTIC_REPOSITORY in $ENV_FILE before running backups" >&2
  exit 1
fi

if [[ -n "${RESTIC_PASSWORD_FILE:-}" && ! -r "$RESTIC_PASSWORD_FILE" ]]; then
  log "RESTIC_PASSWORD_FILE is not readable: $RESTIC_PASSWORD_FILE" >&2
  exit 1
fi

if [[ -z "${RESTIC_PASSWORD:-}" && -z "${RESTIC_PASSWORD_FILE:-}" ]]; then
  log "Set RESTIC_PASSWORD_FILE or RESTIC_PASSWORD in $ENV_FILE" >&2
  exit 1
fi

BACKUP_PATHS_RAW="${RESTIC_BACKUP_PATHS:-/var/backups/db}"
read -r -a BACKUP_PATHS <<< "$BACKUP_PATHS_RAW"

for path in "${BACKUP_PATHS[@]}"; do
  if [[ ! -e "$path" ]]; then
    log "Backup path does not exist: $path" >&2
    exit 1
  fi
done

TAGS_RAW="${RESTIC_BACKUP_TAGS:-scheduled,db}"
IFS=',' read -r -a TAG_ARR <<< "$TAGS_RAW"
TAG_ARGS=()
for t in "${TAG_ARR[@]}"; do
  t="${t#"${t%%[![:space:]]*}"}"
  t="${t%"${t##*[![:space:]]}"}"
  [[ -n "$t" ]] && TAG_ARGS+=(--tag "$t")
done

BACKUP_HOST="${RESTIC_BACKUP_HOST:-}"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "Another restic run is in progress; exiting"
  exit 0
fi

{
  log "Starting restic backup (${BACKUP_PATHS[*]})"
  if [[ -n "$BACKUP_HOST" ]]; then
    restic backup "${BACKUP_PATHS[@]}" --host "$BACKUP_HOST" "${TAG_ARGS[@]}"
  else
    restic backup "${BACKUP_PATHS[@]}" "${TAG_ARGS[@]}"
  fi
  log "Applying retention (daily=$KEEP_DAILY weekly=$KEEP_WEEKLY monthly=$KEEP_MONTHLY)"
  restic forget \
    --keep-daily "$KEEP_DAILY" \
    --keep-weekly "$KEEP_WEEKLY" \
    --keep-monthly "$KEEP_MONTHLY" \
    --prune
  if [[ "${RESTIC_RUN_CHECK:-0}" == "1" ]]; then
    log "Running restic check"
    restic check
  fi
  log "Done"
} >>"$LOG_FILE" 2>&1
