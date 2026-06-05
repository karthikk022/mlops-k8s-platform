#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "═══════════════════════════════════════════════"
echo "  MLOps K8s Platform — Test Suite"
echo "═══════════════════════════════════════════════"
echo ""

FAILED=0

run() {
  local label="$1"
  shift
  echo "── $label ──"
  if "$@" 2>&1 | sed 's/^/  /'; then
    echo ""
  else
    FAILED=1
  fi
}

run "YAML & JSON Validation"     python -m pytest tests/test_configs.py -v --tb=short
run "ML Pipeline Unit Tests"     python -m pytest tests/test_ml_pipeline.py -v --tb=short
run "Infrastructure Shell Tests" bash tests/test_infra.sh

echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "All tests passed."
else
  echo "Some tests FAILED."
  exit 1
fi
