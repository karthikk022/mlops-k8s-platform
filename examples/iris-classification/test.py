"""Simple pytest suite for iris classifier."""
import pytest
import numpy as np
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score


@pytest.fixture
def trained_model():
    data = load_iris()
    X_train, _, y_train, _ = train_test_split(
        data.data, data.target, test_size=0.2, random_state=42
    )
    model = RandomForestClassifier(n_estimators=100, max_depth=4, random_state=42)
    model.fit(X_train, y_train)
    return model, data


def test_model_accuracy(trained_model):
    model, data = trained_model
    _, X_test, _, y_test = train_test_split(
        data.data, data.target, test_size=0.2, random_state=42
    )
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    assert accuracy > 0.9, f"Accuracy {accuracy} < 0.9"


def test_model_output_shape(trained_model):
    model, data = trained_model
    X_test = data.data[:5]
    preds = model.predict(X_test)
    assert preds.shape == (5,), f"Expected shape (5,), got {preds.shape}"
    assert all(p in range(3) for p in preds), "Predictions out of range"


def test_model_probabilities(trained_model):
    model, data = trained_model
    X_test = data.data[:1]
    probs = model.predict_proba(X_test)
    assert probs.shape == (1, 3), f"Expected (1,3), got {probs.shape}"
    assert abs(probs.sum() - 1.0) < 1e-6, "Probabilities do not sum to 1"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
