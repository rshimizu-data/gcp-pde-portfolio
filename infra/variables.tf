variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "service_name" {
  type = string
}

variable "repo_name" {
  type = string
}

variable "service_account_id" {
  type = string
}

variable "service_account_email" {
  type = string
}

variable "image_uri" {
  type = string
}

variable "model_uri" {
  type = string
}

variable "trainer_image_uri" {
  description = "Trainer image URI"
  type        = string
}

variable "model_bucket" {
  description = "Model bucket name"
  type        = string
}

variable "job_launcher_service_name" {
  description = "Cloud Run service name for job launcher"
  type        = string
}

variable "slack_webhook_url" {
  type      = string
  sensitive = true
}