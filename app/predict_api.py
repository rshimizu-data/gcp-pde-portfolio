from __future__ import annotations

import io
import os
import pickle
import json
import uuid
import logging

from datetime import datetime, timezone
from typing import Any

import pandas as pd
from flask import Flask, jsonify, request
from google.cloud import storage
from google.cloud import bigquery


DROP_COLS = [
    "user_id",
    "label_churn",
    "signup_date",
    "base_date",
    "login_per_active_day_7d",
    "future_login_count_30d",
]

CATEGORICAL_COLS = [
    "plan_type",
    "gender",
    "user_tenure_segment",
    "activity_segment_30d",
]

# モデル学習時の列順に合わせた完成版
DEFAULT_FEATURE_COLUMNS = [
    "signup_days",
    "plan_type",
    "age",
    "gender",
    "login_count_7d",
    "active_days_7d",
    "total_session_time_7d",
    "avg_session_time_7d",
    "login_count_14d",
    "active_days_14d",
    "total_session_time_14d",
    "avg_session_time_14d",
    "login_count_30d",
    "active_days_30d",
    "total_session_time_30d",
    "avg_session_time_30d",
    "login_count_prev_7d",
    "active_days_prev_7d",
    "total_session_time_prev_7d",
    "avg_session_time_prev_7d",
    "login_count_prev_14d",
    "active_days_prev_14d",
    "total_session_time_prev_14d",
    "avg_session_time_prev_14d",
    "days_since_last_login",
    "login_count_diff_7d",
    "active_days_diff_7d",
    "total_session_time_diff_7d",
    "login_count_diff_14d",
    "active_days_diff_14d",
    "total_session_time_diff_14d",
    "login_count_ratio_7d",
    "active_days_ratio_7d",
    "total_session_time_ratio_7d",
    "login_ratio_7d_30d",
    "active_days_ratio_7d_30d",
    "session_time_ratio_7d_30d",
    "login_ratio_14d_30d",
    "session_time_ratio_14d_30d",
    "avg_login_per_day_30d",
    "active_day_rate_30d",
    "avg_session_time_per_login_30d",
    "avg_session_time_per_active_day_30d",
    "session_per_active_day_7d",
    "is_login_declining",
    "is_session_declining",
    "is_shrinking_14d_vs_prev14d",
    "recently_dropped_to_zero",
    "momentum_7d_14d",
    "session_momentum_7d_14d",
    "recency_ratio_7d_30d",
    "is_inactive_7d",
    "is_inactive_14d",
    "is_inactive_30d",
    "is_low_activity_30d",
    "is_mid_low_activity_30d",
    "recency_ge_7d",
    "recency_ge_14d",
    "recency_ge_30d",
    "user_tenure_segment",
    "activity_segment_30d",
]

MODEL_URI = os.getenv("MODEL_URI", "")
PROJECT_ID = os.getenv("PROJECT_ID") or os.getenv("GOOGLE_CLOUD_PROJECT", "")
PORT = int(os.getenv("PORT", "8080"))

MODEL_VERSION = os.getenv("MODEL_VERSION", "v1")
EXPERIMENT_ID = os.getenv("EXPERIMENT_ID", "default")
MODEL_VARIANT = os.getenv("MODEL_VARIANT", "default")
BQ_LOG_TABLE = os.getenv(
    "BQ_LOG_TABLE",
    "churn-analysis-491912.ml_logs.prediction_logs",
)
PREDICTION_THRESHOLD = float(os.getenv("PREDICTION_THRESHOLD", "0.5"))

bq_client = bigquery.Client(project=PROJECT_ID or None)

app = Flask(__name__)

MODEL = None
FEATURE_COLUMNS: list[str] = DEFAULT_FEATURE_COLUMNS.copy()
MODEL_CATEGORICAL_COLS: list[str] = CATEGORICAL_COLS.copy()
TRAIN_CATEGORY_MAP: dict[str, list[Any]] = {}

def insert_prediction_log(
    request_id,
    request_time,
    user_id,
    input_features,
    prediction,
    prediction_probability,
    metadata=None
):
    row = {
        "request_id": request_id,
        "request_time": request_time.isoformat(),
        "user_id": str(user_id) if user_id is not None else None,
        "model_version": MODEL_VERSION,
        "model_uri": MODEL_URI,
        "experiment_id": EXPERIMENT_ID,
        "variant": MODEL_VARIANT,
        "input_features_json": json.dumps(
            input_features,
            ensure_ascii=False
        ),
        "prediction": int(prediction),
        "prediction_probability": float(
            prediction_probability
        ),
        "threshold": float(
            PREDICTION_THRESHOLD
        ),
        "metadata_json": json.dumps(
            metadata or {},
            ensure_ascii=False
        ),
        "created_at": datetime.now(
            timezone.utc
        ).isoformat()
    }

    errors = bq_client.insert_rows_json(
        BQ_LOG_TABLE,
        [row]
    )

    if errors:
        logging.error(
            f"BigQuery insert error: {errors}"
        )
        return False

    return True

