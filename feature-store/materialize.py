"""Materialize features from offline store to online store."""
import argparse
from datetime import datetime, timedelta
from feast import FeatureStore
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def materialize(feature_view: str = None, days: int = 30):
    store = FeatureStore(repo_path="feature-store")

    end_date = datetime.now()
    start_date = end_date - timedelta(days=days)

    if feature_view:
        logger.info(f"Materializing {feature_view} from {start_date} to {end_date}")
        store.materialize(
            feature_views=[feature_view],
            start_date=start_date,
            end_date=end_date,
        )
    else:
        logger.info(f"Materializing all features from {start_date} to {end_date}")
        store.materialize(
            start_date=start_date,
            end_date=end_date,
        )

    logger.info("Materialization complete")


def get_online_features(entity_ids: list, features: list):
    store = FeatureStore(repo_path="feature-store")
    entity_rows = [{"customer_id": eid} for eid in entity_ids]
    feature_vector = store.get_online_features(
        features=features,
        entity_rows=entity_rows,
    ).to_dict()

    return feature_vector


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["materialize", "serve"], default="materialize")
    parser.add_argument("--feature-view", default=None)
    parser.add_argument("--days", type=int, default=30)
    args = parser.parse_args()

    if args.mode == "materialize":
        materialize(args.feature_view, args.days)
    elif args.mode == "serve":
        import uvicorn
        from fastapi import FastAPI

        app = FastAPI()

        @app.get("/features/{customer_id}")
        def features(customer_id: int):
            result = get_online_features(
                entity_ids=[customer_id],
                features=[
                    "transaction_features:avg_transaction_amount_30d",
                    "transaction_features:transaction_count_30d",
                    "customer_profile_features:credit_score",
                    "customer_profile_features:annual_income",
                    "loan_application_features:loan_amount",
                ],
            )
            return result

        uvicorn.run(app, host="0.0.0.0", port=6566)
