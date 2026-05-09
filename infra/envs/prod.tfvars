project_id = "churn-analysis-491912"
region     = "asia-northeast1"

service_name          = "predict-api"
service_account_id    = "predict-api-sa"
service_account_email = "predict-api-sa@churn-analysis-491912.iam.gserviceaccount.com"

repo_name = "predict-api-repo"

image_uri = "asia-northeast1-docker.pkg.dev/churn-analysis-491912/predict-api-repo/predict-api:9b38768074e2876aa8b93692b76de3afc0749cbd"

model_uri = "gs://churn-model-bucket-ryo/models/model.pkl"

trainer_image_uri = "asia-northeast1-docker.pkg.dev/churn-analysis-491912/predict-api-repo/churn-trainer:v1"

model_bucket = "churn-model-bucket-ryo"

job_launcher_service_name = "job-launcher"

slack_webhook_url = ""