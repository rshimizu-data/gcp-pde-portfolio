output "service_url" {
 value = google_cloud_run_v2_service.predict_api.uri
}

output "service_account_email" {
 value = google_service_account.predict_api_sa.email
}

output "artifact_registry_repo" {
 value = google_artifact_registry_repository.predict_api.repository_id
}
