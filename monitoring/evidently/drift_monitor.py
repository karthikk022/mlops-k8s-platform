"""Evidently drift monitoring service that sends metrics to Prometheus."""
import time
import logging
import pandas as pd
import numpy as np
from evidently import ColumnMapping
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset, RegressionPreset, ClassificationPreset
from evidently.metrics import *
from prometheus_client import start_http_server, Gauge, Counter, Histogram
import boto3
import json
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

REFERENCE_DATA_PATH = os.environ.get("REFERENCE_DATA", "s3://mlops-data/reference/train.parquet")
CURRENT_DATA_PATH = os.environ.get("CURRENT_DATA", "s3://mlops-data/current/predictions.parquet")
INTERVAL_SECONDS = int(os.environ.get("INTERVAL_SECONDS", "300"))

data_drift_score = Gauge("evidently_data_drift_score", "Data drift score", ["feature"])
model_drift_score = Gauge("evidently_model_drift_score", "Overall model drift score")
missing_values_ratio = Gauge("evidently_missing_values_ratio", "Missing values ratio", ["feature"])
prediction_distribution_ks = Gauge("evidently_prediction_ks_stat", "KS statistic for predictions")
drift_detected_counter = Counter("evidently_drift_detected_total", "Drift detected count", ["feature"])
drift_check_duration = Histogram("evidently_drift_check_seconds", "Drift check duration")


def load_data(path: str) -> pd.DataFrame:
    if path.startswith("s3://"):
        bucket, key = path.replace("s3://", "").split("/", 1)
        s3 = boto3.client("s3")
        s3.download_file(bucket, key, "/tmp/reference.parquet")
        path = "/tmp/reference.parquet"
    return pd.read_parquet(path)


@drift_check_duration.time()
def check_drift(reference: pd.DataFrame, current: pd.DataFrame):
    column_mapping = ColumnMapping(
        target="label" if "label" in reference.columns else None,
        prediction="prediction" if "prediction" in current.columns else None,
        numerical_features=reference.select_dtypes(include=[np.number]).columns.tolist(),
        categorical_features=reference.select_dtypes(include=["object"]).columns.tolist(),
    )

    report = Report(metrics=[DataDriftPreset()])
    report.run(reference_data=reference, current_data=current, column_mapping=column_mapping)

    results = report.as_dict()
    drift_metrics = results["metrics"][0]["result"]

    for feature, data in drift_metrics.get("drift_by_columns", {}).items():
        score = data.get("drift_score", 0)
        data_drift_score.labels(feature=feature).set(score)
        if data.get("drift_detected"):
            drift_detected_counter.labels(feature=feature).inc()
            logger.warning(f"Drift detected for feature '{feature}': score={score:.4f}")

    model_drift_score.set(drift_metrics.get("share_drifted_columns", 0))
    logger.info(f"Drift check complete. Drifted columns: {drift_metrics.get('number_of_drifted_columns', 0)}/{drift_metrics.get('number_of_columns', 0)}")


def main():
    start_http_server(8085)
    logger.info(f"Evidently monitor started on port 8085. Checking every {INTERVAL_SECONDS}s")

    reference = load_data(REFERENCE_DATA_PATH)
    logger.info(f"Loaded reference data: {len(reference)} rows")

    while True:
        try:
            current = load_data(CURRENT_DATA_PATH)
            if len(current) > 0:
                check_drift(reference, current)
            else:
                logger.info("No current data available yet")
        except Exception as e:
            logger.error(f"Drift check failed: {e}")

        time.sleep(INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
