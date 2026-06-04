"""Production training script with MLflow tracking."""
import argparse
import pandas as pd
import numpy as np
import mlflow
import mlflow.sklearn
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
from sklearn.model_selection import cross_val_score
import yaml
import json
import os


def load_config(config_path: str) -> dict:
    with open(config_path) as f:
        return yaml.safe_load(f)


def train(config: dict):
    mlflow.set_tracking_uri(config["tracking_uri"])
    mlflow.set_experiment(config["experiment_name"])

    train = pd.read_parquet(config["data"]["train_path"])
    test = pd.read_parquet(config["data"]["test_path"])

    X_train = train.drop(config["data"]["target_column"], axis=1)
    y_train = train[config["data"]["target_column"]]
    X_test = test.drop(config["data"]["target_column"], axis=1)
    y_test = test[config["data"]["target_column"]]

    with mlflow.start_run() as run:
        model_class = {
            "gradient_boosting": GradientBoostingClassifier,
            "random_forest": RandomForestClassifier,
        }.get(config["model"]["type"])

        if model_class is None:
            raise ValueError(f"Unknown model type: {config['model']['type']}")

        model = model_class(**config["model"]["params"], random_state=42)
        model.fit(X_train, y_train)

        y_pred = model.predict(X_test)
        cv_scores = cross_val_score(model, X_train, y_train, cv=5)

        metrics = {
            "accuracy": accuracy_score(y_test, y_pred),
            "precision": precision_score(y_test, y_pred, average="weighted"),
            "recall": recall_score(y_test, y_pred, average="weighted"),
            "f1": f1_score(y_test, y_pred, average="weighted"),
            "cv_mean": cv_scores.mean(),
            "cv_std": cv_scores.std(),
        }

        mlflow.log_params(config["model"]["params"])
        mlflow.log_params({"model_type": config["model"]["type"]})
        mlflow.log_metrics(metrics)
        mlflow.log_artifact(config_path)
        mlflow.sklearn.log_model(model, "model")

        if config.get("register_model", False):
            mlflow.register_model(
                model_uri=f"runs:/{run.info.run_id}/model",
                name=config["experiment_name"].split("/")[-1]
            )

        with open("/tmp/metrics.json", "w") as f:
            json.dump(metrics, f, indent=2)

        print(f"Run ID: {run.info.run_id}")
        for k, v in metrics.items():
            print(f"  {k}: {v:.4f}")

    return run.info.run_id


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    args = parser.parse_args()

    config = load_config(args.config)
    train(config)
