CREATE OR REPLACE VIEW `churn-analysis-491912.ml_logs.v_prediction_daily_summary` AS
SELECT
  DATE(request_time) AS log_date,
  COUNT(*) AS prediction_count,
  AVG(prediction_probability) AS avg_probability,
  MIN(prediction_probability) AS min_probability,
  MAX(prediction_probability) AS max_probability,
  COUNTIF(prediction = 1) AS predicted_churn_count,
  COUNTIF(prediction = 0) AS predicted_non_churn_count,
  SAFE_DIVIDE(COUNTIF(prediction = 1), COUNT(*)) AS predicted_churn_rate
FROM `churn-analysis-491912.ml_logs.prediction_logs`
GROUP BY log_date;
