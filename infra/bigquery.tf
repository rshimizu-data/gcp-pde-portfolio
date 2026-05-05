resource "google_bigquery_dataset" "ml_logs" {
  dataset_id = "ml_logs"
  location   = "asia-northeast1"
}

resource "google_bigquery_table" "prediction_logs" {
  dataset_id = google_bigquery_dataset.ml_logs.dataset_id
  table_id   = "prediction_logs"

  time_partitioning {
    type  = "DAY"
    field = "request_time"
  }

  clustering = [
    "model_version",
    "variant",
    "user_id",
  ]

  schema = jsonencode([
    {
      name = "request_id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "request_time"
      type = "TIMESTAMP"
      mode = "REQUIRED"
    },
    {
      name = "user_id"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "model_version"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "model_uri"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "experiment_id"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "variant"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "input_features_json"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "prediction"
      type = "INTEGER"
      mode = "NULLABLE"
    },
    {
      name = "prediction_probability"
      type = "FLOAT"
      mode = "NULLABLE"
    },
    {
      name = "threshold"
      type = "FLOAT"
      mode = "NULLABLE"
    },
    {
      name = "metadata_json"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "created_at"
      type = "TIMESTAMP"
      mode = "NULLABLE"
    }
  ])
}

