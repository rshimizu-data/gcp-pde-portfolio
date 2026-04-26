from __future__ import annotations

from pathlib import Path
from typing import Any

import lightgbm as lgb
from sklearn.model_selection import train_test_split

from src.common.bq_client import BigQueryClient
from src.common.config_loader import load_yaml
from src.common.gcs_client import GCSClient
from src.common.logger import get_logger
from src.trainer.evaluate import evaluate_binary_classifier
from src.trainer.preprocess import preprocess_features
from src.trainer.save_artifacts import save_local_artifacts, upload_artifacts_to_gcs

logger = get_logger(__name__)


def build_training_query(project_id: str, dataset: str, table: str) -> str:
    return f"""
    SELECT *
    FROM `{project_id}.{dataset}.{table}`
    """


def run_training(
    settings_path: str = "config/settings.yaml",
    model_config_path: str = "config/model_config.yaml",
    output_dir: str = "data/local_outputs",
) -> dict[str, Any]:
    settings = load_yaml(settings_path)
    model_config = load_yaml(model_config_path)

    project_id = settings["project_id"]
    feature_dataset = settings["datasets"]["feature"]
    gcs_bucket = settings["gcs_bucket"]
    model_name = settings["model"]["name"]
    model_version = settings["model"]["version"]
    threshold = float(settings["model"]["threshold"])

    feature_columns = model_config["feature_columns"]
    target_column = model_config["target_column"]
    test_size = float(model_config["train"]["test_size"])
    random_state = int(model_config["train"]["random_state"])

    query = build_training_query(
        project_id=project_id,
        dataset=feature_dataset,
        table="user_churn_features",
    )

    logger.info("Read feature table from BigQuery")
    bq_client = BigQueryClient(project_id=project_id)
    df = bq_client.query_to_dataframe(query)

    x, y = preprocess_features(
        df=df,
        feature_columns=feature_columns,
        target_column=target_column,
    )

    x_train, x_valid, y_train, y_valid = train_test_split(
        x, y,
        test_size=test_size,
        random_state=random_state,
        stratify=y,
    )

    logger.info("Train LightGBM")
    model = lgb.LGBMClassifier(**model_config["lightgbm"])
    model.fit(x_train, y_train)

    y_proba = model.predict_proba(x_valid)[:, 1]
    metrics = evaluate_binary_classifier(
        y_true=y_valid.to_numpy(),
        y_proba=y_proba,
        threshold=threshold,
    )

    metrics["model_name"] = model_name
    metrics["model_version"] = model_version
    metrics["train_rows"] = int(len(x_train))
    metrics["valid_rows"] = int(len(x_valid))

    local_paths = save_local_artifacts(
        model=model,
        metrics=metrics,
        feature_columns=feature_columns,
        output_dir=Path(output_dir),
    )

    logger.info("Upload artifacts to GCS")
    gcs_client = GCSClient(bucket_name=gcs_bucket, project_id=project_id)
    upload_artifacts_to_gcs(
        gcs_client=gcs_client,
        local_paths=local_paths,
        model_name=model_name,
        model_version=model_version,
    )

    logger.info("Training finished")
    return metrics


if __name__ == "__main__":
    result = run_training()
    print(result)
