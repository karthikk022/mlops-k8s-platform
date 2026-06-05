SHELL := /bin/bash
.DEFAULT_GOAL := help

CLUSTER     ?= mlops-dev
REGION      ?= ap-south-1
NAMESPACE   ?= mlops
ENVIRONMENT ?= dev
MODEL_NAME  ?= loan-default-predictor

.PHONY: help setup-cluster kubeconfig infra-init infra-plan infra-apply infra-destroy
.PHONY: deploy-mlflow deploy-feast deploy-evidently deploy-all
.PHONY: pipeline-compile pipeline-run deploy-model deploy-canary test-endpoint
.PHONY: scan-checkov scan-trivy scan-all
.PHONY: port-forward-grafana port-forward-mlflow
.PHONY: backup-all restore-all verify-backup
.PHONY: k6-model k6-mlflow k6-feast k6-soak k6-stress
.PHONY: test test-python test-yaml test-infra
.PHONY: feast-apply feast-materialize clean

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# ── Cluster ─────────────────────────────────────────────────────────────────

setup-cluster: ## Provision EKS + install Istio, KServe, Prometheus, ML components
	./scripts/setup-cluster.sh $(CLUSTER) $(REGION)

kubeconfig: ## Update kubeconfig for the cluster
	aws eks update-kubeconfig --name $(CLUSTER) --region $(REGION)

# ── Infrastructure (Terraform) ───────────────────────────────────────────────

infra-init: ## terraform init for the target environment
	cd infrastructure/terraform/environments/$(ENVIRONMENT) && terraform init

infra-plan: ## terraform plan for the target environment
	cd infrastructure/terraform/environments/$(ENVIRONMENT) && terraform plan

infra-apply: ## terraform apply for the target environment
	cd infrastructure/terraform/environments/$(ENVIRONMENT) && terraform apply -auto-approve

infra-destroy: ## terraform destroy for the target environment
	cd infrastructure/terraform/environments/$(ENVIRONMENT) && terraform destroy -auto-approve

# ── Helm Deploy ──────────────────────────────────────────────────────────────

deploy-mlflow: ## Deploy/upgrade MLflow via Helm
	./scripts/deploy-mlflow.sh $(ENVIRONMENT) $(NAMESPACE)

deploy-feast: ## Deploy/upgrade Feast via Helm
	helm upgrade --install feast infrastructure/helm/feast -n $(NAMESPACE) --wait

deploy-evidently: ## Deploy/upgrade Evidently via Helm
	helm upgrade --install evidently infrastructure/helm/evidently -n monitoring --wait

deploy-all: deploy-mlflow deploy-feast deploy-evidently ## Deploy all ML platform components

# ── ML Pipeline ──────────────────────────────────────────────────────────────

pipeline-compile: ## Compile the Kubeflow pipeline DAG
	python ml-pipeline/pipeline.py

pipeline-run: ## Upload and run the pipeline on Kubeflow
	kfp --endpoint $(KFP_ENDPOINT) pipeline upload -p ml-training-pipeline ml-training-pipeline.yaml

# ── Model Serving ────────────────────────────────────────────────────────────

deploy-model: ## Deploy InferenceService to the cluster
	kubectl apply -f serving/InferenceService.yaml -n $(NAMESPACE)

deploy-canary: ## Deploy canary rollout (KServe + Istio)
	kubectl apply -f serving/canary-rollout.yaml -n $(NAMESPACE)

test-endpoint: ## Run endpoint smoke tests against the deployed model
	./scripts/test-endpoint.sh $(MODEL_NAME) $(NAMESPACE)

# ── Security Scanning ────────────────────────────────────────────────────────

scan-checkov: ## Run Checkov on Terraform configs
	checkov -d infrastructure/terraform --framework terraform --compact --quiet

scan-trivy: ## Run Trivy filesystem misconfig scan
	trivy fs --scanners misconfig --severity HIGH,CRITICAL .

scan-all: scan-checkov scan-trivy ## Run all security scans

# ── Monitoring ───────────────────────────────────────────────────────────────

port-forward-grafana: ## Port-forward Grafana to localhost:3000
	kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80

port-forward-mlflow: ## Port-forward MLflow UI to localhost:5000
	kubectl port-forward -n $(NAMESPACE) svc/mlflow 5000:5000

# ── Backup / Disaster Recovery ───────────────────────────────────────────────

backup-all: ## Run all Velero + RDS backups
	./backup-dr/scripts/backup-all.sh

restore-all: ## Run all Velero + RDS restores
	./backup-dr/scripts/restore-all.sh

verify-backup: ## Verify Velero backup integrity
	./backup-dr/scripts/verify-backup.sh

# ── Load Testing (k6) ────────────────────────────────────────────────────────

k6-model: ## Run model serving load test
	k6 run load-testing/k6/scripts/model-serving.js -e MODEL_ENDPOINT=http://localhost:8080

k6-mlflow: ## Run MLflow API load test
	k6 run load-testing/k6/scripts/mlflow-api.js -e MLFLOW_ENDPOINT=http://localhost:5000

k6-feast: ## Run feature store load test
	k6 run load-testing/k6/scripts/feature-store.js -e FEAST_ENDPOINT=http://localhost:6566

k6-soak: ## Run soak test (sustained load)
	k6 run load-testing/k6/scripts/soak-test.js -e MODEL_ENDPOINT=http://localhost:8080

k6-stress: ## Run stress test (ramping load)
	k6 run load-testing/k6/scripts/stress-test.js -e MODEL_ENDPOINT=http://localhost:8080

# ── Local Tests ──────────────────────────────────────────────────────────────

test: test-python test-yaml test-infra ## Run all local validation tests

test-python: ## Run Python unit tests (pytest)
	python -m pytest tests/ -v --tb=short -W ignore::DeprecationWarning

test-yaml: ## Validate all YAML and JSON files parse correctly
	python -m pytest tests/test_configs.py -v

test-infra: ## Run infrastructure validation shell tests
	./tests/test_infra.sh

# ── Feature Store ────────────────────────────────────────────────────────────

feast-apply: ## Apply Feast feature definitions to the store
	cd feature-store && feast apply

feast-materialize: ## Materialize features from offline to online store
	python feature-store/materialize.py

# ── Housekeeping ─────────────────────────────────────────────────────────────

clean: ## Remove caches and temporary files
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name '*.pyc' -delete
	rm -rf .pytest_cache
