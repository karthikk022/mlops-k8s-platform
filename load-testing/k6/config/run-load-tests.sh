#!/bin/bash
set -euo pipefail

NAMESPACE="${1:-mlops}"
REPORT_DIR="${2:-load-testing/reports}"

mkdir -p "$REPORT_DIR"

echo "=== MLOps Platform Load Tests ==="

echo ""
echo "1. Port-forward model serving endpoint..."
kubectl port-forward -n "$NAMESPACE" svc/loan-default-predictor 8080:8080 &
PF_PID=$!
sleep 3

echo ""
echo "2. Running model serving load test..."
k6 run load-testing/k6/scripts/model-serving.js \
  -e MODEL_ENDPOINT=http://localhost:8080 \
  --out json="$REPORT_DIR/model-serving-results.json" \
  --summary-export="$REPORT_DIR/model-serving-summary.json"

echo ""
echo "3. Running MLflow API test..."
kubectl port-forward -n "$NAMESPACE" svc/mlflow 5000:5000 &
PF_MLFLOW=$!
sleep 2

k6 run load-testing/k6/scripts/mlflow-api.js \
  -e MLFLOW_ENDPOINT=http://localhost:5000 \
  --out json="$REPORT_DIR/mlflow-api-results.json"

echo ""
echo "4. Running feature store test..."
kubectl port-forward -n "$NAMESPACE" svc/feast-feature-server 6566:6566 &
PF_FEAST=$!
sleep 2

k6 run load-testing/k6/scripts/feature-store.js \
  -e FEAST_ENDPOINT=http://localhost:6566 \
  --out json="$REPORT_DIR/feature-store-results.json"

echo ""
echo "5. Running soak test (60 min)..."
k6 run load-testing/k6/scripts/soak-test.js \
  -e MODEL_ENDPOINT=http://localhost:8080 \
  --out json="$REPORT_DIR/soak-test-results.json"

echo ""
echo "=== Load tests complete ==="
echo "Reports saved to $REPORT_DIR/"

kill $PF_PID $PF_MLFLOW $PF_FEAST 2>/dev/null || true
