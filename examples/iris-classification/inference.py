"""Iris model inference client."""
import requests
import json

MODEL_ENDPOINT = "http://loan-default-predictor.mlops.svc.cluster.local:8080"

samples = [
    {"sepal_length": 5.1, "sepal_width": 3.5, "petal_length": 1.4, "petal_width": 0.2},
    {"sepal_length": 6.2, "sepal_width": 3.4, "petal_length": 5.4, "petal_width": 2.3},
    {"sepal_length": 5.9, "sepal_width": 3.0, "petal_length": 4.2, "petal_width": 1.5},
]

payload = {
    "inputs": [[s["sepal_length"], s["sepal_width"], s["petal_length"], s["petal_width"]] for s in samples]
}

response = requests.post(
    f"{MODEL_ENDPOINT}/v2/models/iris-classifier/infer",
    json=payload,
    timeout=10,
)

if response.status_code == 200:
    result = response.json()
    class_names = ["setosa", "versicolor", "virginica"]
    for i, pred in enumerate(result["predictions"]):
        print(f"Sample {i+1}: {samples[i]} -> {class_names[pred['prediction']]} (confidence: {pred.get('confidence', 'N/A')})")
else:
    print(f"Error: {response.status_code} - {response.text}")
