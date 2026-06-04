#!/bin/bash
set -euo pipefail

echo "=== Installing cert-manager ==="

helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  -f tls/cert-manager/config/cert-manager-values.yaml \
  --wait

echo "Waiting for cert-manager pods..."
kubectl wait --for=condition=Ready --timeout=120s pod -n cert-manager -l app.kubernetes.io/instance=cert-manager

echo "Applying ClusterIssuers..."
kubectl apply -f tls/cert-manager/issuers/letsencrypt-cluster-issuer.yaml

echo "Applying Certificates..."
kubectl apply -f tls/cert-manager/issuers/certificates.yaml

echo "Waiting for certificate issuance..."
kubectl wait --for=condition=Ready --timeout=300s certificate -n mlops mlflow-tls
kubectl wait --for=condition=Ready --timeout=300s certificate -n monitoring grafana-tls
kubectl wait --for=condition=Ready --timeout=300s certificate -n mlops kserve-tls

echo "Applying HTTPS Ingress..."
kubectl apply -f tls/ingress/

echo ""
echo "=== cert-manager installed ==="
echo "Certificates:"
kubectl get certificate -A
echo ""
echo "Ingress endpoints:"
echo "  https://mlflow.mlops.platform"
echo "  https://grafana.mlops.platform"
echo "  https://*.serve.mlops.platform"
echo "  https://evidently.mlops.platform"
