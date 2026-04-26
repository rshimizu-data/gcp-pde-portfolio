from __future__ import annotations

import os
import pickle

import lightgbm as lgb
import pandas as pd
from flask import Flask, jsonify
from google.cloud import bigquery, storage
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import train_test_split

app = Flask(__name__)

PROJECT_ID = os.environ.get("PROJECT_ID")
DATASET = os.environ.get("BQ_DATASET", "feature")
TABLE = os.environ.get("BQ_TABLE", "user_churn_features")
BUCKET_NAME = os.environ.get("MODEL_BUCKET")
BQ_LOCATION = os.environ.get("BQ_LOCATION", "asia-northeast1")

TARGET_COL = "label_churn"
CATEGORICAL_COLS = [
    "plan_type",
    "gender",
    "user_tenure_segment",
    "activity_segment_30d",
]

DROP_COLS = [
    "user_id",
    "label_churn",
    "future_login_count_30d",
    "signup_date",
    "base_date",
    "login_per_active_day_7d",  # 追加
]


def load_data_from_bigquery() -> pd.DataFrame:
    client = bigquery.Client(project=PROJECT_ID, location=BQ_LOCATION)

    query = f"""
    SELECT *
    FROM `{PROJECT_ID}.{DATASET}.{TABLE}`
    """

    df = client.query(query, location=BQ_LOCATION).to_dataframe()
    return df


def preprocess(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.Series]:
    y = df[TARGET_COL].copy()
    X = df.drop(columns=[c for c in DROP_COLS if c in df.columns]).copy()

    for col in CATEGORICAL_COLS:
        if col in X.columns:
            X[col] = X[col].astype("category")

    return X, y


def train_and_save_model() -> dict:
    df = load_data_from_bigquery()
    X, y = preprocess(df)

    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=0.2,
        random_state=42,
        stratify=y,
    )

    model = lgb.LGBMClassifier(
        objective="binary",

        n_estimators=500,
        learning_rate=0.03,

        num_leaves=31,
        min_child_samples=20,

        subsample=0.8,
        colsample_bytree=0.8,

        class_weight="balanced",

        random_state=42,
    )

    model.fit(
        X_train,
        y_train,
        eval_set=[(X_test, y_test)],
        eval_metric="auc",
        categorical_feature=[c for c in CATEGORICAL_COLS if c in X_train.columns],
        callbacks=[lgb.early_stopping(50), lgb.log_evaluation(50)],
    )

    y_pred = model.predict_proba(X_test)[:, 1]
    auc = roc_auc_score(y_test, y_pred)

    local_model_path = "/tmp/model.pkl"
    with open(local_model_path, "wb") as f:
        pickle.dump(model, f)

    storage_client = storage.Client(project=PROJECT_ID)
    bucket = storage_client.bucket(BUCKET_NAME)
    blob = bucket.blob("models/model.pkl")
    blob.upload_from_filename(local_model_path)

    importance_df = pd.DataFrame(
        {
            "feature": X_train.columns,
            "importance": model.feature_importances_,
        }
    ).sort_values("importance", ascending=False)

    return {
        "rows": int(len(df)),
        "train_rows": int(len(X_train)),
        "test_rows": int(len(X_test)),
        "auc": float(auc),
        "model_path": f"gs://{BUCKET_NAME}/models/model.pkl",
        "top_features": importance_df.head(10).to_dict(orient="records"),
    }


@app.route("/", methods=["GET", "POST"])
def run_training():
    result = train_and_save_model()
    return jsonify({"status": "ok", "result": result})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)