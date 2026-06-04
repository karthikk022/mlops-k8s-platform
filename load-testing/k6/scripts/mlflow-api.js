import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate } from 'k6/metrics';

const apiErrors = new Rate('mlflow_api_errors');
const MLFLOW_URL = __ENV.MLFLOW_ENDPOINT || 'http://mlflow.mlops:5000';

export const options = {
  stages: [
    { duration: '1m', target: 5 },
    { duration: '3m', target: 20 },
    { duration: '2m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(99)<500', 'p(95)<300', 'avg<200'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  group('MLflow API', function () {
    const params = { headers: { 'Accept': 'application/json' } };

    const expRes = http.get(`${MLFLOW_URL}/api/2.0/mlflow/experiments/list`, params);
    check(expRes, { 'experiments list ok': (r) => r.status === 200 });
    apiErrors.add(expRes.status !== 200 ? 1 : 0);

    const modelRes = http.get(`${MLFLOW_URL}/api/2.0/mlflow/registered-models/list`, params);
    check(modelRes, { 'models list ok': (r) => r.status === 200 });
    apiErrors.add(modelRes.status !== 200 ? 1 : 0);

    const healthRes = http.get(`${MLFLOW_URL}/health`, params);
    check(healthRes, { 'health ok': (r) => r.status === 200 });
    apiErrors.add(healthRes.status !== 200 ? 1 : 0);
  });

  sleep(1);
}
