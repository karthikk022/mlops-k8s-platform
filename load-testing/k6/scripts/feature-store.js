import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const featureErrors = new Rate('feature_store_errors');
const featureLatency = new Trend('feature_latency');

const FEAST_URL = __ENV.FEAST_ENDPOINT || 'http://feast-feature-server.mlops:6566';

export const options = {
  stages: [
    { duration: '1m', target: 10 },
    { duration: '3m', target: 50 },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(99)<100', 'p(95)<50'],
    feature_store_errors: ['rate<0.01'],
  },
};

export default function () {
  group('Feature Store', function () {
    const customerId = Math.floor(Math.random() * 10000) + 1;
    const payload = JSON.stringify({
      features: [
        'transaction_features:avg_transaction_amount_30d',
        'transaction_features:transaction_count_30d',
        'customer_profile_features:credit_score',
        'customer_profile_features:annual_income',
        'loan_application_features:loan_amount',
      ],
      entities: { customer_id: [customerId] },
    });

    const params = {
      headers: { 'Content-Type': 'application/json' },
    };

    const start = Date.now();
    const res = http.post(`${FEAST_URL}/feast/features/get-online`, payload, params);
    const duration = Date.now() - start;

    featureLatency.add(duration);

    const success = check(res, {
      'status is 200': (r) => r.status === 200,
      'response has features': (r) => {
        try {
          return JSON.parse(r.body).status === 'success';
        } catch { return false; }
      },
    });

    featureErrors.add(success ? 0 : 1);
  });

  sleep(0.5);
}
