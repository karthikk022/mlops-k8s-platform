import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('soak_errors');
const latencyP99 = new Trend('soak_latency_p99');

const MODEL_URL = __ENV.MODEL_ENDPOINT || 'http://loan-default-predictor.mlops.svc.cluster.local:8080';
const MLFLOW_URL = __ENV.MLFLOW_ENDPOINT || 'http://mlflow.mlops:5000';

export const options = {
  stages: [
    { duration: '5m', target: 20 },
    { duration: '60m', target: 20 },
    { duration: '5m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(99)<3000', 'p(95)<1500'],
    http_req_failed: ['rate<0.02'],
    soak_errors: ['rate<0.05'],
  },
};

export default function () {
  const payload = JSON.stringify({
    inputs: [[
      Math.random() * 10,
      Math.random() * 5,
      Math.random() * 7,
      Math.random() * 3,
      Math.floor(Math.random() * 2),
      Math.floor(Math.random() * 100000),
      Math.random(),
      Math.floor(Math.random() * 30),
      Math.floor(Math.random() * 850) + 350,
      Math.random(),
    ]],
  });

  const res = http.post(`${MODEL_URL}/v2/models/loan-default-predictor/infer`, payload, {
    headers: { 'Content-Type': 'application/json' },
  });

  const success = check(res, {
    'model serving ok': (r) => r.status === 200,
    'response valid': (r) => {
      try {
        return JSON.parse(r.body).predictions !== undefined;
      } catch { return false; }
    },
    'latency within bounds': (r) => r.timings.duration < 3000,
  });

  errorRate.add(success ? 0 : 1);

  if (__ITER % 20 === 0) {
    const healthRes = http.get(`${MLFLOW_URL}/health`);
    check(healthRes, { 'mlflow healthy during soak': (r) => r.status === 200 });
  }

  sleep(3);
}

export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: '  ', enableColors: true }),
    'soak-test-summary.json': JSON.stringify(data, null, 2),
  };
}

function textSummary(data, options) {
  const out = [];
  out.push('=== Soak Test Summary ===');
  out.push(`Duration: ${data.state.testRunDurationStr}`);
  out.push(`Total requests: ${data.metrics.http_reqs.values.count}`);
  out.push(`Error rate: ${(data.metrics.http_req_failed.values.rate * 100).toFixed(2)}%`);
  out.push(`p50 latency: ${data.metrics.http_req_duration.values.med.toFixed(0)}ms`);
  out.push(`p95 latency: ${data.metrics.http_req_duration.values['p(95)'].toFixed(0)}ms`);
  out.push(`p99 latency: ${data.metrics.http_req_duration.values['p(99)'].toFixed(0)}ms`);
  out.push(`Avg latency: ${data.metrics.http_req_duration.values.avg.toFixed(0)}ms`);
  out.push('=========================');
  return out.join('\n');
}
