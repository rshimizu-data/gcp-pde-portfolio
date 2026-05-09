# ==========================================
# Eventarc Trigger
# ==========================================

resource "google_eventarc_trigger" "retraining_trigger" {
  name     = "retraining-trigger"
  location = var.region

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.pubsub.topic.v1.messagePublished"
  }

  transport {
    pubsub {
      topic = google_pubsub_topic.retraining_requested.id
    }
  }

  destination {
    cloud_run_service {
      service = var.job_launcher_service_name
      region  = var.region
      path    = "/"
    }
  }

  service_account = google_service_account.retraining_job_sa.email
}