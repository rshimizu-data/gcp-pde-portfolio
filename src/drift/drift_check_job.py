from google.cloud import bigquery
from src.drift.drift_metrics import calc_mean_diff
from src.events.publish_event import publish_mlops_event
import datetime
import math
import pandas as pd

# ===== 設定 =====
PROJECT_ID = "churn-analysis-491912"
REGION = "asia-northeast1"

client = bigquery.Client(project=PROJECT_ID)

THRESHOLD = 0.2


def safe_float(value):
    """
    BigQuery insert_rows_json 用に、
    NaN / None を None に変換する
    """

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


def safe_bool(value):
    """
    BigQuery insert_rows_json 用に bool 型へ安全に変換する
    """

    if value is None:
        return False

    try:
        if pd.isna(value):
            return False
    except Exception:
        pass

    return bool(value)


def safe_str(value):
    """
    NaN / None を None に変換し、それ以外は文字列化する
    """

    if value is None:
        return None

    try:
        if pd.isna(value):
            return None
    except Exception:
        pass

    return str(value)


def safe_isoformat(value):
    """
    Timestamp / date / datetime を isoformat に変換する
    NaN / None の場合は None
    """

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

    # baseline取得
    baseline_query = """
    SELECT feature_name, baseline_mean
    FROM `churn-analysis-491912.ml_logs.baseline_feature_stats`
    """
    baseline_df = client.query(baseline_query, location=REGION).to_dataframe()

    # recent取得
    recent_query = """
    SELECT *
    FROM `churn-analysis-491912.ml_logs.v_recent_feature_stats`
    """
    recent_df = client.query(recent_query, location=REGION).to_dataframe()

    if recent_df.empty:
        print("No recent data. Skip.")
        return

    row = recent_df.iloc[0]

    results = []

    now = datetime.datetime.utcnow().isoformat()

    recent_column_map = {
        "login_count_7d": "avg_login_count_7d",
        "active_days_30d": "avg_active_days_30d",
        "days_since_last_login": "avg_days_since_last_login",
        "avg_session_time_30d": "avg_session_time_30d",
    }

    for _, b in baseline_df.iterrows():

        feature = b["feature_name"]
        baseline_mean = b["baseline_mean"]

        if feature not in recent_column_map:
            print(f"Skip unknown feature: {feature}")
            continue

        recent_col = recent_column_map[feature]
        recent_mean = row[recent_col]

        baseline_mean_safe = safe_float(baseline_mean)
        recent_mean_safe = safe_float(recent_mean)

        # NaN / None がある場合はdrift計算できないため、driftなしとして扱う
        if baseline_mean_safe is None or recent_mean_safe is None:
            drift_score_safe = None
            is_drift = False
            print(f"Skip drift calculation due to null value. feature={feature}")
        else:
            drift_score = calc_mean_diff(baseline_mean_safe, recent_mean_safe)
            drift_score_safe = safe_float(drift_score)
            is_drift = abs(drift_score_safe) > THRESHOLD if drift_score_safe is not None else False

        results.append({
            "check_time": now,
            "feature_name": safe_str(feature),
            "baseline_mean": baseline_mean_safe,
            "recent_mean": recent_mean_safe,
            "drift_score": drift_score_safe,
            "threshold": THRESHOLD,
            "is_drift": safe_bool(is_drift),
            "model_version": safe_str(row.get("model_version")),
            "variant": safe_str(row.get("variant")),
            "experiment_id": safe_str(row.get("experiment_id")),
            "drift_method": "mean_diff",
            "checked_window_start": safe_isoformat(row.get("window_start")),
            "checked_window_end": safe_isoformat(row.get("window_end")),
            "created_at": now
        })

    if not results:
        print("No drift results to insert. Skip.")
        return

    # BigQueryへINSERT
    table_id = "churn-analysis-491912.ml_logs.drift_results"
    errors = client.insert_rows_json(table_id, results)

    if errors:
        print("Insert error:", errors)
        return
    else:
        print("Drift results inserted.")

    # Drift判定
    drifted_results = [r for r in results if r["is_drift"]]

    retraining_required = len(drifted_results) > 0

    print(f"retraining_required={retraining_required}")

    if retraining_required:
        print("Drift detected. Publish event to Pub/Sub.")

        publish_mlops_event(
            event_type="drift_detected",
            payload={
                "source": "drift_check_job",
                "project_id": PROJECT_ID,
                "retraining_required": retraining_required,
                "reason": "drift_detected",
                "drift_count": len(drifted_results),
                "features": [r["feature_name"] for r in drifted_results],
                "drift_scores": {
                    r["feature_name"]: r["drift_score"]
                    for r in drifted_results
                },
                "model_version": drifted_results[0].get("model_version"),
                "variant": drifted_results[0].get("variant"),
                "experiment_id": drifted_results[0].get("experiment_id"),
                "action": "trigger_retraining",
            },
        )

        alert_event = {
            "source": "drift_check_job",
            "project_id": PROJECT_ID,
            "type": "drift_detected",
            "severity": "warning",
            "message": "Drift detected. Retraining required.",
            "retraining_required": True,
            "reason": "drift_detected",
            "drift_count": len(drifted_results),
            "features": [r["feature_name"] for r in drifted_results],
        }

        publish_mlops_event(
            event_type="drift_alert",
            payload=alert_event,
            topic_id="mlops-alerts",
        )
        
        print("status: drift_detected")
        print("action: publish_pubsub_event")
        print("event_type: drift_detected")
        print("reason: drift_detected")

    else:
        print("No drift. Skip event publishing.")
        print("status: no_drift")
        print("action: skip_event_publishing")


if __name__ == "__main__":
    main()