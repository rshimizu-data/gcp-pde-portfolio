CREATE OR REPLACE VIEW `churn-analysis-491912.ml_logs.v_prediction_user_latest` AS
SELECT
  user_id,
  request_id,
  request_time,
  model_version,
  variant,
  experiment_id,
  prediction,
  prediction_probability,
  model_uri
FROM `churn-analysis-491912.ml_logs.prediction_logs`
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY user_id
  ORDER BY request_time DESC
) = 1;
