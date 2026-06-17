#!/usr/bin/env bash
# Preflight checks for the Claude Code observability Docker stack.
# Verifies Docker is installed and running, compose is available, and the
# host ports the stack needs are free. Prints install guidance on failure.
set -euo pipefail

FAIL=0
PORTS=(3000 3100 4317 4318 8889 9090)

red()   { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }

echo "==> Preflight checks"

# --- Docker installed? ---
if ! command -v docker >/dev/null 2>&1; then
  red "    ✗ Docker is not installed."
  echo ""
  echo "    Install Docker Desktop for Mac (Apple Silicon):"
  echo "      brew install --cask docker"
  echo "      or download: https://www.docker.com/products/docker-desktop/"
  echo ""
  echo "    Then launch Docker Desktop and re-run 'make up'."
  exit 1
fi
green "    ✓ docker found ($(docker --version | awk '{print $3}' | tr -d ,))"

# --- Compose plugin available? ---
if ! docker compose version >/dev/null 2>&1; then
  red "    ✗ 'docker compose' (v2) is not available."
  echo "    Update Docker Desktop, or install the compose plugin."
  exit 1
fi
green "    ✓ docker compose found ($(docker compose version --short 2>/dev/null || echo v2))"

# --- Daemon running? ---
if ! docker info >/dev/null 2>&1; then
  red "    ✗ Docker daemon is not running."
  echo "    Start Docker Desktop (open -a Docker), wait for it to be ready, then re-run."
  exit 1
fi
green "    ✓ docker daemon is running"

# --- Ports free? ---
# A port already bound by OUR stack is fine; only flag foreign listeners.
for p in "${PORTS[@]}"; do
  pid="$(lsof -nP -iTCP:"$p" -sTCP:LISTEN -t 2>/dev/null | head -1 || true)"
  if [ -n "$pid" ]; then
    cmd="$(ps -p "$pid" -o comm= 2>/dev/null || echo '?')"
    if echo "$cmd" | grep -qiE 'docker|com.docker'; then
      yellow "    ! port $p in use by Docker ($cmd) — assuming this stack, OK"
    else
      red "    ✗ port $p is in use by '$cmd' (pid $pid) — free it before 'make up'"
      FAIL=1
    fi
  fi
done
[ "$FAIL" -eq 0 ] && green "    ✓ required host ports are free (or held by Docker)"

echo ""
if [ "$FAIL" -ne 0 ]; then
  red "==> Preflight failed. Resolve the issues above and retry."
  exit 1
fi
green "==> Preflight passed."
