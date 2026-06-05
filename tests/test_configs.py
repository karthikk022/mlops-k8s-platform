import json
import os
import yaml
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

EXCLUDED_DIRS = {".git", "__pycache__", "node_modules", ".pytest_cache"}
EXCLUDED_PATTERNS = {
    ".DS_Store",
    "*.pyc",
    "*.md",
    "*.sh",
    "*.tf",
    "*.tfvars",
    "*.lock",
    "*.png",
    "*.jpg",
    "*.svg",
    "*.sum",
    "*.gitignore",
    ".checkovignore",
    ".trivyignore",
}

HELM_TEMPLATE_DIRS = {"templates"}

def _is_helm_template(path):
    for parent in path.parents:
        if parent.name in HELM_TEMPLATE_DIRS:
            return True
    return False


def _collect_yaml_files():
    files = []
    for root, dirs, fnames in os.walk(REPO_ROOT):
        dirs[:] = [d for d in dirs if d not in EXCLUDED_DIRS]
        for fn in fnames:
            if fn.endswith((".yaml", ".yml")):
                files.append(Path(root) / fn)
    return files


def _collect_json_files():
    files = []
    for root, dirs, fnames in os.walk(REPO_ROOT):
        dirs[:] = [d for d in dirs if d not in EXCLUDED_DIRS]
        for fn in fnames:
            if fn.endswith(".json"):
                files.append(Path(root) / fn)
    return files


def test_all_yaml_parses():
    errors = []
    for path in _collect_yaml_files():
        if _is_helm_template(path):
            continue
        try:
            list(yaml.safe_load_all(path.read_text()))
        except yaml.YAMLError as e:
            rel = path.relative_to(REPO_ROOT)
            errors.append(f"{rel}: {e}")
    assert not errors, "\n".join(errors)


def test_all_json_parses():
    errors = []
    for path in _collect_json_files():
        try:
            json.loads(path.read_text())
        except json.JSONDecodeError as e:
            rel = path.relative_to(REPO_ROOT)
            errors.append(f"{rel}: {e}")
    assert not errors, "\n".join(errors)


def test_inference_service_has_required_fields():
    path = REPO_ROOT / "serving" / "InferenceService.yaml"
    docs = list(yaml.safe_load_all(path.read_text()))
    isvc = docs[0]
    assert isvc["kind"] == "InferenceService"
    assert isvc["apiVersion"].startswith("serving.kserve.io")
    assert isvc["spec"]["predictor"]["containers"]


def test_canary_rollout_has_required_fields():
    path = REPO_ROOT / "serving" / "canary-rollout.yaml"
    docs = list(yaml.safe_load_all(path.read_text()))
    assert len(docs) >= 1
    assert all(d is not None for d in docs)


def test_helm_chart_yaml():
    for chart in ["mlflow", "feast", "evidently"]:
        chart_path = REPO_ROOT / "infrastructure" / "helm" / chart
        if not chart_path.exists():
            continue
        yaml_files = list(chart_path.rglob("*.yaml")) + list(chart_path.rglob("*.yml"))
        assert yaml_files, f"No YAML files found in helm chart {chart}/"


def test_gatekeeper_constraint_syntax():
    constraint_dirs = [
        REPO_ROOT / "security" / "gatekeeper" / "constraints",
        REPO_ROOT / "security" / "gatekeeper" / "templates",
    ]
    for d in constraint_dirs:
        for path in d.rglob("*.yaml"):
            docs = list(yaml.safe_load_all(path.read_text()))
            assert all(d is not None for d in docs), f"Empty doc in {path.relative_to(REPO_ROOT)}"


def test_monitoring_alert_rules():
    alerts = REPO_ROOT / "monitoring" / "alerts"
    for f in alerts.glob("*.yml"):
        doc = yaml.safe_load(f.read_text())
        assert doc is not None, f"Empty alert file: {f.name}"
