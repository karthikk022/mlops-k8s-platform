"""Feast feature definitions for the ML platform."""
from datetime import timedelta
from feast import Entity, FeatureView, Field, FileSource, ValueType
from feast.types import Float64, Int64, String


customer = Entity(
    name="customer_id",
    value_type=ValueType.INT64,
    description="Unique customer identifier",
)

transaction_source = FileSource(
    path="s3://mlops-data/features/transactions.parquet",
    timestamp_field="event_timestamp",
    created_timestamp_column="created_timestamp",
)

transaction_features = FeatureView(
    name="transaction_features",
    entities=[customer],
    ttl=timedelta(days=30),
    schema=[
        Field(name="avg_transaction_amount_30d", dtype=Float64),
        Field(name="transaction_count_30d", dtype=Int64),
        Field(name="max_transaction_amount_30d", dtype=Float64),
        Field(name="min_transaction_amount_30d", dtype=Float64),
        Field(name="std_transaction_amount_30d", dtype=Float64),
        Field(name="total_transaction_volume_30d", dtype=Float64),
        Field(name="num_late_payments_90d", dtype=Int64),
        Field(name="payment_to_income_ratio", dtype=Float64),
        Field(name="avg_days_between_transactions", dtype=Float64),
    ],
    source=transaction_source,
)

customer_profile_source = FileSource(
    path="s3://mlops-data/features/customer_profiles.parquet",
    timestamp_field="event_timestamp",
)

customer_profile_features = FeatureView(
    name="customer_profile_features",
    entities=[customer],
    ttl=timedelta(days=90),
    schema=[
        Field(name="credit_score", dtype=Int64),
        Field(name="annual_income", dtype=Float64),
        Field(name="employment_status", dtype=String),
        Field(name="years_at_current_job", dtype=Float64),
        Field(name="num_open_credit_lines", dtype=Int64),
        Field(name="total_credit_limit", dtype=Float64),
        Field(name="credit_utilization_ratio", dtype=Float64),
        Field(name="debt_to_income_ratio", dtype=Float64),
        Field(name="num_derogatory_marks", dtype=Int64),
        Field(name="bankruptcy_history", dtype=Int64),
    ],
    source=customer_profile_source,
)

loan_application_source = FileSource(
    path="s3://mlops-data/features/loan_applications.parquet",
    timestamp_field="event_timestamp",
)

loan_application_features = FeatureView(
    name="loan_application_features",
    entities=[customer],
    ttl=timedelta(days=7),
    schema=[
        Field(name="loan_amount", dtype=Float64),
        Field(name="loan_term_months", dtype=Int64),
        Field(name="interest_rate", dtype=Float64),
        Field(name="loan_purpose", dtype=String),
        Field(name="requested_loan_to_value", dtype=Float64),
    ],
    source=loan_application_source,
)
