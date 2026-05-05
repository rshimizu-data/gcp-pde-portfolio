from google.cloud import bigquery
from src.events.publish_event import publish_mlops_event

PROJECT_ID = "churn-analysis-491912"
BQ_LOCATION = "asia-northeast1"

client = bigquery.Client(project=PROJECT_ID)


def main():
    """
    A/B test結果を確認し、必要に応じてPub/Subへイベント送信する
    """

    query = """
    SELECT
      experiment_id,
      control_avg_probability,
      treatment_avg_probability,
      probability_diff,
      control_count,
      treatment_count
    FROM `churn-analysis-491912.ml_logs.v_ab_test_comparison`
    WHERE experiment_id = 'ab_test_001'
    LIMIT 1
    """

    rows = list(client.query(query, location=BQ_LOCATION).result())

    if not rows:
        print("No A/B test comparison result.")
        return

    row = rows[0]

    # 簡易判定ルール
    # treatmentの離脱確率がcontrolより高い場合、悪化とみなす
    is_degraded = row["probability_diff"] > 0

    if is_degraded:
        print("A/B test degraded. Publish event to Pub/Sub.")

        publish_mlops_event(
            event_type="ab_test_degraded",
            payload={
                "source": "ab_test_event_publisher",
                "project_id": PROJECT_ID,
                "experiment_id": row["experiment_id"],
                "control_avg_probability": float(row["control_avg_probability"]),
                "treatment_avg_probability": float(row["treatment_avg_probability"]),
                "probability_diff": float(row["probability_diff"]),
                "control_count": int(row["control_count"]),
                "treatment_count": int(row["treatment_count"]),
                "action": "trigger_retraining",
            },
        )

    else:
        print("A/B test is not degraded. Skip event publishing.")


if __name__ == "__main__":
    main()
