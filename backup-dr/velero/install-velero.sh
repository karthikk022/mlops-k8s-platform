#!/bin/bash
set -euo pipefail

echo "=== Installing Velero for K8s backup ==="

helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update

helm upgrade --install velero vmware-tanzu/velero \
  -n velero --create-namespace \
  -f backup-dr/velero/config/velero-values.yaml \
  --wait

echo "Applying backup schedules..."
kubectl apply -f backup-dr/velero/schedules/

echo "Velero installed successfully"
echo ""
echo "Verify: velero backup get"
echo "Manual backup: velero backup create mlops-manual --include-namespaces mlops,monitoring --wait"
