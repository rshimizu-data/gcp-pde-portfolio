from google.cloud import bigquery
from drift_metrics import calc_mean_diff
from src.events.publish_event import publish_mlops_event
import datetime
import math
import pandas as pd
import os

# ===== 設定 =====
PROJECT_ID = os.environ.get("PROJECT_ID", "churn-analysis-491912")
REGION = os.environ.get("BQ_LOCATION", "asia-northeast1")

client = bigquery.Client(project=PROJECT_ID)

THRESHOLD = 0.2


def safe_float(value):
    if value is None:
        return None
    try:
        if pd.isna(value):
            return None
    except Exception:
        pass
    try:
        value = float(value)
        if math.isnan(value):
            return None
        return value
    except Exception:
        return None


def safe_str(value):
    if value is None:
        return None
    try:
        if pd.isna(value):
            return None
    except Exception:
        pass
    return str(value)


def safe_iso(value):
    if value is None:
        return None
    try:
        if pd.isna(value):
            return None
    except Exception:
        pass
    try:
        return value.isoformat()
    except Exception:
        return str(value)


def main():
    print("==== Drift Check Job Start ====")

    baseline_query = """
    SELECT feature_name, baseline_mean
    FROM `churn-analysis-491912.ml_logs.baseline_feature_stats`
    """

    recent_query = """
    SELECT *
    FROM `churn-analysis-491912.ml_logs.v_recent_feature_stats`
    """

    baseline_df = client.query(baseline_query, location=REGION).to_dataframe()
    recent_df = client.query(recent_query, location=REGION).to_dataframe()

    if recent_df.empty:
        print("No recent data. Skip.")
        return

    row = recent_df.iloc[0]

    results = []
    now = datetime.datetime.utcnow().isoformat()

    column_map = {
        "login_count_7d": "avg_login_count_7d",
        "active_days_30d": "avg_active_days_30d",
        "days_since_last_login": "avg_days_since_last_login",
        "avg_session_time_30d": "avg_session_time_30d",
    }

    for _, b in baseline_df.iterrows():
        feature = b["feature_name"]

        if feature not in column_map:
            continue

        baseline_mean = safe_float(b["baseline_mean"])
        recent_mean = safe_float(row[column_map[feature]])

        if baseline_mean is None or recent_mean is None:
            drift_score = None
            is_drift = False
        else:
            drift_score = safe_float(calc_mean_diff(baseline_mean, recent_mean))
            is_drift = abs(drift_score) > THRESHOLD if drift_score else False

        results.append({
            "check_time": now,
            "feature_name": safe_str(feature),
            "baseline_mean": baseline_mean,
            "recent_mean": recent_mean,
            "drift_score": drift_score,
            "threshold": THRESHOLD,
            "is_drift": bool(is_drift),
            "model_version": safe_str(row.get("model_version")),
            "variant": safe_str(row.get("variant")),
            "experiment_id": safe_str(row.get("experiment_id")),
            "checked_window_start": safe_iso(row.get("window_start")),
            "checked_window_end": safe_iso(row.get("window_end")),
            "created_at": now
        })

    table_id = "churn-analysis-491912.ml_logs.drift_results"
    errors = client.insert_rows_json(table_id, results)

    if errors:
        print("Insert error:", errors)
        return

    drifted = [r for r in results if r["is_drift"]]

    if drifted:
        print("Drift detected → publish event")

        publish_mlops_event(
            event_type="drift_detected",
            payload={
                "source": "drift_job",
                "drift_count": len(drifted),
                "features": [r["feature_name"] for r in drifted],
                "action": "trigger_retraining",
            },
        )

    else:
        print("No drift detected.")


if __name__ == "__main__":
    main()