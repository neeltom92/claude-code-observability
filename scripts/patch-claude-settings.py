#!/usr/bin/env python3
"""Patch (or revert) Claude Code's OTEL env vars in ~/.claude/settings.json.

Points Claude Code at the local OTEL collector (http://127.0.0.1:4318) so
metrics and events flow into the Docker stack.

Usage:
    python3 patch-claude-settings.py            # add/update OTEL env vars
    python3 patch-claude-settings.py --revert   # remove the OTEL env vars
"""
import json
import os
import sys

SETTINGS = os.path.expanduser("~/.claude/settings.json")

WANTED = {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_LOGS_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://127.0.0.1:4318",
    "OTEL_METRICS_ENABLED": "true",
    # Adds tool/skill names and input args (incl. Bash command lines) to
    # tool_result events, powering the Skills Usage dashboard. These are
    # stored only in your local Loki. Remove this key to disable event detail.
    "OTEL_LOG_TOOL_DETAILS": "1",
}


def load():
    os.makedirs(os.path.dirname(SETTINGS), exist_ok=True)
    if not os.path.exists(SETTINGS):
        return {}
    with open(SETTINGS) as f:
        return json.load(f)


def save(cfg):
    with open(SETTINGS, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")


def patch():
    cfg = load()
    env = cfg.setdefault("env", {})
    changed = {k: v for k, v in WANTED.items() if env.get(k) != v}
    if changed:
        env.update(WANTED)
        save(cfg)
        print("    Updated OTEL env vars: " + ", ".join(sorted(changed)))
    else:
        print("    OTEL env vars already configured.")
    print("    NOTE: OTEL_LOG_TOOL_DETAILS=1 stores tool/skill names and input")
    print("    args (incl. Bash command lines) in your local Loki (loopback only).")


def revert():
    cfg = load()
    env = cfg.get("env", {})
    removed = [k for k in WANTED if k in env]
    for k in removed:
        del env[k]
    if not env:
        cfg.pop("env", None)
    save(cfg)
    if removed:
        print("    Removed OTEL env vars: " + ", ".join(sorted(removed)))
    else:
        print("    No OTEL env vars to remove.")


if __name__ == "__main__":
    if "--revert" in sys.argv:
        revert()
    else:
        patch()
