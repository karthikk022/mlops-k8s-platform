#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0

green() { printf "\033[32m%s\033[0m\n" "$1"; }
red()   { printf "\033[31m%s\033[0m\n" "$1"; }

check() {
  local label="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    green "  PASS  $label"
  else
    red "  FAIL  $label"
    FAILED=1
  fi
}

echo ""
echo "=== Infrastructure Validation Tests ==="
echo ""

# ── Terraform files exist (validation is done in CI with `terraform validate`) ──
for env_dir in "$REPO_ROOT"/infrastructure/terraform/environments/*/; do
  env=$(basename "$env_dir")
  check "terraform files exist: $env" test -f "$env_dir/main.tf"
  check "terraform variables: $env"  test -f "$env_dir/variables.tf"
done

# ── Helm chart structure ──
for chart_dir in "$REPO_ROOT"/infrastructure/helm/*/; do
  chart=$(basename "$chart_dir")
  check "Chart.yaml exists in $chart" test -f "$chart_dir/Chart.yaml"
done

# ── Dockerfiles exist ──
check "Dockerfile: ml-pipeline/training"     test -f "$REPO_ROOT/ml-pipeline/training/Dockerfile"
check "Dockerfile: ml-pipeline/preprocessing" test -f "$REPO_ROOT/ml-pipeline/preprocessing/Dockerfile"
check "Dockerfile: ml-pipeline/evaluation"    test -f "$REPO_ROOT/ml-pipeline/evaluation/Dockerfile"
check "Dockerfile: serving/model-server"      test -f "$REPO_ROOT/serving/model-server/Dockerfile"

# ── Shell scripts have shebang ──
for dir in "$REPO_ROOT/scripts" "$REPO_ROOT/backup-dr/scripts"; do
  [ -d "$dir" ] || continue
  for script in "$dir"/*.sh; do
    [ -f "$script" ] || continue
    rel="${script#"$REPO_ROOT/"}"
    check "shebang: $rel" grep -qE '^#!' "$script"
  done
done

# ── Great Expectations: pipeline uses it ──
check "great_expectations in pipeline.py" grep -q "great_expectations" "$REPO_ROOT/ml-pipeline/pipeline.py"

echo ""
if [ "$FAILED" -eq 0 ]; then
  green "=== All infrastructure tests passed ==="
else
  red "=== Some infrastructure tests FAILED ==="
  exit 1
fi
