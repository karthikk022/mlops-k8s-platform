"""Reference ML training example: Iris classification."""
import mlflow
import mlflow.sklearn
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report
import warnings

warnings.filterwarnings("ignore")

mlflow.set_tracking_uri("http://mlflow.mlops:5000")
mlflow.set_experiment("mlops-platform/iris-classification")

data = load_iris()
X_train, X_test, y_train, y_test = train_test_split(
    data.data, data.target, test_size=0.2, random_state=42
)

with mlflow.start_run() as run:
    model = RandomForestClassifier(n_estimators=100, max_depth=4, random_state=42)
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)

    mlflow.log_params({"n_estimators": 100, "max_depth": 4})
    mlflow.log_metric("accuracy", accuracy)
    mlflow.sklearn.log_model(model, "model")

    mlflow.register_model(
        model_uri=f"runs:/{run.info.run_id}/model",
        name="iris-classifier"
    )

    print(f"Run ID: {run.info.run_id}")
    print(f"Accuracy: {accuracy:.4f}")
    print(f"Classes: {data.target_names}")
    print(classification_report(y_test, y_pred, target_names=data.target_names))
