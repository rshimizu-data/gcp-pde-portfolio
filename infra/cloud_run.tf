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
      scaling,
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