CREATE OR REPLACE VIEW `churn-analysis-491912.ml_logs.v_retraining_dataset` AS

SELECT
  p.user_id,
  p.request_id,
  p.request_time,
  p.model_version,
  p.variant,
  p.experiment_id,
  p.model_uri,
  p.prediction,
  p.prediction_probability,
  p.threshold,

  f.login_count_7d,
  f.active_days_30d,
  f.days_since_last_login,
  f.avg_session_time_30d,

  CAST(NULL AS INT64) AS actual_churn_label,

  p.input_features_json,
  p.metadata_json,
  p.created_at
FROM
  `churn-analysis-491912.ml_logs.prediction_logs` p
LEFT JOIN
  `churn-analysis-491912.feature.user_churn_features` f
ON
  p.user_id = f.user_id;
