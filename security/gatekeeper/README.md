# Gatekeeper OPA Policies

Enforced on all namespaces in the MLOps platform. Violations block admission.

| Policy | Enforcement | Violation Action |
|--------|------------|------------------|
| require-resource-limits | All pods | Deny |
| block-privileged-containers | All pods | Deny |
| require-istio-sidecar | mlops namespace | Deny |
| require-probes | All deployments | Deny |
| block-latest-tag | All containers | Deny |
| min-replicas | Deployments in mlops | Deny |
| required-labels | All resources | Warn |
| block-host-network | All pods | Deny |
