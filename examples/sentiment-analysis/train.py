"""NLP sentiment analysis model training with MLflow tracking."""
import mlflow
import mlflow.sklearn
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import numpy as np


def load_sample_data():
    texts = [
        "This product is amazing, I love it",
        "Terrible experience, worst purchase ever",
        "Pretty good quality, satisfied with the buy",
        "Horrible customer service, very disappointed",
        "Excellent product, highly recommend to everyone",
        "Not worth the money, very poor quality",
        "Works great, exactly what I needed",
        "Disappointing, broke after one week",
        "Fantastic value for the price, very happy",
        "Awful, do not waste your money",
        "Good quality but overpriced",
        "Waste of time and money, very bad",
        "Perfect, exceeded my expectations",
        "Mediocre at best, nothing special",
        "Outstanding performance, very impressed",
        "Poor build quality, fell apart quickly",
        "Love it! Best purchase this year",
        "Returns process was a nightmare",
        "Decent product for the price point",
        "Absolutely terrible, zero stars",
    ]
    labels = [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]
    return texts, labels


mlflow.set_tracking_uri("http://mlflow.mlops:5000")
mlflow.set_experiment("mlops-platform/sentiment-analysis")

texts, labels = load_sample_data()
X_train, X_test, y_train, y_test = train_test_split(texts, labels, test_size=0.3, random_state=42)

with mlflow.start_run() as run:
    pipeline = Pipeline([
        ("tfidf", TfidfVectorizer(max_features=1000, ngram_range=(1, 2))),
        ("classifier", LogisticRegression(C=1.0, max_iter=1000, random_state=42)),
    ])
    pipeline.fit(X_train, y_train)

    y_pred = pipeline.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)

    mlflow.log_params({"vectorizer": "tfidf", "ngram_range": "(1,2)", "classifier": "logistic_regression", "C": 1.0})
    mlflow.log_metric("accuracy", accuracy)

    mlflow.sklearn.log_model(pipeline, "model")
    mlflow.register_model(model_uri=f"runs:/{run.info.run_id}/model", name="sentiment-classifier")

    print(f"Run ID: {run.info.run_id}")
    print(f"Accuracy: {accuracy:.4f}")
    print(classification_report(y_test, y_pred, target_names=["negative", "positive"]))
