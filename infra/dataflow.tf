# ========================================
# Dataflow
# ========================================

resource "google_dataflow_job" "user_events_streaming" {
  name              = "user-events-streaming-job"
  region            = "asia-northeast2"
  zone              = "asia-northeast2-a"
  template_gcs_path = "gs://dataflow-templates/latest/PubSub_Subscription_to_BigQuery"
  temp_gcs_location = "gs://churn-model-bucket-ryo/temp"

  parameters = {
    inputSubscription = "projects/churn-analysis-491912/subscriptions/user-events-sub"
    outputTableSpec   = "churn-analysis-491912:raw_stream.user_events"
  }

  on_delete = "cancel"
}