def parse_gcs_uri(uri: str) -> tuple[str, str]:
    if not uri.startswith("gs://"):
        raise ValueError(f"MODEL_URI must start with 'gs://': {uri}")

    path = uri.replace("gs://", "", 1)
    parts = path.split("/", 1)
    if len(parts) != 2:
        raise ValueError(f"Invalid GCS URI: {uri}")

    bucket_name, blob_name = parts
    return bucket_name, blob_name


def load_pickle_from_gcs(gcs_uri: str) -> Any:
    bucket_name, blob_name = parse_gcs_uri(gcs_uri)
    client = storage.Client(project=PROJECT_ID or None)
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(blob_name)
    data = blob.download_as_bytes()
    return pickle.load(io.BytesIO(data))


def build_feature_df(records: list[dict[str, Any]]) -> pd.DataFrame:
    df = pd.DataFrame(records)

    cols_to_drop = [c for c in DROP_COLS if c in df.columns]
    if cols_to_drop:
        df = df.drop(columns=cols_to_drop)

    for col in FEATURE_COLUMNS:
        if col not in df.columns:
            df[col] = pd.NA

    df = df[FEATURE_COLUMNS]

    for col in MODEL_CATEGORICAL_COLS:
        if col in df.columns:
            if col in TRAIN_CATEGORY_MAP and TRAIN_CATEGORY_MAP[col]:
                df[col] = pd.Categorical(df[col], categories=TRAIN_CATEGORY_MAP[col])
            else:
                df[col] = df[col].astype("category")

    return df


def validate_payload(payload: Any) -> list[dict[str, Any]]:
    if payload is None:
        raise ValueError("Request body must be valid JSON.")

    if isinstance(payload, dict):
        if "instances" in payload:
            instances = payload["instances"]
            if isinstance(instances, dict):
                return [instances]
            if isinstance(instances, list):
                if not all(isinstance(x, dict) for x in instances):
                    raise ValueError("'instances' must be a dict or a list of dicts.")
                return instances
            raise ValueError("'instances' must be a dict or a list of dicts.")
        return [payload]

    if isinstance(payload, list):
        if not all(isinstance(x, dict) for x in payload):
            raise ValueError("JSON array must contain only objects.")
        return payload

    raise ValueError("Unsupported JSON format.")


def load_model_once() -> None:
    global MODEL, FEATURE_COLUMNS, MODEL_CATEGORICAL_COLS, TRAIN_CATEGORY_MAP

    if MODEL is not None:
        return

    if not MODEL_URI:
        raise ValueError("MODEL_URI env var is required. Example: gs://your-bucket/models/model.pkl")

    artifact = load_pickle_from_gcs(MODEL_URI)

    if isinstance(artifact, dict) and "model" in artifact:
        MODEL = artifact["model"]
        FEATURE_COLUMNS = artifact.get("feature_columns", DEFAULT_FEATURE_COLUMNS.copy())
        MODEL_CATEGORICAL_COLS = artifact.get("categorical_columns", CATEGORICAL_COLS.copy())
        TRAIN_CATEGORY_MAP = artifact.get("category_map", {})
    else:
        MODEL = artifact
        FEATURE_COLUMNS = DEFAULT_FEATURE_COLUMNS.copy()
        MODEL_CATEGORICAL_COLS = CATEGORICAL_COLS.copy()
        TRAIN_CATEGORY_MAP = {}


@app.route("/", methods=["GET"])
def root():
    return jsonify(
        {
            "message": "predict-api is running",
            "model_uri": MODEL_URI,
            "predict_endpoint": "/predict",
        }
    )


@app.route("/health", methods=["GET"])
def health():
    try:
        load_model_once()
        return jsonify({"status": "ok"}), 200
    except Exception as e:
        return jsonify({"status": "ng", "error": str(e)}), 500


@app.route("/predict", methods=["POST"])
def predict():
    try:
        load_model_once()

        payload = request.get_json(silent=False)

        request_id = str(uuid.uuid4())
        request_time = datetime.now(timezone.utc)

        if isinstance(payload, dict):
            user_id = payload.get("user_id")
            metadata = payload.get("metadata", {})
        else:
            user_id = None
            metadata = {}

        records = validate_payload(payload)
        df = build_feature_df(records)

        probs = MODEL.predict_proba(df)[:, 1]

        predictions = []
        for i, p in enumerate(probs):
            predictions.append(
                {
                    "index": i,
                    "churn_probability": float(p),
                    "churn_prediction": int(p >= PREDICTION_THRESHOLD),
                }
            )

        try:
            if predictions:
                insert_prediction_log(
                    request_id=request_id,
                    request_time=request_time,
                    user_id=user_id,
                    input_features=payload,
                    prediction=predictions[0]["churn_prediction"],
                    prediction_probability=predictions[0]["churn_probability"],
                    metadata=metadata
                )
        except Exception as e:
            logging.exception(
                f"Failed to insert prediction log: {e}"
            )

        return jsonify(
            {
                "request_id": request_id,
                "model_version": MODEL_VERSION,
                "n_predictions": len(predictions),
                "predictions": predictions,
            }
        ), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 400


if __name__ == "__main__":
    load_model_once()
    app.run(host="0.0.0.0", port=PORT, debug=False)