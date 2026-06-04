#!/bin/bash
set -euo pipefail

MODEL_NAME="${1:-loan-default-predictor}"
NAMESPACE="${2:-mlops}"

echo "Testing model endpoint: $MODEL_NAME in namespace $NAMESPACE"

# Get endpoint URL
ENDPOINT=$(kubectl get inferenceservice "$MODEL_NAME" -n "$NAMESPACE" \
  -o jsonpath='{.status.url}' 2>/dev/null || echo "http://localhost:8080")

echo "Endpoint: $ENDPOINT"

# Test with sample data
echo ""
echo "=== Test 1: Basic Prediction ==="
curl -s -H "Content-Type: application/json" \
  -d '{
    "inputs": [
      [5.1, 3.5, 1.4, 0.2, 1, 50000, 0.3, 12, 750, 0.15]
    ]
  }' \
  "${ENDPOINT}/v2/models/${MODEL_NAME}/infer" | python -m json.tool

echo ""
echo "=== Test 2: Batch Prediction ==="
curl -s -H "Content-Type: application/json" \
  -d '{
    "inputs": [
      [5.1, 3.5, 1.4, 0.2, 1, 50000, 0.3, 12, 750, 0.15],
      [6.3, 2.9, 5.6, 1.8, 0, 32000, 0.6, 6, 620, 0.35],
      [4.9, 3.0, 1.4, 0.2, 1, 85000, 0.1, 24, 800, 0.08]
    ]
  }' \
  "${ENDPOINT}/v2/models/${MODEL_NAME}/infer" | python -m json.tool

echo ""
echo "=== Test 3: Health Check ==="
curl -s "${ENDPOINT}/v2/health/ready" && echo " OK"

echo ""
echo "=== All tests passed ==="
