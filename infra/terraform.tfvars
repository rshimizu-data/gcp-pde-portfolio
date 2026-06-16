project_id = "churn-analysis-491912"
region     = "asia-northeast1"

service_name          = "predict-api"
repo_name             = "predict-api-repo"
service_account_id    = "predict-api-sa"
service_account_email = "predict-api-sa@churn-analysis-491912.iam.gserviceaccount.com"

image_uri = "asia-northeast1-docker.pkg.dev/churn-analysis-491912/predict-api-repo/predict-api:cfe477c20d934490beb951c0cd0360bfe3ed5e82"

model_uri    = "gs://churn-model-bucket-ryo/models/model.pkl"
model_bucket = "churn-model-bucket-ryo"

trainer_image_uri = "asia-northeast1-docker.pkg.dev/churn-analysis-491912/predict-api-repo/churn-trainer:v1"

job_launcher_service_name = "job-launcher"

slack_webhook_url = ""