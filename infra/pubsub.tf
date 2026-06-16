resource "google_pubsub_topic" "retraining_requested" {
  name = "mlops-retraining-requested"
}

resource "google_pubsub_topic" "mlops_alerts" {
  name = "mlops-alerts"

  labels = {
    system     = "mlops"
    purpose    = "alert"
    managed_by = "terraform"
  }
}

resource "google_pubsub_subscription" "alert_notifier_sub" {

  name  = "alert-notifier-sub"
  topic = google_pubsub_topic.mlops_alerts.name

  push_config {
    push_endpoint = google_cloud_run_v2_service.alert_notifier.uri
  }

  ack_deadline_seconds = 10
}

resource "google_pubsub_topic" "user_events" {
  name = "user-events-topic"

  labels = {
    system     = "streaming"
    purpose    = "user-events"
    managed_by = "terraform"
  }
}

resource "google_pubsub_subscription" "user_events_sub" {

  name  = "user-events-sub"
  topic = google_pubsub_topic.user_events.name

  ack_deadline_seconds = 10
}
