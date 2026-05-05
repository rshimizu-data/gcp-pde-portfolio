CREATE OR REPLACE TABLE `churn-analysis-491912.ml_logs.drift_results` (
  check_time TIMESTAMP,
  feature_name STRING,
  baseline_mean FLOAT64,
  recent_mean FLOAT64,
  drift_score FLOAT64,
  threshold FLOAT64,
  is_drift BOOL,
  model_version STRING,
  variant STRING,
  experiment_id STRING,
  drift_method STRING,
  checked_window_start TIMESTAMP,
  checked_window_end TIMESTAMP,
  created_at TIMESTAMP
);