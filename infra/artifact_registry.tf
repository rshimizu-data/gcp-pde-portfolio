resource "google_artifact_registry_repository" "predict_api" {
 location = var.region
 repository_id = var.repo_name
 format = "DOCKER"
 description = "predict api repository"
}
