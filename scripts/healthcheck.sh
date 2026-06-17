#!/usr/bin/env bash
# Health check for the Claude Code observability stack.
# Probes each service on its host-mapped port and reports per-service status.
# Standalone: works whether or not the stack was started by this Makefile.
#
# Usage:
#   healthcheck.sh           # one-shot report
#   healthcheck.sh --wait    # poll up to ~60s for everything to come up
set -uo pipefail

WAIT=0
[ "${1:-}" = "--wait" ] && WAIT=1

red()   { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }

# name|url|match  — match is a substring expected in a healthy response ('' = any 2xx)
check_one() {
  local name="$1" url="$2" match="$3"
  local body
  if body="$(curl -sf --max-time 3 "$url" 2>/dev/null)"; then
    if [ -z "$match" ] || echo "$body" | grep -q "$match"; then
      green "    ✓ $name"
      return 0
    fi
  fi
  red "    ✗ $name  ($url)"
  return 1
}

run_checks() {
  local fails=0
  check_one "OTEL Collector (:8889 prom exporter)" "http://127.0.0.1:8889/metrics" "" || fails=$((fails+1))
  check_one "Prometheus      (:9090)"              "http://127.0.0.1:9090/-/healthy" "" || fails=$((fails+1))
  check_one "Loki            (:3100)"              "http://127.0.0.1:3100/ready" "ready" || fails=$((fails+1))
  check_one "Grafana         (:3000)"              "http://127.0.0.1:3000/api/health" "ok" || fails=$((fails+1))
  return "$fails"
}

echo "==> Service health"

if [ "$WAIT" -eq 1 ]; then
  # Poll up to ~60s; Loki's ingester needs ~15s after start.
  # Print progress dots so the wait doesn't look frozen.
  printf "    waiting for services"
  for _ in $(seq 1 20); do
    if out="$(run_checks)"; then
      printf "\n"; echo "$out"; green "==> All services healthy."; exit 0
    fi
    printf "."
    sleep 3
  done
  printf "\n"
  echo "$out"
  red "==> Some services did not become healthy in time."
  echo "    Inspect logs:  make logs"
  exit 1
fi

if out="$(run_checks)"; then
  echo "$out"
  green "==> All services healthy."
  exit 0
else
  echo "$out"
  red "==> Some services are down."
  echo "    Start the stack:  make up"
  echo "    Or inspect logs:  make logs"
  exit 1
fi
