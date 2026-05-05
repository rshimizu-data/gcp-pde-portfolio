CREATE OR REPLACE VIEW `churn-analysis-491912.ml_logs.v_prediction_features` AS

SELECT
  request_time,
  model_version,
  variant,
  experiment_id,
  model_uri,
  prediction_probability,
  SAFE_CAST(JSON_VALUE(input_features_json, '$.login_count_7d') AS FLOAT64) AS login_count_7d,
  SAFE_CAST(JSON_VALUE(input_features_json, '$.active_days_30d') AS FLOAT64) AS active_days_30d,
  SAFE_CAST(JSON_VALUE(input_features_json, '$.days_since_last_login') AS FLOAT64) AS days_since_last_login,
  SAFE_CAST(JSON_VALUE(input_features_json, '$.avg_session_time_30d') AS FLOAT64) AS avg_session_time_30d
FROM `churn-analysis-491912.ml_logs.prediction_logs`;
