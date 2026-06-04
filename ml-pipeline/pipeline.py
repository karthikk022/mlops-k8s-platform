"""Kubeflow pipeline definition for automated ML training."""
import kfp
from kfp import dsl, components

@dsl.component(
    base_image="python:3.11-slim",
    packages_to_install=["pandas", "numpy", "scikit-learn", "pyarrow", "great-expectations"]
)
def validate_data(dataset_path: str) -> str:
    import pandas as pd
    import great_expectations as ge

    df = pd.read_parquet(dataset_path)
    ge_df = ge.from_pandas(df)

    ge_df.expect_column_values_to_not_be_null("feature_1")
    ge_df.expect_column_values_to_be_between("feature_1", 0, 100000)
    ge_df.expect_column_values_to_not_be_null("label")
    ge_df.expect_column_values_to_be_in_set("label", [0, 1])

    results = ge_df.validate()
    assert results["success"], f"Data validation failed: {results}"
    return f"Validated {len(df)} rows"


@dsl.component(
    base_image="python:3.11-slim",
    packages_to_install=["pandas", "numpy", "scikit-learn", "pyarrow"]
)
def preprocess_data(dataset_path: str, output_path: str) -> str:
    import pandas as pd
    import numpy as np
    from sklearn.model_selection import train_test_split

    df = pd.read_parquet(dataset_path)
    df = df.dropna()
    df = pd.get_dummies(df, columns=[c for c in df.columns if df[c].dtype == "object"])

    train, test = train_test_split(df, test_size=0.2, random_state=42)

    train.to_parquet(f"{output_path}/train.parquet")
    test.to_parquet(f"{output_path}/test.parquet")
    return f"Preprocessed: {len(train)} train, {len(test)} test"


@dsl.component(
    base_image="python:3.11-slim",
    packages_to_install=["pandas", "numpy", "scikit-learn", "mlflow", "boto3", "pyarrow"]
)
def train_model(train_path: str, test_path: str, model_uri: str, experiment_name: str) -> str:
    import pandas as pd
    import numpy as np
    import mlflow
    import mlflow.sklearn
    from sklearn.ensemble import GradientBoostingClassifier
    from sklearn.metrics import accuracy_score, precision_score, recall_score

    mlflow.set_tracking_uri("http://mlflow.mlops:5000")
    mlflow.set_experiment(experiment_name)

    train = pd.read_parquet(train_path)
    test = pd.read_parquet(test_path)

    X_train = train.drop("label", axis=1)
    y_train = train["label"]
    X_test = test.drop("label", axis=1)
    y_test = test["label"]

    with mlflow.start_run() as run:
        model = GradientBoostingClassifier(
            n_estimators=100,
            max_depth=4,
            learning_rate=0.1,
            random_state=42
        )
        model.fit(X_train, y_train)

        y_pred = model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        precision = precision_score(y_test, y_pred, average="weighted")
        recall = recall_score(y_test, y_pred, average="weighted")

        mlflow.log_params({
            "n_estimators": 100,
            "max_depth": 4,
            "learning_rate": 0.1
        })
        mlflow.log_metrics({
            "accuracy": accuracy,
            "precision": precision,
            "recall": recall
        })
        mlflow.sklearn.log_model(model, "model")
        mlflow.register_model(
            model_uri=f"runs:/{run.info.run_id}/model",
            name=experiment_name.split("/")[-1]
        )

    return f"Model trained. Accuracy={accuracy:.4f}, Precision={precision:.4f}, Registered in MLflow"


@dsl.component(
    base_image="python:3.11-slim",
    packages_to_install=["pandas", "numpy", "scikit-learn", "pyarrow"]
)
def evaluate_model(test_path: str, model_uri: str, min_accuracy: float) -> str:
    import pandas as pd
    import mlflow
    from sklearn.metrics import accuracy_score

    mlflow.set_tracking_uri("http://mlflow.mlops:5000")
    model = mlflow.sklearn.load_model(model_uri)

    test = pd.read_parquet(test_path)
    X_test = test.drop("label", axis=1)
    y_test = test["label"]

    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)

    if accuracy < min_accuracy:
        raise ValueError(f"Accuracy {accuracy:.4f} below minimum {min_accuracy}")

    return f"Evaluation passed. Accuracy={accuracy:.4f} >= {min_accuracy}"


@dsl.pipeline(
    name="ML Training Pipeline",
    description="Automated ML training with validation, preprocessing, training, and evaluation"
)
def ml_training_pipeline(
    dataset_path: str = "s3://mlops-data/datasets/latest.parquet",
    experiment_name: str = "mlops-platform/default",
    min_accuracy: float = 0.80
):
    validate = validate_data(dataset_path=dataset_path)
    preprocess = preprocess_data(dataset_path=validate.output, output_path="/tmp/preprocessed")
    train = train_model(
        train_path=preprocess.output,
        test_path="/tmp/preprocessed/test.parquet",
        model_uri="s3://mlflow-artifacts",
        experiment_name=experiment_name
    )
    evaluate = evaluate_model(
        test_path="/tmp/preprocessed/test.parquet",
        model_uri=train.output,
        min_accuracy=min_accuracy
    )


if __name__ == "__main__":
    kfp.compiler.Compiler().compile(ml_training_pipeline, "ml-training-pipeline.yaml")
