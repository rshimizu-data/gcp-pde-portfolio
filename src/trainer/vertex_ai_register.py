from __future__ import annotations

import datetime
import os

from google.cloud import aiplatform


PROJECT_ID = os.environ.get("PROJECT_ID")
REGION = os.environ.get("REGION", "asia-northeast1")

EXPERIMENT_ID = os.environ.get("EXPERIMENT_ID", "churn-experiment-001")
MODEL_VERSION = os.environ.get("MODEL_VERSION", "v1")
MODEL_DISPLAY_NAME = os.environ.get("MODEL_DISPLAY_NAME", "churn-lightgbm")


def register_to_vertex(auc: float, model_uri: str) -> aiplatform.Model:
    aiplatform.init(
        project=PROJECT_ID,
        location=REGION,
        experiment=EXPERIMENT_ID,
    )

    run_name = f"{MODEL_VERSION}-{datetime.datetime.utcnow().strftime('%Y%m%d%H%M%S')}"

    with aiplatform.start_run(run=run_name):
        aiplatform.log_params(
            {
                "experiment_id": EXPERIMENT_ID,
                "model_version": MODEL_VERSION,
                "run_name": run_name,
                "model_uri": model_uri,
                "model_type": "LightGBM",
            }
        )

        aiplatform.log_metrics(
            {
                "auc": float(auc),
            }
        )

    artifact_uri = model_uri.rsplit("/", 1)[0] + "/"

    model = aiplatform.Model.upload(
        display_name=MODEL_DISPLAY_NAME,
        artifact_uri=artifact_uri,
        serving_container_image_uri="asia-docker.pkg.dev/vertex-ai/prediction/sklearn-cpu.1-5:latest",
        labels={
            "model-version": MODEL_VERSION,
            "experiment-id": EXPERIMENT_ID,
        },
    )

    return model
