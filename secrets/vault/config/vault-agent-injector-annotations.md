# Vault Agent Injector Annotations

Add these annotations to any pod that needs secrets from Vault.

## MLflow Deployment

```yaml
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/agent-inject-status: "update"
    vault.hashicorp.com/role: "mlflow"
    vault.hashicorp.com/agent-inject-secret-db-creds: "database/creds/mlflow-role"
    vault.hashicorp.com/agent-inject-template-db-creds: |
      {{- with secret "database/creds/mlflow-role" -}}
      export MLFLOW_DB_USER="{{ .Data.username }}"
      export MLFLOW_DB_PASSWORD="{{ .Data.password }}"
      {{- end }}
    vault.hashicorp.com/agent-inject-secret-aws-creds: "aws/creds/mlops-s3"
    vault.hashicorp.com/agent-inject-template-aws-creds: |
      {{- with secret "aws/creds/mlops-s3" -}}
      export AWS_ACCESS_KEY_ID="{{ .Data.access_key }}"
      export AWS_SECRET_ACCESS_KEY="{{ .Data.secret_key }}"
      {{- end }}
    vault.hashicorp.com/agent-inject-secret-mlflow-config: "secret/data/mlflow/mlflow"
    vault.hashicorp.com/agent-inject-template-mlflow-config: |
      {{- with secret "secret/data/mlflow/mlflow" -}}
      export MLFLOW_ADMIN_PASSWORD="{{ .Data.data.admin_password }}"
      {{- end }}
```

## KServe InferenceService

```yaml
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "kserve"
    vault.hashicorp.com/agent-inject-secret-model-config: "secret/data/models/loan-default"
    vault.hashicorp.com/agent-inject-template-model-config: |
      {{- with secret "secret/data/models/loan-default" -}}
      export MODEL_VERSION="{{ .Data.data.model_version }}"
      {{- end }}
    vault.hashicorp.com/agent-inject-secret-aws-creds: "aws/creds/mlops-s3"
    vault.hashicorp.com/agent-inject-template-aws-creds: |
      {{- with secret "aws/creds/mlops-s3" -}}
      export AWS_ACCESS_KEY_ID="{{ .Data.access_key }}"
      export AWS_SECRET_ACCESS_KEY="{{ .Data.secret_key }}"
      {{- end }}
```

## Feast Feature Store

```yaml
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "mlflow"
    vault.hashicorp.com/agent-inject-secret-redis: "secret/data/feast/redis"
    vault.hashicorp.com/agent-inject-template-redis: |
      {{- with secret "secret/data/feast/redis" -}}
      export REDIS_PASSWORD="{{ .Data.data.redis_password }}"
      {{- end }}
```
