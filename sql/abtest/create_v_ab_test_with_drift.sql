CREATE OR REPLACE VIEW `churn-analysis-491912.ml_logs.v_ab_test_with_drift` AS

SELECT
  a.experiment_id,
  a.model_version,
  a.variant,
  AVG(a.prediction_probability) AS avg_probability,
  MAX(CASE WHEN d.is_drift THEN 1 ELSE 0 END) AS has_drift
FROM `churn-analysis-491912.ml_logs.prediction_logs` a
LEFT JOIN `churn-analysis-491912.ml_logs.drift_results` d
  ON a.model_version = d.model_version
WHERE a.experiment_id IS NOT NULL
GROUP BY a.experiment_id, a.model_version, a.variant;
