# MLOps K8s Platform

End-to-end ML platform on Amazon EKS — automated training, feature store, model serving, drift monitoring, and infrastructure-as-code. Built for production ML workloads.

```
                          ┌──────────────────────────────────────────────────┐
                          │                   GitHub Actions                 │
                          │  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
                          │  │ ML Train │  │ Infra    │  │ Model Deploy  │  │
                          │  │ Pipeline │  │ Deploy   │  │ (Canary)      │  │
                          │  └─────┬────┘  └────┬─────┘  └───────┬───────┘  │
                          └────────┼─────────────┼───────────────┼──────────┘
                                   │             │               │
                    ┌──────────────┼─────────────┼───────────────┼──────────┐
                    │              │     Amazon EKS Cluster      │          │
                    │  ┌───────────┴──────────┐  ┌───────────────┴───────┐  │
                    │  │     Kubeflow         │  │     KServe + Istio    │  │
                    │  │  ┌────────────────┐  │  │  ┌─────────────────┐  │  │
                    │  │  │ Training Ops   │  │  │  │ Model Serving   │  │  │
                    │  │  │ (TFJob,        │  │  │  │ (InferenceSvc   │  │  │
                    │  │  │  PyTorchJob)   │  │  │  │  + canary)      │  │  │
                    │  │  └────────────────┘  │  │  └─────────────────┘  │  │
                    │  └──────────────────────┘  └───────────────────────┘  │
                    │                                                       │
                    │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
                    │  │  Feast       │  │  MLflow      │  │  Evidently   │ │
                    │  │  Feature     │  │  Model/Exp   │  │  Drift       │ │
                    │  │  Store       │  │  Registry    │  │  Monitor     │ │
                    │  └──────────────┘  └──────────────┘  └──────────────┘ │
                    │                                                       │
                    │  ┌──────────────────────────────────────────────────┐  │
                    │  │  Prometheus + Grafana + Alertmanager             │  │
                    │  │  (Infra + Model drift + API latency)             │  │
                    │  └──────────────────────────────────────────────────┘  │
                    └───────────────────────────────────────────────────────┘
```

## Features

| Capability | Tool | Description |
|------------|------|-------------|
| ML Pipeline | Kubeflow + Argo Workflows | Automated training, eval, promotion |
| Model Registry | MLflow | Experiment tracking, model versioning |
| Feature Store | Feast | Real-time feature serving |
| Model Serving | KServe + Istio | A/B testing, canary, autoscaling |
| Drift Monitoring | Evidently + Prometheus | Data drift, model drift, alerts |
| Infra-as-Code | Terraform + Crossplane | GitOps for infra + ML platform |
| CI/CD | GitHub Actions | Pipeline triggers, model deploy |

## Quick Start

```bash
# 1. Provision EKS + ML platform
cd infrastructure/terraform/environments/dev
terraform init && terraform apply -auto-approve

# 2. Deploy ML pipeline components
kubectl apply -k infrastructure/helm

# 3. Run training pipeline
cd ml-pipeline
python pipeline.py --run

# 4. Deploy model
kubectl apply -f serving/InferenceService.yaml

# 5. Verify
curl -H "Content-Type: application/json" \
  -d '{"inputs": [[5.1, 3.5, 1.4, 0.2]]}' \
  http://modelmesh-serving:8008/v2/models/iris/infer
```

## Project Structure

```
mlops-k8s-platform/
├── infrastructure/          # Terraform, Helm, Crossplane
│   ├── terraform/           # EKS + ML platform IaC
│   ├── helm/                # MLflow, Feast, Evidently charts
│   └── crossplane/          # Platform API compositions
├── ml-pipeline/             # Kubeflow training pipeline
│   ├── training/            # Model training containers
│   ├── preprocessing/       # Feature engineering
│   ├── evaluation/          # Model evaluation
│   └── pipeline.py          # Pipeline DAG definition
├── serving/                 # Model inference
│   ├── model-server/        # Custom inference handler
│   └── InferenceService.yaml
├── feature-store/           # Feast definitions
├── monitoring/              # Drift + infra alerts
├── .github/workflows/       # CI/CD automation
├── examples/                # Reference implementations
└── scripts/                 # Utility scripts
```

## CI/CD Pipelines

| Workflow | Trigger | What It Does |
|----------|---------|-------------|
| `ml-pipeline.yml` | Push to `ml-pipeline/` | Data validation → train → evaluate → push to registry |
| `infra-deploy.yml` | Push to `infrastructure/` | Terraform plan/apply for EKS + addons |
| `model-deploy.yml` | MLflow registry tag | Canary deploy via KServe + Istio |

## Compliance & Governance

- **OPA/Gatekeeper** policies enforce pod security, resource limits, and model provenance
- **MLflow** tracks experiment lineage for auditability
- **Crossplane** compositions enforce platform standards
- All infrastructure is immutable — rebuilt, not patched

## Target Roles

MLOps Engineer | Platform Engineer | AI Infrastructure Engineer | ML DevOps
