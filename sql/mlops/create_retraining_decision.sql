CREATE OR REPLACE TABLE `churn-analysis-491912.mlops.retraining_decision`
AS

WITH drift AS (
  SELECT
    checked_at,
    drift_flag,
    drift_reason,
    avg_probability_diff,
    latest_probability_diff,
    prediction_count_7d_diff_rate
  FROM
    `churn-analysis-491912.mlops.drift_detection_results`
  ORDER BY checked_at DESC
  LIMIT 1
),

ab_base AS (
  SELECT
    experiment_id,
    model_version,
    variant,
    prediction_count,
    user_count,
    avg_probability,
    churn_rate
  FROM
    `churn-analysis-491912.mlops.ab_test_analysis`
  WHERE
    experiment_id = 'ab_test_001'
),

model_compare AS (
  SELECT
    MAX(CASE WHEN model_version = 'v1' THEN avg_probability END) AS v1_avg_probability,
    MAX(CASE WHEN model_version = 'v2' THEN avg_probability END) AS v2_avg_probability,
    ABS(
      MAX(CASE WHEN model_version = 'v2' THEN avg_probability END)
      -
      MAX(CASE WHEN model_version = 'v1' THEN avg_probability END)
    ) AS model_probability_diff
  FROM ab_base
),

variant_compare AS (
  SELECT
    MAX(CASE WHEN variant = 'control' THEN avg_probability END) AS control_avg_probability,
    MAX(CASE WHEN variant = 'treatment' THEN avg_probability END) AS treatment_avg_probability,
    ABS(
      MAX(CASE WHEN variant = 'treatment' THEN avg_probability END)
      -
      MAX(CASE WHEN variant = 'control' THEN avg_probability END)
    ) AS variant_probability_diff
  FROM ab_base
),

decision AS (
  SELECT
    d.checked_at,
    d.drift_flag,
    d.drift_reason,

    d.avg_probability_diff,
    d.latest_probability_diff,
    d.prediction_count_7d_diff_rate,

    m.v1_avg_probability,
    m.v2_avg_probability,
    m.model_probability_diff,

    v.control_avg_probability,
    v.treatment_avg_probability,
    v.variant_probability_diff,

    CASE
      WHEN d.drift_flag = false THEN false
      WHEN d.drift_reason = 'PREDICTION_COUNT_DRIFT' THEN false
      WHEN v.variant_probability_diff >= 0.10 THEN false
      WHEN m.model_probability_diff >= 0.10 THEN true
      WHEN d.avg_probability_diff >= 0.10 THEN true
      WHEN d.latest_probability_diff >= 0.10 THEN true
      ELSE false
    END AS retraining_required,

    CASE
      WHEN d.drift_flag = false THEN 'NO_DRIFT'
      WHEN d.drift_reason = 'PREDICTION_COUNT_DRIFT' THEN 'LOG_VOLUME_CHANGE_NO_RETRAINING'
      WHEN v.variant_probability_diff >= 0.10 THEN 'VARIANT_EFFECT_NO_RETRAINING'
      WHEN m.model_probability_diff >= 0.10 THEN 'MODEL_DIFF_RETRAINING_CANDIDATE'
      WHEN d.avg_probability_diff >= 0.10 THEN 'AVG_PROBABILITY_DRIFT_RETRAINING_CANDIDATE'
      WHEN d.latest_probability_diff >= 0.10 THEN 'LATEST_PROBABILITY_DRIFT_RETRAINING_CANDIDATE'
      ELSE 'NO_RETRAINING_REQUIRED'
    END AS retraining_reason,

    CASE
      WHEN d.drift_flag = false THEN 'MONITOR_ONLY'
      WHEN d.drift_reason = 'PREDICTION_COUNT_DRIFT' THEN 'IGNORE_LOG_DRIFT'
      WHEN v.variant_probability_diff >= 0.10 THEN 'MONITOR_AB_RESULT'
      WHEN m.model_probability_diff >= 0.10 THEN 'RUN_RETRAINING_JOB'
      WHEN d.avg_probability_diff >= 0.10 THEN 'RUN_RETRAINING_JOB'
      WHEN d.latest_probability_diff >= 0.10 THEN 'RUN_RETRAINING_JOB'
      ELSE 'MONITOR_ONLY'
    END AS action

  FROM drift d
  CROSS JOIN model_compare m
  CROSS JOIN variant_compare v
)

SELECT * FROM decision;
