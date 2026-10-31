#!/usr/bin/env python3
"""Build a short plain + HTML vuln-watch email from scan artifacts."""

from __future__ import annotations

import argparse
import html
import json
import subprocess
import sys
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Report:
    host: str
    stamp: str
    codename: str
    pretty_name: str
    kernel_running: str
    reboot_required: bool
    reboot_pkgs: str
    sctp_blocked: bool
    sctp_loaded: bool
    security_upgradable: list[str] = field(default_factory=list)
    other_upgradable_count: int = 0
    other_upgradable_sample: list[str] = field(default_factory=list)
    usns_apply: list[dict] = field(default_factory=list)
    usns_skip: list[dict] = field(default_factory=list)
    actions: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    need_attention: bool = False
    subject_detail: str = "ok"

    def compute_attention(self) -> None:
        self.actions.clear()
        self.warnings.clear()

        if self.reboot_required:
            pkgs = self.reboot_pkgs.strip() or "kernel or related"
            self.actions.append(
                f"Reboot required — updates are installed but not active ({pkgs})."
            )

        if self.security_upgradable:
            n = len(self.security_upgradable)
            self.actions.append(
                f"{n} security-tagged package(s) can be upgraded now."
            )

        for u in self.usns_apply:
            if u.get("needs_upgrade"):
                self.actions.append(
                    f"{u['id']} ({u['title']}) — installed package(s) still upgradable."
                )

        if not self.sctp_blocked:
            self.warnings.append(
                "SCTP is not blacklisted (relevant while CVE-2026-64564 has no noble package fix)."
            )

        self.need_attention = bool(self.actions or self.warnings)

        if self.reboot_required and self.security_upgradable:
            self.subject_detail = "reboot + security updates"
        elif self.reboot_required:
            self.subject_detail = "reboot needed"
        elif self.security_upgradable:
            self.subject_detail = f"{len(self.security_upgradable)} security update(s)"
        elif any(u.get("needs_upgrade") for u in self.usns_apply):
            self.subject_detail = "USN packages need upgrade"
        elif self.usns_apply:
            self.subject_detail = f"{len(self.usns_apply)} USN(s) apply (review)"
        elif self.warnings:
            self.subject_detail = "review warnings"
        else:
            self.subject_detail = "ok"


def run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)


def installed_packages() -> set[str]:
    out = run(["dpkg-query", "-W", "-f=${Package}\n"])
    return {ln.strip() for ln in out.splitlines() if ln.strip()}


