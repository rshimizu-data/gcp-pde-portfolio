CREATE OR REPLACE VIEW `churn-analysis-491912.ml_logs.v_ab_test_summary` AS

SELECT
  experiment_id,
  variant,
  model_version,
  COUNT(*) AS prediction_count,
  AVG(prediction_probability) AS avg_prediction_probability,
  MIN(prediction_probability) AS min_prediction_probability,
  MAX(prediction_probability) AS max_prediction_probability
FROM `churn-analysis-491912.ml_logs.prediction_logs`
WHERE experiment_id IS NOT NULL
GROUP BY experiment_id, variant, model_version;
