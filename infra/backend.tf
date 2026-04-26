terraform {
  backend "gcs" {
    bucket = "terraform-state-churn-analysis-ryo"
    prefix = "predict-api/prod"
  }
}
