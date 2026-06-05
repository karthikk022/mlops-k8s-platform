import ast
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ML_PIPELINE = REPO_ROOT / "ml-pipeline"


def test_pipeline_compiles():
    with open(ML_PIPELINE / "pipeline.py") as f:
        tree = ast.parse(f.read())
    func_defs = [n.name for n in ast.walk(tree) if isinstance(n, ast.FunctionDef)]
    assert "ml_training_pipeline" in func_defs, "Missing pipeline DAG function"
    assert "validate_data" in func_defs, "Missing validate_data component"
    assert "preprocess_data" in func_defs, "Missing preprocess_data component"
    assert "train_model" in func_defs, "Missing train_model component"
    assert "evaluate_model" in func_defs, "Missing evaluate_model component"


def test_pipeline_has_no_syntax_errors():
    for f in ["pipeline.py"]:
        path = ML_PIPELINE / f
        with open(path) as fh:
            compile(fh.read(), str(path), "exec")


def test_ml_requirements_parse():
    for subdir in ["training", "preprocessing", "evaluation"]:
        req = ML_PIPELINE / subdir / "requirements.txt"
        assert req.exists(), f"Missing requirements.txt in {subdir}/"
        lines = req.read_text().strip().splitlines()
        for line in lines:
            line = line.strip()
            if line and not line.startswith("#"):
                assert re.match(r"^[a-zA-Z0-9_.-]+([><=!~]=.+)?$", line.split("#")[0].strip()), (
                    f"Illegal requirement line in {subdir}/requirements.txt: {line}"
                )


def test_dockerfiles_exist():
    for subdir in ["training", "preprocessing", "evaluation"]:
        df = ML_PIPELINE / subdir / "Dockerfile"
        assert df.exists(), f"Missing Dockerfile in {subdir}/"
        content = df.read_text()
        assert "FROM" in content, f"{subdir}/Dockerfile missing FROM instruction"
        assert "COPY" in content or "RUN" in content, f"{subdir}/Dockerfile looks empty"


def test_training_script_has_fit():
    path = ML_PIPELINE / "training" / "train.py"
    assert ".fit(" in path.read_text() or ".train(" in path.read_text()


def test_model_server_handler():
    path = REPO_ROOT / "serving" / "model-server" / "handler.py"
    assert path.exists(), "Missing model server handler"
    content = path.read_text()
    assert "def handle" in content or "def predict" in content or "class" in content
