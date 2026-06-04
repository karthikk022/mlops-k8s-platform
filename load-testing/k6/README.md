# Load Testing

Validates model serving autoscaling, MLflow API performance, and feature store latency.

## Tests

| Test | File | Duration | Target VUs | Validates |
|------|------|----------|------------|-----------|
| Model Serving | `scripts/model-serving.js` | 23 min | 10→50→100 | Inference latency, error rate |
| MLflow API | `scripts/mlflow-api.js` | 6 min | 5→20 | API throughput |
| Feature Store | `scripts/feature-store.js` | 5 min | 10→50 | Feature retrieval latency |
| Soak Test | `scripts/soak-test.js` | 70 min | 20 constant | Memory leak, long-run stability |
| Stress Test | `scripts/stress-test.js` | 9 min | 200→500 | Breaking point, autoscaling limit |

## Thresholds

| Metric | Threshold | Trigger |
|--------|-----------|---------|
| P99 latency | < 2s | Model serving overload |
| P95 latency | < 1s | Performance degradation |
| Error rate | < 1% | Infrastructure issue |
| Avg latency | < 500ms | Healthy baseline |

## Run

```bash
# All tests
./load-testing/k6/config/run-load-tests.sh

# Single test
k6 run load-testing/k6/scripts/model-serving.js \
  -e MODEL_ENDPOINT=http://localhost:8080

# Stress test
k6 run load-testing/k6/scripts/stress-test.js \
  -e MODEL_ENDPOINT=http://localhost:8080
```

## What It Validates

- **HPA scaling**: under 100→500 concurrent VUs, does K8s HPA scale pods from 2→10?
- **KServe request queue**: does the inference server handle request buffering?
- **MLflow RDS connection pool**: does the DB handle concurrent experiment queries?
- **Feature store Redis cache**: does Feast serve cached features under load?
- **Memory leak detection**: soak test for 60 min reveals steady-state memory growth
