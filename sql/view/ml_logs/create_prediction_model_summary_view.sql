CREATE OR REPLACE VIEW `churn-analysis-491912.ml_logs.v_prediction_model_summary` AS
SELECT
  model_version,
  variant,
  experiment_id,
  COUNT(*) AS prediction_count,
  AVG(prediction_probability) AS avg_probability,
  COUNTIF(prediction = 1) AS predicted_churn_count,
  SAFE_DIVIDE(COUNTIF(prediction = 1), COUNT(*)) AS predicted_churn_rate,
  MIN(request_time) AS first_request_time,
  MAX(request_time) AS last_request_time
FROM `churn-analysis-491912.ml_logs.prediction_logs`
GROUP BY
  model_version,
  variant,
  experiment_id;
