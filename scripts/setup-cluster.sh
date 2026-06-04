#!/bin/bash
set -euo pipefail

CLUSTER_NAME="${1:-mlops-dev}"
REGION="${2:-ap-south-1}"

echo "=== Setting up MLOps cluster: $CLUSTER_NAME ==="

echo "1. Updating kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

echo "2. Installing Istio..."
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm upgrade --install istio-base istio/base -n istio-system --create-namespace --wait
helm upgrade --install istiod istio/istiod -n istio-system --wait
helm upgrade --install istio-ingress istio/gateway -n istio-system --wait
kubectl label namespace mlops istio-injection=enabled --overwrite

echo "3. Installing KServe..."
helm repo add kserve https://kserve.github.io/helm-charts
helm upgrade --install kserve kserve/kserve -n mlops --create-namespace --wait
helm upgrade --install kserve-models kserve/kserve-models -n mlops --wait

echo "4. Installing Prometheus stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace --wait

echo "5. Installing MLflow, Feast, Evidently..."
helm upgrade --install mlflow infrastructure/helm/mlflow -n mlops --wait
helm upgrade --install feast infrastructure/helm/feast -n mlops --wait
helm upgrade --install evidently infrastructure/helm/evidently -n monitoring --wait

echo "6. Setting up S3 buckets..."
aws s3 mb "s3://mlflow-artifacts-$CLUSTER_NAME" --region "$REGION"
aws s3 mb "s3://kserve-models-$CLUSTER_NAME" --region "$REGION"
aws s3 mb "s3://mlops-data-$CLUSTER_NAME" --region "$REGION"

echo "7. Applying Crossplane compositions..."
kubectl apply -f infrastructure/crossplane/

echo "=== Setup complete ==="
echo ""
echo "MLflow UI:   kubectl port-forward -n mlops svc/mlflow 5000:5000"
echo "Grafana:     kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80"
echo "KServe:      kubectl get inferenceservices -n mlops"
