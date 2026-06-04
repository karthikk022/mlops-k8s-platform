#!/bin/bash
set -euo pipefail

NAMESPACE="${1:-vault}"
CLUSTER_NAME="${2:-mlops-prod}"
REGION="${3:-ap-south-1}"

echo "=== Bootstrapping Vault on cluster: $CLUSTER_NAME ==="

echo "1. Installing Vault HA with Raft..."
helm repo add hashicorp https://helm.releases.hashicorp.com
helm upgrade --install vault hashicorp/vault \
  -n "$NAMESPACE" --create-namespace \
  -f secrets/vault/config/vault-values.yaml \
  --wait

echo "2. Waiting for Vault pods..."
kubectl wait --for=condition=Ready --timeout=180s pod/vault-0 -n "$NAMESPACE"
kubectl wait --for=condition=Ready --timeout=180s pod/vault-1 -n "$NAMESPACE"
kubectl wait --for=condition=Ready --timeout=180s pod/vault-2 -n "$NAMESPACE"

echo "3. Initializing Vault..."
kubectl exec -n "$NAMESPACE" vault-0 -- vault operator init \
  -key-shares=5 -key-threshold=3 \
  -format=json > /tmp/vault-keys.json

UNSEAL_KEYS=$(cat /tmp/vault-keys.json | jq -r '.unseal_keys_b64[0:3][]')
ROOT_TOKEN=$(cat /tmp/vault-keys.json | jq -r '.root_token')

echo "4. Unsealing vault-0..."
for key in $UNSEAL_KEYS; do
  kubectl exec -n "$NAMESPACE" vault-0 -- vault operator unseal "$key"
done

echo "5. Joining vault-1 and vault-2 to Raft..."
kubectl exec -n "$NAMESPACE" vault-1 -- vault operator raft join http://vault-0.vault-internal:8200
kubectl exec -n "$NAMESPACE" vault-2 -- vault operator raft join http://vault-0.vault-internal:8200

for key in $UNSEAL_KEYS; do
  kubectl exec -n "$NAMESPACE" vault-1 -- vault operator unseal "$key"
  kubectl exec -n "$NAMESPACE" vault-2 -- vault operator unseal "$key"
done

echo "6. Enabling Kubernetes auth..."
kubectl exec -n "$NAMESPACE" vault-0 -- sh -c "
  vault login $ROOT_TOKEN
  vault auth enable kubernetes
  vault write auth/kubernetes/config \
    kubernetes_host=https://\${KUBERNETES_SERVICE_HOST}:443 \
    token_reviewer_jwt=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token) \
    kubernetes_ca_cert=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt) \
    issuer=https://kubernetes.default.svc.cluster.local
"

echo "7. Enabling database secrets engine for MLflow RDS..."
kubectl exec -n "$NAMESPACE" vault-0 -- sh -c "
  vault secrets enable database
  vault write database/config/mlflow-rds \
    plugin_name=postgresql-database-plugin \
    allowed_roles=mlflow-role \
    connection_url=postgresql://{{username}}:{{password}}@mlflow-db.${REGION}.rds.amazonaws.com:5432/mlflow \
    username=vault_admin \
    password=$(aws secretsmanager get-secret-value --secret-id mlflow/rds/master-password --query SecretString --output text)

  vault write database/roles/mlflow-role \
    db_name=mlflow-rds \
    creation_statements=\"CREATE USER \\\"{{name}}\\\" WITH PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT ALL PRIVILEGES ON DATABASE mlflow TO \\\"{{name}}\\\";\" \
    default_ttl=1h \
    max_ttl=24h
"

echo "8. Enabling AWS secrets engine for cross-account access..."
kubectl exec -n "$NAMESPACE" vault-0 -- sh -c "
  vault secrets enable aws
  vault write aws/config/root \
    access_key=\$(aws configure get aws_access_key_id) \
    secret_key=\$(aws configure get aws_secret_access_key) \
    region=$REGION

  vault write aws/roles/mlops-s3 \
    credential_type=iam_user \
    policy_document='
{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Effect\": \"Allow\",
      \"Action\": [\"s3:GetObject\", \"s3:PutObject\"],
      \"Resource\": \"arn:aws:s3:::mlops-*\"
    }
  ]
}'
"

echo "9. Creating policies for MLOps workloads..."
kubectl exec -n "$NAMESPACE" vault-0 -- sh -c "
  vault policy write mlflow - <<'POL'
path \"database/creds/mlflow-role\" {
  capabilities = [\"read\"]
}
path \"aws/creds/mlops-s3\" {
  capabilities = [\"read\"]
}
path \"secret/data/mlflow/*\" {
  capabilities = [\"read\", \"list\"]
}
POL

  vault policy write kserve - <<'POL'
path \"aws/creds/mlops-s3\" {
  capabilities = [\"read\"]
}
path \"secret/data/models/*\" {
  capabilities = [\"read\"]
}
POL

  vault write auth/kubernetes/role/mlflow \
    bound_service_account_names=mlflow \
    bound_service_account_namespaces=mlops \
    policies=mlflow \
    ttl=1h

  vault write auth/kubernetes/role/kserve \
    bound_service_account_names=kserve \
    bound_service_account_namespaces=mlops \
    policies=kserve \
    ttl=1h
"

echo "10. Writing static secrets..."
kubectl exec -n "$NAMESPACE" vault-0 -- sh -c "
  vault secrets enable -path=secret kv-v2
  vault kv put secret/mlflow/mlflow admin_password=$(openssl rand -base64 16)
  vault kv put secret/mlflow/grafana grafana_password=$(openssl rand -base64 16)
  vault kv put secret/mlflow/slack webhook_url=https://hooks.slack.com/services/T00/CHANGEME
  vault kv put secret/models/loan-default model_version=1.0.0
"

echo "=== Vault bootstrap complete ==="
echo "Root token: $ROOT_TOKEN (store securely!)"
echo "Unseal keys stored in /tmp/vault-keys.json"
echo ""
echo "Next: Update app deployments to use Vault agent injector annotations"
