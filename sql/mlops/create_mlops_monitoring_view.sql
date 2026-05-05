CREATE OR REPLACE VIEW `churn-analysis-491912.mlops.mlops_monitoring_view`
AS

WITH drift AS (
  SELECT *
  FROM `churn-analysis-491912.mlops.drift_detection_results`
  ORDER BY checked_at DESC
  LIMIT 1
),

decision AS (
  SELECT *
  FROM `churn-analysis-491912.mlops.retraining_decision`
  ORDER BY checked_at DESC
  LIMIT 1
),

ab AS (
  SELECT
    experiment_id,
    model_version,
    variant,
    prediction_count,
    user_count,
    avg_probability,
    churn_rate
  FROM `churn-analysis-491912.mlops.ab_test_analysis`
)

SELECT
  d.checked_at,

  d.drift_flag,
  d.drift_reason,
  d.avg_probability_diff,
  d.latest_probability_diff,
  d.prediction_count_7d_diff_rate,

  dec.model_probability_diff,
  dec.variant_probability_diff,
  dec.retraining_required,
  dec.retraining_reason,
  dec.action,

  ab.experiment_id,
  ab.model_version,
  ab.variant,
  ab.prediction_count,
  ab.user_count,
  ab.avg_probability,
  ab.churn_rate

FROM drift d
CROSS JOIN decision dec
LEFT JOIN ab
ON 1=1;