def upgradable_lines() -> list[str]:
    try:
        out = subprocess.check_output(
            ["apt", "list", "--upgradable"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        return []
    lines = out.strip().splitlines()
    if lines and lines[0].startswith("Listing"):
        lines = lines[1:]
    return [ln for ln in lines if ln.strip()]


def package_from_apt_line(line: str) -> str:
    return line.split("/", 1)[0].strip()


def is_security_line(line: str) -> bool:
    return "security" in line.lower()


def parse_local_report(text: str) -> dict:
    info: dict = {
        "host": "",
        "stamp": "",
        "codename": "",
        "pretty_name": "",
        "kernel_running": "",
        "reboot_required": False,
        "reboot_pkgs": "",
        "sctp_blocked": False,
        "sctp_loaded": False,
    }
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("host:"):
            info["host"] = line.split(":", 1)[1].strip()
        elif line.startswith("when_utc:"):
            info["stamp"] = line.split(":", 1)[1].strip()
        elif line.startswith("codename:"):
            info["codename"] = line.split(":", 1)[1].strip()
        elif line.startswith("pretty:"):
            info["pretty_name"] = line.split(":", 1)[1].strip()
        elif line.startswith("running:"):
            info["kernel_running"] = line.split(":", 1)[1].strip()
        elif line.startswith("reboot:"):
            val = line.split(":", 1)[1].strip()
            if val.upper().startswith("REQUIRED"):
                info["reboot_required"] = True
                info["reboot_pkgs"] = val.replace("REQUIRED", "", 1).strip(" ()")
        elif line.startswith("sctp:"):
            if "NOT blocked" in line:
                info["sctp_blocked"] = False
            elif "blocked" in line:
                info["sctp_blocked"] = True
        elif line.startswith("sctp_loaded:"):
            info["sctp_loaded"] = "yes" in line.lower()
    return info


def fetch_usn_detail(usn_id: str) -> dict | None:
    url = f"https://ubuntu.com/security/notices/{usn_id}.json"
    req = urllib.request.Request(url, headers={"User-Agent": "ubuntu-vuln-watch/2.0"})
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            return json.load(resp)
    except OSError:
        return None


def noble_packages_from_usn(detail: dict, codename: str) -> set[str]:
    rp = detail.get("release_packages") or {}
    pkgs = rp.get(codename) or []
    return {p["name"] for p in pkgs if p.get("name")}


def match_usns(
    notices: list[dict],
    codename: str,
    installed: set[str],
    upgradable_pkg: set[str],
) -> tuple[list[dict], list[dict]]:
    apply: list[dict] = []
    skip: list[dict] = []
    for n in notices:
        usn_id = n.get("id") or ""
        detail = fetch_usn_detail(usn_id)
        if not detail:
            skip.append({**n, "reason": "could not fetch USN detail"})
            continue
        usn_pkgs = noble_packages_from_usn(detail, codename)
        hit = sorted(installed & usn_pkgs)
        if not hit:
            skip.append({**n, "reason": "no affected packages installed"})
            continue
        needs = sorted(installed & usn_pkgs & upgradable_pkg)
        cves = detail.get("cves_ids") or []
        apply.append(
            {
                "id": usn_id,
                "title": n.get("title") or detail.get("title") or "",
                "published": n.get("published") or detail.get("published") or "",
                "packages_installed": hit[:8],
                "packages_more": max(0, len(hit) - 8),
                "needs_upgrade": bool(needs),
                "packages_upgradable": needs[:8],
                "cves": cves[:5],
                "url": f"https://ubuntu.com/security/notices/{usn_id}",
            }
        )
    return apply, skip


def plain_text(report: Report, ai_section: str | None) -> str:
    lines: list[str] = []
    lines.append(f"Ubuntu vuln-watch — {report.host}")
    lines.append(f"{report.pretty_name} · {report.codename} · {report.stamp} UTC")
    lines.append(f"Kernel running: {report.kernel_running}")
    lines.append("")

    if ai_section:
        lines.append("--- Summary (Cursor) ---")
        lines.append(ai_section.strip())
        lines.append("")

    lines.append("=== Do on this host ===")
    if report.actions:
        for a in report.actions:
            lines.append(f"• {a}")
        lines.append("")
        lines.append("Suggested:")
        if report.reboot_required:
            lines.append("  sudo reboot   # after you schedule a window")
        if report.security_upgradable or any(u.get("needs_upgrade") for u in report.usns_apply):
            lines.append("  sudo apt update && sudo apt upgrade -y")
    else:
        lines.append("Nothing urgent from this scan.")

    if report.warnings:
        lines.append("")
        lines.append("=== Warnings ===")
        for w in report.warnings:
            lines.append(f"• {w}")

    if report.security_upgradable:
        lines.append("")
        lines.append("=== Security upgrades (apt) ===")
        for ln in report.security_upgradable[:20]:
            lines.append(f"  {ln}")
        if len(report.security_upgradable) > 20:
            lines.append(f"  … and {len(report.security_upgradable) - 20} more")

    if report.usns_apply:
        lines.append("")
        lines.append("=== USNs that apply to installed packages ===")
        for u in report.usns_apply:
            flag = "UPGRADE" if u.get("needs_upgrade") else "installed OK / review"
            lines.append(f"  {u['id']}: {u['title']} [{flag}]")
            lines.append(f"    {u['url']}")
            if u.get("packages_installed"):
                lines.append(f"    packages: {', '.join(u['packages_installed'])}")
            if u.get("cves"):
                lines.append(f"    CVEs: {', '.join(u['cves'])}")

    if report.other_upgradable_count:
        lines.append("")
        lines.append(
            f"=== Other upgradable ({report.other_upgradable_count}, non-security) ==="
        )
        lines.append("Routine updates — unattended-upgrades may handle security; these are often PHP repo pins, mesa, snapd, etc.")
        for ln in report.other_upgradable_sample:
            lines.append(f"  {package_from_apt_line(ln)}")

    lines.append("")
    lines.append(f"Full scan artifacts: ~/scripts/ubuntu-vuln-watch/run/")
    return "\n".join(lines) + "\n"


def html_report(report: Report, ai_section: str | None) -> str:
    def esc(s: str) -> str:
        return html.escape(s, quote=True)

    action_items = "".join(
        f"<li>{esc(a)}</li>" for a in report.actions
    ) or "<li>Nothing urgent from this scan.</li>"
    warn_block = ""
    if report.warnings:
        warn_items = "".join(f"<li>{esc(w)}</li>" for w in report.warnings)
        warn_block = f"""
        <h2 style="margin:20px 0 8px;font-size:15px;color:#b45309;">Warnings</h2>
        <ul style="margin:0;padding-left:20px;color:#92400e;">{warn_items}</ul>
        """

    sec_rows = ""
    for ln in report.security_upgradable[:15]:
        sec_rows += f"<tr><td style='padding:4px 8px;font-family:monospace;font-size:12px;'>{esc(ln)}</td></tr>"

    sec_table = ""
    if sec_rows:
        sec_table = f"""
        <h2 style="margin:20px 0 8px;font-size:15px;">Security upgrades</h2>
        <table style="border-collapse:collapse;width:100%;background:#f8fafc;border:1px solid #e2e8f0;">
        {sec_rows}
        </table>
        """

    usn_cards = ""
    for u in report.usns_apply:
        badge = "#dc2626" if u.get("needs_upgrade") else "#059669"
        badge_text = "upgrade" if u.get("needs_upgrade") else "review"
        cves = ", ".join(u.get("cves") or [])
        usn_cards += f"""
        <div style="border:1px solid #e2e8f0;border-radius:8px;padding:12px;margin-bottom:10px;">
          <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;">
            <strong>{esc(u['id'])}</strong>
            <span style="background:{badge};color:#fff;font-size:11px;padding:2px 8px;border-radius:999px;">{badge_text}</span>
          </div>
          <div style="margin-top:6px;color:#334155;">{esc(u['title'])}</div>
          <div style="margin-top:6px;font-size:12px;color:#64748b;">Packages: {esc(', '.join(u.get('packages_installed') or []))}</div>
          {f'<div style="margin-top:4px;font-size:12px;color:#64748b;">CVEs: {esc(cves)}</div>' if cves else ''}
          <div style="margin-top:8px;"><a href="{esc(u['url'])}">{esc(u['url'])}</a></div>
        </div>
        """

    usn_block = ""
    if usn_cards:
        usn_block = f"""
        <h2 style="margin:20px 0 8px;font-size:15px;">USNs on this host</h2>
        {usn_cards}
        """

    ai_block = ""
    if ai_section:
        ai_block = f"""
        <div style="background:#eff6ff;border:1px solid #bfdbfe;border-radius:8px;padding:12px;margin:16px 0;">
          <div style="font-size:12px;font-weight:600;color:#1d4ed8;margin-bottom:8px;">Cursor summary</div>
          <pre style="white-space:pre-wrap;font-family:ui-monospace,monospace;font-size:12px;margin:0;color:#1e3a8a;">{esc(ai_section.strip())}</pre>
        </div>
        """

    cmd_block = ""
    if report.actions:
        cmds = []
        if report.security_upgradable or any(u.get("needs_upgrade") for u in report.usns_apply):
            cmds.append("sudo apt update && sudo apt upgrade -y")
        if report.reboot_required:
            cmds.append("sudo reboot   # schedule a maintenance window")
        cmd_block = f"""
        <pre style="background:#0f172a;color:#e2e8f0;padding:12px;border-radius:8px;font-size:12px;overflow-x:auto;">{esc(chr(10).join(cmds))}</pre>
        """

    other_note = ""
    if report.other_upgradable_count:
        sample = ", ".join(
            package_from_apt_line(ln) for ln in report.other_upgradable_sample
        )
        extra = report.other_upgradable_count - len(report.other_upgradable_sample)
        tail = f" (+{extra} more)" if extra > 0 else ""
        other_note = f"""
        <p style="font-size:12px;color:#64748b;margin-top:20px;">
          {report.other_upgradable_count} other non-security upgrades available ({esc(sample)}{tail}).
          Not listed in full — see server artifacts if needed.
        </p>
        """

    status_color = "#dc2626" if report.need_attention else "#059669"
    status_text = "Action suggested" if report.need_attention else "All clear"

    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="font-family:system-ui,-apple-system,Segoe UI,sans-serif;line-height:1.45;color:#0f172a;max-width:640px;margin:0 auto;padding:16px;">
  <div style="border-bottom:3px solid {status_color};padding-bottom:12px;margin-bottom:16px;">
    <div style="font-size:12px;color:#64748b;text-transform:uppercase;letter-spacing:.04em;">Ubuntu vuln-watch</div>
    <h1 style="margin:8px 0 4px;font-size:20px;">{esc(report.host)}</h1>
    <div style="font-size:13px;color:#475569;">{esc(report.pretty_name)} · kernel {esc(report.kernel_running)}</div>
    <div style="margin-top:8px;font-weight:600;color:{status_color};">{status_text}</div>
  </div>
  {ai_block}
  <h2 style="margin:0 0 8px;font-size:15px;">Do on this host</h2>
  <ul style="margin:0 0 12px;padding-left:20px;">{action_items}</ul>
  {cmd_block}
  {warn_block}
  {sec_table}
  {usn_block}
  {other_note}
  <p style="font-size:11px;color:#94a3b8;margin-top:24px;">Generated {esc(report.stamp)} UTC · artifacts in ~/scripts/ubuntu-vuln-watch/run/</p>
</body></html>
"""


def send_multipart(
    email_to: str,
    email_from: str | None,
    subject: str,
    plain: str,
    html_body: str,
) -> None:
    from email.mime.multipart import MIMEMultipart
    from email.mime.text import MIMEText
    from email.utils import formatdate

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["To"] = email_to
    msg["Date"] = formatdate(localtime=True)
    if email_from:
        msg["From"] = email_from
    msg.attach(MIMEText(plain, "plain", "utf-8"))
    msg.attach(MIMEText(html_body, "html", "utf-8"))

    subprocess.run(
        ["/usr/sbin/sendmail", "-t", "-oi"],
        input=msg.as_bytes(),
        check=True,
    )


def build_report(
    local_report_path: Path,
    usn_json_path: Path,
    host: str,
    stamp: str,
    codename: str,
) -> Report:
    local_text = local_report_path.read_text(encoding="utf-8")
    parsed = parse_local_report(local_text)
    usn_data = json.loads(usn_json_path.read_text(encoding="utf-8"))
    notices = usn_data.get("notices") or []

    installed = installed_packages()
    up_lines = upgradable_lines()
    upgradable_pkg = {package_from_apt_line(ln) for ln in up_lines}

    security = [ln for ln in up_lines if is_security_line(ln)]
    other = [ln for ln in up_lines if not is_security_line(ln)]

    usns_apply, usns_skip = match_usns(notices, codename, installed, upgradable_pkg)

    report = Report(
        host=host or parsed.get("host") or "host",
        stamp=stamp or parsed.get("stamp") or "",
        codename=codename or parsed.get("codename") or "",
        pretty_name=parsed.get("pretty_name") or "",
        kernel_running=parsed.get("kernel_running") or "",
        reboot_required=parsed.get("reboot_required", False),
        reboot_pkgs=parsed.get("reboot_pkgs") or "",
        sctp_blocked=parsed.get("sctp_blocked", False),
        sctp_loaded=parsed.get("sctp_loaded", False),
        security_upgradable=security,
        other_upgradable_count=len(other),
        other_upgradable_sample=[package_from_apt_line(ln) for ln in other[:6]],
        usns_apply=usns_apply,
        usns_skip=usns_skip,
    )
    report.compute_attention()
    return report


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--local-report", type=Path, required=True)
    p.add_argument("--usn-json", type=Path, required=True)
    p.add_argument("--host", required=True)
    p.add_argument("--stamp", required=True)
    p.add_argument("--codename", required=True)
    p.add_argument("--out-plain", type=Path, required=True)
    p.add_argument("--out-html", type=Path, required=True)
    p.add_argument("--out-meta", type=Path, required=True)
    p.add_argument("--ai-file", type=Path, default=None)
    p.add_argument("--send", action="store_true", help="Send via sendmail when allowed")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--mail-only-on-findings", type=int, default=1)
    p.add_argument("--email-to", default="")
    p.add_argument("--email-from", default="")
    args = p.parse_args()

    ai_section = None
    if args.ai_file and args.ai_file.is_file():
        ai_section = args.ai_file.read_text(encoding="utf-8")

    report = build_report(
        args.local_report,
        args.usn_json,
        args.host,
        args.stamp,
        args.codename,
    )

    plain = plain_text(report, ai_section)
    html_body = html_report(report, ai_section)

    args.out_plain.write_text(plain, encoding="utf-8")
    args.out_html.write_text(html_body, encoding="utf-8")
    meta = {
        "need_attention": report.need_attention,
        "subject_detail": report.subject_detail,
        "reboot_required": report.reboot_required,
        "security_upgradable_count": len(report.security_upgradable),
        "usns_apply_count": len(report.usns_apply),
        "other_upgradable_count": report.other_upgradable_count,
    }
    args.out_meta.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")

    subject = f"[vuln-watch] {report.host}: {report.subject_detail}"
    skip_mail = args.mail_only_on_findings == 1 and not report.need_attention

    if args.dry_run:
        if skip_mail:
            print("Dry-run: would skip mail (MAIL_ONLY_ON_FINDINGS, nothing actionable)")
        else:
            print(f"Dry-run: would send: {subject} → {args.email_to or '(no recipient)'}")
    elif args.send:
        if skip_mail:
            print("No actionable findings; skipping mail (MAIL_ONLY_ON_FINDINGS=1).")
        else:
            if not args.email_to:
                print("missing --email-to", file=sys.stderr)
                return 1
            send_multipart(
                args.email_to,
                args.email_from or None,
                subject,
                plain,
                html_body,
            )
            print(f"Mailed: {subject} → {args.email_to}")

    print(json.dumps(meta))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
