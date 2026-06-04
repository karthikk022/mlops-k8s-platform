"""KServe custom model server with preprocessing and monitoring."""
import os
import json
import logging
import numpy as np
import mlflow
from typing import Dict, List, Any

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class MLOpsModel:
    def __init__(self, name: str):
        self.name = name
        self.model = None
        self.ready = False
        self.feature_order = None

    def load(self):
        model_uri = os.environ.get("MODEL_URI", "models:/default/latest")
        logger.info(f"Loading model from {model_uri}")
        self.model = mlflow.pyfunc.load_model(model_uri)
        self.ready = True
        logger.info("Model loaded successfully")

    def predict(self, features: List[float]) -> Dict[str, Any]:
        if not self.ready:
            self.load()

        X = np.array(features).reshape(1, -1)
        prediction = self.model.predict(X)
        probability = self.model.predict_proba(X) if hasattr(self.model, "predict_proba") else None

        result = {
            "prediction": int(prediction[0]),
            "model": self.name,
            "model_version": os.environ.get("MODEL_VERSION", "unknown"),
        }

        if probability is not None:
            result["probability"] = float(np.max(probability[0]))
            result["confidence"] = float(np.max(probability[0]))

        return result


_model = None


def get_model():
    global _model
    if _model is None:
        _model = MLOpsModel("mlops-model")
        _model.load()
    return _model


def handler(data: Dict[str, Any]) -> Dict[str, Any]:
    model = get_model()

    inputs = data.get("inputs", data.get("instances", []))
    if not inputs:
        raise ValueError("No inputs provided")

    results = [model.predict(item) for item in inputs]
    return {"predictions": results}
