CREATE OR REPLACE VIEW `churn-analysis-491912.ml_logs.v_ab_test_comparison` AS

WITH base AS (
  SELECT
    experiment_id,
    variant,
    COUNT(*) AS cnt,
    AVG(prediction_probability) AS avg_prob
  FROM `churn-analysis-491912.ml_logs.prediction_logs`
  WHERE experiment_id IS NOT NULL
  GROUP BY experiment_id, variant
)

SELECT
  experiment_id,
  MAX(CASE WHEN variant='control' THEN avg_prob END) AS control_avg,
  MAX(CASE WHEN variant='treatment' THEN avg_prob END) AS treatment_avg,
  MAX(CASE WHEN variant='treatment' THEN avg_prob END)
    - MAX(CASE WHEN variant='control' THEN avg_prob END) AS diff
FROM base
GROUP BY experiment_id;
