#!/usr/bin/env python3
"""Optional Cursor SDK step: turn scan artifacts into a short ops email section.

Install once (venv recommended, from your install directory):
  python3 -m venv .venv
  . .venv/bin/activate
  pip install cursor-sdk

This uses your Cursor plan usage (same pools as the IDE), tagged SDK in the dashboard.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path


PROMPT = """You are helping an Ubuntu server operator.

Below is a deterministic scan from ONE host. Interpret it for email:
- What actually needs fixing on THIS host (be specific).
- What can be ignored (e.g. USNs for aws/azure/tegra kernels if this host is generic/virtual).
- Exact next commands if useful (apt, reboot, modprobe blacklist) — no exploit details.
- If nothing important: say so in one sentence.

Keep it under ~25 lines. Plain text only.
"""


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--api-key", default=os.environ.get("CURSOR_API_KEY", ""))
    p.add_argument("--model", default="composer-2.5")
    p.add_argument("--local-report", type=Path, required=True)
    p.add_argument("--findings", type=Path, required=True)
    p.add_argument("--usn-json", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    args = p.parse_args()

    if not args.api_key:
        print("missing API key", file=sys.stderr)
        return 1

    try:
        from cursor_sdk import Agent, AgentOptions, LocalAgentOptions
    except ImportError:
        print(
            "cursor_sdk not installed. Create a venv and: pip install cursor-sdk",
            file=sys.stderr,
        )
        return 1

    bundle = (
        PROMPT
        + "\n\n=== findings ===\n"
        + args.findings.read_text(encoding="utf-8")
        + "\n\n=== local report ===\n"
        + args.local_report.read_text(encoding="utf-8")
        + "\n\n=== recent USNs JSON ===\n"
        + args.usn_json.read_text(encoding="utf-8")[:12000]
    )

    # One-shot: create agent, prompt, get text, exit.
    # local cwd is the script dir so the agent has a workspace; we already
    # inlined the reports in the prompt so it does not need to hunt files.
    result = Agent.prompt(
        bundle,
        AgentOptions(
            api_key=args.api_key,
            model=args.model,
            local=LocalAgentOptions(cwd=str(Path(__file__).resolve().parent)),
        ),
    )

    text = getattr(result, "result", None) or getattr(result, "text", None) or str(result)
    args.out.write_text(str(text).strip() + "\n", encoding="utf-8")
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
