"""Sentiment analysis inference client."""
import requests

MODEL_ENDPOINT = "http://loan-default-predictor.mlops.svc.cluster.local:8080"

test_texts = [
    "This is absolutely amazing!",
    "Terrible product, very disappointed.",
    "Pretty good, worth the money.",
    "I hate this, complete waste.",
]

payload = {"inputs": [[t] for t in test_texts]}

response = requests.post(
    f"{MODEL_ENDPOINT}/v2/models/sentiment-classifier/infer",
    json=payload,
    timeout=10,
)

if response.status_code == 200:
    result = response.json()
    for text, pred in zip(test_texts, result["predictions"]):
        sentiment = "positive" if pred["prediction"] == 1 else "negative"
        print(f"Text: \"{text}\"")
        print(f"Sentiment: {sentiment} (confidence: {pred.get('confidence', 'N/A')})")
        print()
else:
    print(f"Error: {response.status_code} - {response.text}")
