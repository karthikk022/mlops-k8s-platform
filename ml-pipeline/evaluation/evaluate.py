"""Model evaluation and validation gate."""
import argparse
import pandas as pd
import numpy as np
import mlflow
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    confusion_matrix, classification_report, roc_auc_score
)
import json


def evaluate(model_uri: str, test_path: str, target_column: str, min_metrics: dict, tracking_uri: str = "http://mlflow.mlops:5000"):
    mlflow.set_tracking_uri(tracking_uri)

    model = mlflow.sklearn.load_model(model_uri)
    test = pd.read_parquet(test_path)

    X_test = test.drop(target_column, axis=1)
    y_test = test[target_column]

    y_pred = model.predict(X_test)
    y_proba = model.predict_proba(X_test)[:, 1] if hasattr(model, "predict_proba") else None

    metrics = {
        "accuracy": accuracy_score(y_test, y_pred),
        "precision": precision_score(y_test, y_pred, average="weighted"),
        "recall": recall_score(y_test, y_pred, average="weighted"),
        "f1": f1_score(y_test, y_pred, average="weighted"),
    }

    if y_proba is not None and len(np.unique(y_test)) == 2:
        metrics["roc_auc"] = roc_auc_score(y_test, y_proba)

    cm = confusion_matrix(y_test, y_pred)
    report = classification_report(y_test, y_pred, output_dict=True)

    results = {"metrics": metrics, "confusion_matrix": cm.tolist(), "classification_report": report}

    with open("/tmp/evaluation_results.json", "w") as f:
        json.dump(results, f, indent=2)

    print("Evaluation Results:")
    for k, v in metrics.items():
        status = "PASS" if k not in min_metrics or v >= min_metrics[k] else "FAIL"
        print(f"  {k}: {v:.4f} [{status}]")

    for metric, threshold in min_metrics.items():
        if metric in metrics and metrics[metric] < threshold:
            raise ValueError(f"Gate failed: {metric}={metrics[metric]:.4f} < {threshold}")

    print("All gates passed. Model promoted.")
    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-uri", required=True)
    parser.add_argument("--test-path", required=True)
    parser.add_argument("--target", default="label")
    parser.add_argument("--min-accuracy", type=float, default=0.80)
    parser.add_argument("--min-precision", type=float, default=0.75)
    parser.add_argument("--min-recall", type=float, default=0.75)
    args = parser.parse_args()

    min_metrics = {
        "accuracy": args.min_accuracy,
        "precision": args.min_precision,
        "recall": args.min_recall,
    }

    evaluate(args.model_uri, args.test_path, args.target, min_metrics)
