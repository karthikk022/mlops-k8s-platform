import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

const modelErrors = new Rate('model_errors');
const predictionLatency = new Trend('prediction_latency');
const successfulPredictions = new Counter('successful_predictions');

const BASE_URL = __ENV.MODEL_ENDPOINT || 'http://loan-default-predictor.mlops.svc.cluster.local:8080';

export const options = {
  stages: [
    { duration: '2m', target: 10 },    // Ramp up
    { duration: '5m', target: 50 },    // Normal load
    { duration: '3m', target: 100 },   // Peak load
    { duration: '10m', target: 100 },  // Sustained peak
    { duration: '3m', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(99)<2000', 'p(95)<1000', 'avg<500'],
    http_req_failed: ['rate<0.01'],
    model_errors: ['rate<0.05'],
  },
};

function generateSample() {
  return [
    Math.random() * 10,       // sepal_length
    Math.random() * 5,        // sepal_width
    Math.random() * 7,        // petal_length
    Math.random() * 3,        // petal_width
    Math.floor(Math.random() * 2),  // binary_feature
    Math.floor(Math.random() * 100000),  // income
    Math.random(),             // ratio
    Math.floor(Math.random() * 30),  // tenure
    Math.floor(Math.random() * 850) + 350,  // credit_score
    Math.random(),             // debt_ratio
  ];
}

export default function () {
  group('Model Serving Inference', function () {
    const payload = JSON.stringify({
      inputs: [generateSample()],
    });

    const params = {
      headers: {
        'Content-Type': 'application/json',
      },
      tags: { endpoint: 'predict' },
    };

    const start = Date.now();
    const res = http.post(`${BASE_URL}/v2/models/loan-default-predictor/infer`, payload, params);
    const duration = Date.now() - start;

    predictionLatency.add(duration);

    const success = check(res, {
      'status is 200': (r) => r.status === 200,
      'response has predictions': (r) => r.json('predictions') !== undefined,
      'response time < 2s': (r) => r.timings.duration < 2000,
    });

    if (success) {
      successfulPredictions.add(1);
      modelErrors.add(0);
    } else {
      modelErrors.add(1);
      console.error(`Prediction failed: ${res.status} ${res.body}`);
    }
  });

  sleep(Math.random() * 0.5 + 0.1);
}

export function teardown() {
  console.log('Model serving load test complete');
  console.log(`Total successful predictions: ${successfulPredictions.value}`);
}
