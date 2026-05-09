from google.cloud import bigquery
from src.events.publish_event import publish_mlops_event
import datetime
import pandas as pd

PROJECT_ID = "churn-analysis-491912"
REGION = "asia-northeast1"

client = bigquery.Client(project=PROJECT_ID)

MIN_PREDICTION_COUNT = 1
MAX_NULL_RATE = 0.0

def main():
    query = """
    SELECT
      COUNT(*) AS prediction_count,
      COUNTIF(prediction IS NULL) AS null_prediction_count,
      COUNTIF(prediction_probability IS NULL) AS null_probability_count,
      COUNTIF(user_id IS NULL) AS null_user_id_count,
      COUNTIF(model_version IS NULL) AS null_model_version_count,
      COUNTIF(variant IS NULL) AS null_variant_count,
      AVG(prediction_probability) AS avg_probability
    FROM `churn-analysis-491912.ml_logs.prediction_logs`
    WHERE request_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
    """

    df = client.query(query, location=REGION).to_dataframe()
    row = df.iloc[0]

    prediction_count = int(row["prediction_count"])
    null_prediction_count = int(row["null_prediction_count"])
    null_probability_count = int(row["null_probability_count"])
    null_user_id_count = int(row["null_user_id_count"])
    null_model_version_count = int(row["null_model_version_count"])
    null_variant_count = int(row["null_variant_count"])
    avg_probability = row["avg_probability"]

    anomalies = []

    if prediction_count < MIN_PREDICTION_COUNT:
        anomalies.append("prediction_count_too_low")

    if null_prediction_count > 0:
        anomalies.append("null_prediction_detected")

    if null_probability_count > 0:
        anomalies.append("null_probability_detected")

    if null_user_id_count > 0:
        anomalies.append("null_user_id_detected")

    if null_model_version_count > 0:
        anomalies.append("null_model_version_detected")

    if null_variant_count > 0:
        anomalies.append("null_variant_detected")

    anomaly_detected = len(anomalies) > 0

    print(f"prediction_count={prediction_count}")
    print(f"null_prediction_count={null_prediction_count}")
    print(f"null_probability_count={null_probability_count}")
    print(f"null_user_id_count={null_user_id_count}")
    print(f"null_model_version_count={null_model_version_count}")
    print(f"null_variant_count={null_variant_count}")
    print(f"avg_probability={avg_probability}")
    print(f"anomaly_detected={anomaly_detected}")
    print(f"anomalies={anomalies}")

    if anomaly_detected:
        publish_mlops_event(
            event_type="prediction_anomaly",
            payload={
                "source": "prediction_anomaly_check",
                "project_id": PROJECT_ID,
                "severity": "warning",
                "message": "Prediction anomaly detected.",
                "prediction_count": prediction_count,
                "null_prediction_count": null_prediction_count,
                "null_probability_count": null_probability_count,
                "null_user_id_count": null_user_id_count,
                "null_model_version_count": null_model_version_count,
                "null_variant_count": null_variant_count,
                "avg_probability": None if pd.isna(avg_probability) else float(avg_probability),
                "anomalies": anomalies,
                "checked_window": "last_24_hours",
            },
            topic_id="mlops-alerts",
        )

        print("status: anomaly_detected")
        print("action: publish_alert_event")

    else:
        print("status: no_anomaly")
        print("action: skip_alert_event")

if __name__ == "__main__":
    main()
