resource "google_cloud_run_v2_service" "predict_api" {
  name     = var.service_name
  location = var.region

  ingress = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = var.service_account_email
    timeout         = "300s"

    containers {
      image = var.image_uri

      ports {
        container_port = 8080
      }

      env {
        name  = "MODEL_URI"
        value = var.model_uri
      }

      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }

      env {
        name  = "PROJECT_ID"
        value = var.project_id
      }

      env {
        name  = "BQ_LOG_TABLE"
        value = "churn-analysis-491912.ml_logs.prediction_logs"
      }

      env {
        name  = "MODEL_VERSION"
        value = "v1"
      }

      env {
        name  = "EXPERIMENT_ID"
        value = "default"
      }

      env {
        name  = "MODEL_VARIANT"
        value = "default"
      }

      env {
        name  = "PREDICTION_THRESHOLD"
        value = "0.5"
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
      }
    }

    max_instance_request_concurrency = 80
  }

  lifecycle {
    ignore_changes = [
      client,
      client_version,
      template[0].containers[0].image,
      template[0].containers[0].resources[0].cpu_idle,
      template[0].containers[0].resources[0].startup_cpu_boost
    ]
  }
}

resource "google_cloud_run_service_iam_member" "public_invoker" {
  location = var.region
  service  = var.service_name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ==========================================
# Cloud Run Jobs
# ==========================================

resource "google_cloud_run_v2_job" "retraining_job" {
  name     = "retraining-job"
  location = var.region

  template {
    template {
      service_account = google_service_account.retraining_job_sa.email
      timeout         = "900s"
      max_retries     = 0

      containers {
        image = var.trainer_image_uri

        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "BQ_LOCATION"
          value = var.region
        }

        env {
          name  = "MODEL_BUCKET"
          value = var.model_bucket
        }
      }
    }
  }
}

resource "google_cloud_run_v2_service" "alert_notifier" {

  name     = "alert-notifier"
  location = var.region

  template {

    containers {

      image = "asia-northeast1-docker.pkg.dev/churn-analysis-491912/predict-api-repo/alert-notifier:v2"

      env {
        name  = "SLACK_WEBHOOK_URL"
        value = var.slack_webhook_url
      }
    }
  }

  ingress = "INGRESS_TRAFFIC_ALL"
}
