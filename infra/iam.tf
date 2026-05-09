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

# ==========================================
# Service Account
# ==========================================

resource "google_service_account" "retraining_job_sa" {
  account_id   = "retraining-job-sa"
  display_name = "Service Account for retraining-job"
}

# ==========================================
# IAM
# ==========================================

resource "google_project_iam_member" "retraining_job_bigquery_data_viewer" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.retraining_job_sa.email}"
}

resource "google_project_iam_member" "retraining_job_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.retraining_job_sa.email}"
}

resource "google_project_iam_member" "retraining_job_storage_object_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.retraining_job_sa.email}"
}

resource "google_project_iam_member" "retraining_job_aiplatform_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.retraining_job_sa.email}"
}

resource "google_project_iam_member" "retraining_job_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.retraining_job_sa.email}"
}

resource "google_service_account_iam_member" "retraining_job_sa_user" {
  service_account_id = google_service_account.retraining_job_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.retraining_job_sa.email}"
}