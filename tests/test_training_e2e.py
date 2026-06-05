import os
import sys
import tempfile
import yaml
import pytest
import pandas as pd
import numpy as np
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "ml-pipeline" / "training"))
sys.path.insert(0, str(REPO_ROOT / "ml-pipeline" / "preprocessing"))
sys.path.insert(0, str(REPO_ROOT / "ml-pipeline" / "evaluation"))
sys.path.insert(0, str(REPO_ROOT / "data"))


def train_with_data(tmp_path):
    from generate_sample_data import generate_loan_default_data
    from preprocess import preprocess
    from train import train

    data_dir = tmp_path / "data"
    preprocessed_dir = tmp_path / "preprocessed"

    generate_loan_default_data(str(data_dir), n_samples=500, random_state=42)
    preprocess(
        input_path=str(data_dir / "dataset.parquet"),
        output_path=str(preprocessed_dir),
        test_size=0.2,
        target_column="label",
    )

    config = {
        "tracking_uri": "",
        "experiment_name": "e2e-test",
        "data": {
            "train_path": str(preprocessed_dir / "train.parquet"),
            "test_path": str(preprocessed_dir / "test.parquet"),
            "target_column": "label",
        },
        "model": {
            "type": "gradient_boosting",
            "params": {
                "n_estimators": 50,
                "max_depth": 3,
                "learning_rate": 0.1,
            },
        },
        "register_model": False,
    }
    config_path = tmp_path / "config.yaml"
    with open(config_path, "w") as f:
        yaml.dump(config, f)

    run_id = train(config)
    return run_id, preprocessed_dir


class TestTrainingEndToEnd:
    def test_generate_sample_data_creates_parquet(self, tmp_path):
        from generate_sample_data import generate_loan_default_data
        df = generate_loan_default_data(str(tmp_path), n_samples=100, random_state=42)
        assert len(df) == 100
        assert "label" in df.columns
        assert "customer_id" in df.columns
        assert os.path.exists(str(tmp_path / "dataset.parquet"))

    def test_preprocessing_outputs_files(self, tmp_path):
        from generate_sample_data import generate_loan_default_data
        from preprocess import preprocess
        data_dir = tmp_path / "data"
        out_dir = tmp_path / "out"
        generate_loan_default_data(str(data_dir), n_samples=200, random_state=42)
        preprocess(str(data_dir / "dataset.parquet"), str(out_dir), 0.2, "label")
        assert (out_dir / "train.parquet").exists()
        assert (out_dir / "test.parquet").exists()
        assert (out_dir / "metadata.json").exists()
        train_df = pd.read_parquet(out_dir / "train.parquet")
        test_df = pd.read_parquet(out_dir / "test.parquet")
        assert len(train_df) > len(test_df)

    def test_model_trains_and_logs_metrics(self, tmp_path):
        config_data = {
            "tracking_uri": "",
            "experiment_name": "test-metrics",
            "data": {
                "train_path": "",
                "test_path": "",
                "target_column": "label",
            },
            "model": {
                "type": "gradient_boosting",
                "params": {"n_estimators": 30, "max_depth": 2, "learning_rate": 0.1},
            },
            "register_model": False,
        }
        from generate_sample_data import generate_loan_default_data
        from preprocess import preprocess
        from train import train
        data_dir = tmp_path / "data"
        pp_dir = tmp_path / "pp"
        generate_loan_default_data(str(data_dir), n_samples=300, random_state=42)
        preprocess(str(data_dir / "dataset.parquet"), str(pp_dir), 0.2, "label")
        config_data["data"]["train_path"] = str(pp_dir / "train.parquet")
        config_data["data"]["test_path"] = str(pp_dir / "test.parquet")
        config_path = tmp_path / "cfg.yaml"
        with open(config_path, "w") as f:
            yaml.dump(config_data, f)
        run_id = train(config_data)
        assert run_id is not None
        assert os.path.exists("/tmp/metrics.json")
        import json
        with open("/tmp/metrics.json") as f:
            metrics = json.load(f)
        assert metrics["accuracy"] > 0.5
        assert metrics["f1"] > 0.5

    def test_model_accuracy_above_threshold(self, tmp_path):
        from generate_sample_data import generate_loan_default_data
        from preprocess import preprocess
        from train import train
        from evaluate import evaluate
        data_dir = tmp_path / "data"
        pp_dir = tmp_path / "pp"
        generate_loan_default_data(str(data_dir), n_samples=500, random_state=42)
        preprocess(str(data_dir / "dataset.parquet"), str(pp_dir), 0.2, "label")
        config = {
            "tracking_uri": "",
            "experiment_name": "test-accuracy",
            "data": {
                "train_path": str(pp_dir / "train.parquet"),
                "test_path": str(pp_dir / "test.parquet"),
                "target_column": "label",
            },
            "model": {
                "type": "gradient_boosting",
                "params": {"n_estimators": 50, "max_depth": 4, "learning_rate": 0.1},
            },
            "register_model": False,
        }
        run_id = train(config)
        model_uri = f"runs:/{run_id}/model"
        results = evaluate(model_uri, str(pp_dir / "test.parquet"), "label", {"accuracy": 0.70, "precision": 0.65}, tracking_uri="")
        assert results["metrics"]["accuracy"] >= 0.70
        assert results["metrics"]["precision"] >= 0.65
        assert "confusion_matrix" in results
        assert "classification_report" in results

    def test_different_model_types(self, tmp_path):
        from generate_sample_data import generate_loan_default_data
        from preprocess import preprocess
        from train import train
        data_dir = tmp_path / "data"
        pp_dir = tmp_path / "pp"
        generate_loan_default_data(str(data_dir), n_samples=300, random_state=42)
        preprocess(str(data_dir / "dataset.parquet"), str(pp_dir), 0.2, "label")
        config_template = {
            "tracking_uri": "",
            "experiment_name": "test-model-types",
            "data": {
                "train_path": str(pp_dir / "train.parquet"),
                "test_path": str(pp_dir / "test.parquet"),
                "target_column": "label",
            },
            "register_model": False,
        }
        for model_type in ["gradient_boosting", "random_forest"]:
            cfg = {**config_template, "model": {"type": model_type, "params": {"n_estimators": 30, "max_depth": 3, "random_state": 42}}}
            run_id = train(cfg)
            assert run_id is not None

    def test_handler_predict(self, tmp_path):
        from generate_sample_data import generate_loan_default_data
        from preprocess import preprocess
        from train import train
        data_dir = tmp_path / "data"
        pp_dir = tmp_path / "pp"
        generate_loan_default_data(str(data_dir), n_samples=300, random_state=42)
        preprocess(str(data_dir / "dataset.parquet"), str(pp_dir), 0.2, "label")
        config = {
            "tracking_uri": "",
            "experiment_name": "test-handler",
            "data": {
                "train_path": str(pp_dir / "train.parquet"),
                "test_path": str(pp_dir / "test.parquet"),
                "target_column": "label",
            },
            "model": {"type": "gradient_boosting", "params": {"n_estimators": 30, "max_depth": 3, "learning_rate": 0.1}},
            "register_model": False,
        }
        train(config)
        test_df = pd.read_parquet(pp_dir / "test.parquet")
        features = test_df.drop("label", axis=1).iloc[0].tolist()
        assert len(features) > 0
        assert all(isinstance(v, (int, float, np.floating, np.integer)) for v in features)
