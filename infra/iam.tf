resource "google_service_account" "predict_api_sa" {
  account_id   = var.service_account_id
  display_name = "Service Account for predict-api"
}

resource "google_project_iam_member" "predict_api_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${var.service_account_email}"
}

resource "google_project_iam_member" "predict_api_bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${var.service_account_email}"
}

resource "google_project_iam_member" "predict_api_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${var.service_account_email}"
}
