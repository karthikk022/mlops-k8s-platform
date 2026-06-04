#!/bin/bash
set -euo pipefail

ENV="${1:-dev}"
NAMESPACE="${2:-mlops}"

echo "Deploying MLflow to $ENV environment..."

# Create S3 bucket for artifacts
BUCKET="mlflow-artifacts-$ENV-$(aws sts get-caller-identity --query Account --output text)"
aws s3 mb "s3://$BUCKET" 2>/dev/null || true
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled

# Create RDS database for MLflow
aws rds create-db-instance \
  --db-instance-identifier "mlflow-$ENV" \
  --db-instance-class db.t3.medium \
  --engine postgres \
  --master-username mlflow \
  --master-user-password "$(openssl rand -base64 16)" \
  --allocated-storage 20 \
  --tags Key=Environment,Value="$ENV" Key=Service,Value=mlflow 2>/dev/null || true

# Deploy Helm chart
helm upgrade --install mlflow infrastructure/helm/mlflow \
  --namespace "$NAMESPACE" \
  --set "environment=$ENV" \
  --set "storage.bucket=$BUCKET" \
  --wait

echo "MLflow deployed. Port-forward: kubectl port-forward -n $NAMESPACE svc/mlflow 5000:5000"
