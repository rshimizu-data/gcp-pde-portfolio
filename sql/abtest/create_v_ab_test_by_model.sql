CREATE OR REPLACE VIEW `churn-analysis-491912.ml_logs.v_ab_test_by_model` AS

SELECT
  experiment_id,
  model_version,
  COUNT(*) AS prediction_count,
  AVG(prediction_probability) AS avg_prediction_probability,
  SUM(CASE WHEN prediction_probability >= 0.5 THEN 1 ELSE 0 END) AS predicted_churn_count,
  SAFE_DIVIDE(
    SUM(CASE WHEN prediction_probability >= 0.5 THEN 1 ELSE 0 END),
    COUNT(*)
  ) AS predicted_churn_rate
FROM `churn-analysis-491912.ml_logs.prediction_logs`
WHERE experiment_id IS NOT NULL
GROUP BY experiment_id, model_version;
