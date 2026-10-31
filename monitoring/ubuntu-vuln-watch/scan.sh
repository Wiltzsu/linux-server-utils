#!/usr/bin/env bash
# ubuntu-vuln-watch — security watch for this host (email via build_email.py)
#
# Cron example (root):
#   30 7 * * * /path/to/ubuntu-vuln-watch/scan.sh >>/path/to/ubuntu-vuln-watch/scan.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="${SCRIPT_DIR}/run"
mkdir -p "$WORKDIR"

if [[ -f "${SCRIPT_DIR}/config.env" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/config.env"
else
  echo "Missing config.env — copy config.env.example and edit EMAIL_TO" >&2
  exit 1
fi

: "${EMAIL_TO:?Set EMAIL_TO in config.env}"
: "${USN_LOOKBACK_DAYS:=7}"
: "${MAIL_ONLY_ON_FINDINGS:=1}"
: "${USE_CURSOR_AI:=0}"
: "${CURSOR_MODEL:=composer-2.5}"
: "${DRY_RUN_EMAIL:=0}"

case "${EMAIL_TO}" in
  ""|CHANGE_ME|*@example.com|*@example.org)
    echo "Refusing to send mail to placeholder EMAIL_TO='${EMAIL_TO}'. Edit config.env." >&2
    exit 1
    ;;
esac

if [[ -z "${UBUNTU_CODENAME:-}" ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  UBUNTU_CODENAME="${VERSION_CODENAME}"
fi

HOST="$(hostname -f 2>/dev/null || hostname)"
STAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
LOCAL_REPORT="${WORKDIR}/local-${STAMP}.txt"
USN_JSON="${WORKDIR}/usns-${STAMP}.json"
FINDINGS="${WORKDIR}/findings-${STAMP}.txt"
EMAIL_PLAIN="${WORKDIR}/email-${STAMP}.txt"
EMAIL_HTML="${WORKDIR}/email-${STAMP}.html"
EMAIL_META="${WORKDIR}/email-${STAMP}.meta.json"
AI_OUT="${WORKDIR}/ai-${STAMP}.txt"

say() { printf '%s\n' "$*"; }
section() { printf '\n== %s ==\n' "$*"; }

{
  section "Host"
  say "host:        ${HOST}"
  say "when_utc:    ${STAMP}"
  say "codename:    ${UBUNTU_CODENAME}"
  say "pretty:      $(. /etc/os-release; echo "$PRETTY_NAME")"

  section "Kernel"
  say "running:     $(uname -r)"
  if command -v apt-cache >/dev/null; then
    say "virtual_pkg: $(apt-cache policy linux-image-virtual 2>/dev/null | awk '/Installed:/{i=$2} /Candidate:/{c=$2} END{print "installed="i" candidate="c}')"
  fi
  if [[ -f /var/run/reboot-required ]]; then
    say "reboot:      REQUIRED ($(cat /var/run/reboot-required.pkgs 2>/dev/null | tr '\n' ' '))"
  else
    say "reboot:      not flagged"
  fi

  section "Apt upgradable (may include non-security)"
  if apt-get update -qq >/dev/null 2>&1; then
    apt list --upgradable 2>/dev/null | sed '1d' || true
  else
    say "(apt-get update failed — using cached lists)"
    apt list --upgradable 2>/dev/null | sed '1d' || true
  fi

  section "Optional kernel mitigations (modprobe)"
  if [[ -f /etc/modprobe.d/disable-sctp.conf ]] || grep -Rqs 'install sctp' /etc/modprobe.d/ 2>/dev/null; then
    say "sctp:        blocked via modprobe"
  else
    say "sctp:        NOT blocked (relevant while CVE-2026-64564 is unfixed on noble)"
  fi
  if lsmod 2>/dev/null | grep -q '^sctp'; then
    say "sctp_loaded: yes"
  else
    say "sctp_loaded: no"
  fi
  if [[ -f /etc/modprobe.d/dirtyfrag.conf ]]; then
    say "dirtyfrag:   mitigation file present (obsolete if kernel >= 6.8.0-124)"
  fi
  if [[ -f /etc/modprobe.d/disable-algif_aead.conf ]]; then
    say "copyfail:    algif_aead mitigation file present (obsolete if kernel >= 6.8.0-117)"
  fi

  section "Ubuntu Pro hint"
  if command -v pro >/dev/null; then
    pro security-status 2>/dev/null | head -40 || true
  fi
} >"$LOCAL_REPORT"

python3 - "$UBUNTU_CODENAME" "$USN_LOOKBACK_DAYS" "$USN_JSON" <<'PY'
import json, sys, urllib.request
from datetime import datetime, timedelta, timezone

codename, days, out_path = sys.argv[1], int(sys.argv[2]), sys.argv[3]
cutoff = datetime.now(timezone.utc) - timedelta(days=days)
notices = []
offset = 0
limit = 20

while offset < 200:
    url = (
        "https://ubuntu.com/security/notices.json"
        f"?release={codename}&limit={limit}&offset={offset}"
    )
    req = urllib.request.Request(url, headers={"User-Agent": "ubuntu-vuln-watch/2.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.load(resp)
    batch = data.get("notices") or []
    if not batch:
        break
    stop = False
    for n in batch:
        pub = n["published"]
        if pub.endswith("Z"):
            pub = pub[:-1] + "+00:00"
        dt = datetime.fromisoformat(pub)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        if dt < cutoff:
            stop = True
            break
        notices.append(
            {
                "id": n.get("id"),
                "title": n.get("title"),
                "published": n.get("published"),
                "summary": (n.get("summary") or n.get("description") or "")[:400],
                "cves": n.get("cves") or [],
            }
        )
    if stop or len(batch) < limit:
        break
    offset += limit

with open(out_path, "w", encoding="utf-8") as f:
    json.dump({"codename": codename, "lookback_days": days, "notices": notices}, f, indent=2)
print(f"fetched {len(notices)} USNs for {codename} (last {days}d)")
PY

{
  section "Findings (log only — email uses build_email.py)"
  if [[ -f /var/run/reboot-required ]]; then
    say "[ACTION] Reboot required"
  fi
  if command -v apt-cache >/dev/null; then
    inst="$(apt-cache policy linux-image-virtual 2>/dev/null | awk '/Installed:/{print $2}')"
    cand="$(apt-cache policy linux-image-virtual 2>/dev/null | awk '/Candidate:/{print $2}')"
    if [[ -n "$inst" && -n "$cand" && "$inst" != "$cand" && "$inst" != "(none)" ]]; then
      say "[ACTION] linux-image-virtual: installed=$inst candidate=$cand"
    fi
  fi
  sec_count="$(apt list --upgradable 2>/dev/null | sed '1d' | grep -ci security || true)"
  say "Security-tagged upgradable: ${sec_count:-0}"
  upgradable_count="$(apt list --upgradable 2>/dev/null | sed '1d' | grep -c . || true)"
  say "All upgradable (incl. non-security): ${upgradable_count:-0}"
  if ! grep -Rqs 'install sctp' /etc/modprobe.d/ 2>/dev/null; then
    say "[WARN] SCTP not blocked (CVE-2026-64564 mitigation)"
  fi
  usn_count="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["notices"]))' "$USN_JSON")"
  say "Recent USNs (${USN_LOOKBACK_DAYS}d): ${usn_count}"
} | tee "$FINDINGS"

AI_ARG=()
if [[ "$USE_CURSOR_AI" == "1" ]]; then
  if [[ -z "${CURSOR_API_KEY:-}" ]]; then
    say "USE_CURSOR_AI=1 but CURSOR_API_KEY empty — skipping AI"
  elif python3 "${SCRIPT_DIR}/analyze_with_cursor.py" \
      --api-key "$CURSOR_API_KEY" \
      --model "$CURSOR_MODEL" \
      --local-report "$LOCAL_REPORT" \
      --findings "$FINDINGS" \
      --usn-json "$USN_JSON" \
      --out "$AI_OUT"; then
    AI_ARG=(--ai-file "$AI_OUT")
  else
    say "AI analysis failed — continuing without AI section"
  fi
fi

BUILD_ARGS=(--send)
if [[ "$DRY_RUN_EMAIL" == "1" ]]; then
  BUILD_ARGS=(--dry-run)
fi

python3 "${SCRIPT_DIR}/build_email.py" \
  --local-report "$LOCAL_REPORT" \
  --usn-json "$USN_JSON" \
  --host "$HOST" \
  --stamp "$STAMP" \
  --codename "$UBUNTU_CODENAME" \
  --out-plain "$EMAIL_PLAIN" \
  --out-html "$EMAIL_HTML" \
  --out-meta "$EMAIL_META" \
  --mail-only-on-findings "$MAIL_ONLY_ON_FINDINGS" \
  "${AI_ARG[@]}" \
  "${BUILD_ARGS[@]}" \
  --email-to "$EMAIL_TO" \
  ${EMAIL_FROM:+--email-from "$EMAIL_FROM"}

SUBJECT_DETAIL="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["subject_detail"])' "$EMAIL_META")"

if [[ "$DRY_RUN_EMAIL" == "1" ]]; then
  say "Preview: ${EMAIL_PLAIN} and ${EMAIL_HTML}"
fi

say "Subject: [vuln-watch] ${HOST}: ${SUBJECT_DETAIL}"
say "Artifacts in $WORKDIR"
say "Done."
