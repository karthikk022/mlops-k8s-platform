import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('stress_errors');

const MODEL_URL = __ENV.MODEL_ENDPOINT || 'http://loan-default-predictor.mlops.svc.cluster.local:8080';

export const options = {
  stages: [
    { duration: '2m', target: 200 },
    { duration: '5m', target: 500 },
    { duration: '2m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(99)<5000'],
    http_req_failed: ['rate<0.10'],
  },
};

function generatePayload() {
  return JSON.stringify({
    inputs: Array.from({ length: 32 }, () => [
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
    ]),
  });
}

export default function () {
  const res = http.post(`${MODEL_URL}/v2/models/loan-default-predictor/infer`, generatePayload(), {
    headers: { 'Content-Type': 'application/json' },
    tags: { test: 'stress' },
  });

  const success = check(res, {
    'status is 200': (r) => r.status === 200,
  });

  errorRate.add(success ? 0 : 1);

  if (!success && res.status >= 429) {
    console.warn(`Rate limited at VU ${__VU}, iteration ${__ITER}`);
  }
}

export function handleSummary(data) {
  return {
    'stress-test-summary.json': JSON.stringify({
      max_vus: data.state.vusMax,
      total_requests: data.metrics.http_reqs.values.count,
      error_rate: data.metrics.http_req_failed.values.rate,
      p95_latency: data.metrics.http_req_duration.values['p(95)'],
      p99_latency: data.metrics.http_req_duration.values['p(99)'],
      avg_latency: data.metrics.http_req_duration.values.avg,
    }, null, 2),
  };
}
