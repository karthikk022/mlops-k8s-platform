import argparse
import pandas as pd
import numpy as np
from sklearn.datasets import make_classification
import os


def generate_loan_default_data(
    output_path: str,
    n_samples: int = 10000,
    n_features: int = 20,
    random_state: int = 42,
):
    X, y = make_classification(
        n_samples=n_samples,
        n_features=n_features,
        n_informative=10,
        n_redundant=5,
        n_clusters_per_class=2,
        flip_y=0.05,
        random_state=random_state,
    )

    feature_names = [
        "credit_score",
        "annual_income",
        "debt_to_income_ratio",
        "loan_amount",
        "loan_term_months",
        "interest_rate",
        "employment_years",
        "num_open_credit_lines",
        "total_credit_limit",
        "credit_utilization_ratio",
        "num_late_payments_2yr",
        "num_derogatory_marks",
        "bankruptcy_history",
        "loan_to_value_ratio",
        "dti_monthly_payment",
        "residential_units",
        "occupancy_type",
        "property_value",
        "origination_loan_amount",
        "remaining_balance_ratio",
    ]

    df = pd.DataFrame(X, columns=feature_names[:n_features])
    df["label"] = y
    df["customer_id"] = np.arange(n_samples)
    df["event_timestamp"] = pd.Timestamp.now()

    os.makedirs(output_path, exist_ok=True)
    df.to_parquet(os.path.join(output_path, "dataset.parquet"), index=False)

    print(f"Generated {n_samples} rows, {n_features + 2} columns")
    print(f"Class distribution: {pd.Series(y).value_counts().to_dict()}")
    print(f"Saved to {output_path}/dataset.parquet")

    return df


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="/tmp/mlops-data", type=str)
    parser.add_argument("--samples", default=10000, type=int)
    args = parser.parse_args()
    generate_loan_default_data(args.output, args.samples)
