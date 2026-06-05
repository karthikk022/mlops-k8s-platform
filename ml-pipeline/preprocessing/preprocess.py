"""Feature engineering and data preprocessing pipeline."""
import argparse
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder
import pyarrow.parquet as pq
import json
import os


def preprocess(input_path: str, output_path: str, test_size: float, target_column: str):
    df = pd.read_parquet(input_path)
    print(f"Loaded {len(df)} rows, {len(df.columns)} columns")

    numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
    categorical_cols = df.select_dtypes(include=["object", "category"]).columns.tolist()

    if target_column in numeric_cols:
        numeric_cols.remove(target_column)
    if target_column in categorical_cols:
        categorical_cols.remove(target_column)

    df = df.dropna(subset=[target_column])
    print(f"After dropping null targets: {len(df)} rows")

    for col in numeric_cols:
        df[col] = df[col].fillna(df[col].median())

    for col in categorical_cols:
        df[col] = df[col].fillna("MISSING")
        le = LabelEncoder()
        df[col] = le.fit_transform(df[col].astype(str))

    scaler = StandardScaler()
    if numeric_cols:
        df[numeric_cols] = scaler.fit_transform(df[numeric_cols])

    feature_cols = numeric_cols + categorical_cols
    drop_cols = [c for c in df.columns if c not in feature_cols and c != target_column]
    if drop_cols:
        print(f"Dropping non-feature columns: {drop_cols}")
    df = df.drop(columns=drop_cols)

    os.makedirs(output_path, exist_ok=True)

    train, test = train_test_split(df, test_size=test_size, random_state=42, stratify=df[target_column])

    train.to_parquet(os.path.join(output_path, "train.parquet"))
    test.to_parquet(os.path.join(output_path, "test.parquet"))

    metadata = {
        "input_rows": len(df),
        "train_rows": len(train),
        "test_rows": len(test),
        "numeric_features": numeric_cols,
        "categorical_features": categorical_cols,
        "target_column": target_column,
    }
    with open(os.path.join(output_path, "metadata.json"), "w") as f:
        json.dump(metadata, f, indent=2)

    print(f"Preprocessing complete: {len(train)} train, {len(test)} test")
    print(f"Features: {len(numeric_cols)} numeric, {len(categorical_cols)} categorical")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", default="/tmp/preprocessed")
    parser.add_argument("--test-size", type=float, default=0.2)
    parser.add_argument("--target", default="label")
    args = parser.parse_args()

    preprocess(args.input, args.output, args.test_size, args.target)
