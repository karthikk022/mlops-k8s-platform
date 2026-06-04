# Architecture

## Overview

Production ML platform on AWS EKS with full separation of concerns: training plane, serving plane, and control plane.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Orchestrator | Amazon EKS | Managed control plane, native AWS integrations |
| ML Pipeline | Kubeflow | Native K8s, TFJob/PyTorchJob operators |
| Model Registry | MLflow | De facto standard, experiment tracking |
| Serving | KServe + Istio | Autoscaling, canary, A/B, request routing |
| Feature Store | Feast | Real-time + batch, Redis backend |
| Drift Detection | Evidently | Open-source, Prometheus integration |
| Infra Provisioning | Terraform | State management, multi-env |
| Platform API | Crossplane | Self-service infra for data scientists |

## Training Plane

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Git Push   │───▶│ GitHub       │───▶│ Argo         │
│ (ml-pipeline)│    │ Actions      │    │ Workflows    │
└──────────────┘    └──────────────┘    └──────┬───────┘
                                               │
                    ┌──────────────────────────┼──────────┐
                    │                          │          │
              ┌─────┴─────┐           ┌────────┴────────┐ │
              │ Data Valid│           │   Training Job  │ │
              │ (GreatExp)│           │  (TFJob/KFJob)  │ │
              └───────────┘           └────────┬────────┘ │
                                               │          │
                    ┌──────────────────────────┼──────────┘
                    │                          │
              ┌─────┴─────┐           ┌────────┴────────┐
              │ Evaluation│           │  Model Registry │
              │ (metrics) │           │  (MLflow)       │
              └───────────┘           └─────────────────┘
```

## Serving Plane

```
                    ┌──────────────┐
                    │  Istio       │
                    │  Ingress     │
                    │  Gateway     │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
        ┌─────┴─────┐ ┌───┴────┐ ┌────┴─────┐
        │ Stable    │ │ Canary │ │ Baseline │
        │ (v1) 90%  │ │ (v2)10%│ │ (v2)  0% │
        └───────────┘ └────────┘ └──────────┘
              │            │            │
              └────────────┼────────────┘
                           │
                    ┌──────┴───────┐
                    │  Prometheus  │
                    │  (latency,   │
                    │   error_rate)│
                    └──────────────┘
```

## Environments

| Env | Purpose | Nodes | Cost |
|-----|---------|-------|------|
| dev | Data science experimentation | m6i.large x3 (spot) | ~$200/mo |
| staging | Pre-prod validation | m6i.xlarge x3 (spot) | ~$500/mo |
| prod | Production workloads | m6i.2xlarge x5 (OD + SP) | ~$3,000/mo |

## Observability Stack

| Signal | Tool | What's Measured |
|--------|------|-----------------|
| Metrics | Prometheus | Request latency, error rate, throughput |
| Metrics | Evidently | Data drift, model drift, target drift |
| Logs | CloudWatch + Fluent Bit | Training logs, serving logs |
| Traces | OpenTelemetry + Jaeger | Request tracing through pipeline |
| Dashboards | Grafana | Model perf, infra health, cost |
| Alerts | Alertmanager | Drift threshold, latency SLO, error budget |
