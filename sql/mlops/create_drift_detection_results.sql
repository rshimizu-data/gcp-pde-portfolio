CREATE OR REPLACE TABLE `churn-analysis-491912.mlops.drift_detection_results`
AS

WITH base AS (
  SELECT
    user_id,
    feature_date,
    prediction_count_7d,
    avg_probability_30d AS avg_prediction_probability_30d,
    latest_probability AS latest_prediction_probability,
    latest_prediction_time,
    total_prediction_count
  FROM
    `churn-analysis-491912.feature.prediction_user_features_daily`
  WHERE
    feature_date IS NOT NULL
),

baseline AS (
  SELECT
    'baseline' AS period_type,
    COUNT(*) AS row_count,
    COUNT(DISTINCT user_id) AS user_count,
    AVG(avg_prediction_probability_30d) AS avg_probability,
    STDDEV(avg_prediction_probability_30d) AS std_probability,
    AVG(latest_prediction_probability) AS avg_latest_probability,
    AVG(prediction_count_7d) AS avg_prediction_count_7d
  FROM base
  WHERE feature_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
                         AND DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY)
),

recent AS (
  SELECT
    'recent' AS period_type,
    COUNT(*) AS row_count,
    COUNT(DISTINCT user_id) AS user_count,
    AVG(avg_prediction_probability_30d) AS avg_probability,
    STDDEV(avg_prediction_probability_30d) AS std_probability,
    AVG(latest_prediction_probability) AS avg_latest_probability,
    AVG(prediction_count_7d) AS avg_prediction_count_7d
  FROM base
  WHERE feature_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
                         AND CURRENT_DATE()
),

comparison AS (
  SELECT
    CURRENT_TIMESTAMP() AS checked_at,

    b.row_count AS baseline_row_count,
    r.row_count AS recent_row_count,

    b.user_count AS baseline_user_count,
    r.user_count AS recent_user_count,

    b.avg_probability AS baseline_avg_probability,
    r.avg_probability AS recent_avg_probability,

    b.avg_latest_probability AS baseline_avg_latest_probability,
    r.avg_latest_probability AS recent_avg_latest_probability,

    b.avg_prediction_count_7d AS baseline_avg_prediction_count_7d,
    r.avg_prediction_count_7d AS recent_avg_prediction_count_7d,

    ABS(r.avg_probability - b.avg_probability) AS avg_probability_diff,
    ABS(r.avg_latest_probability - b.avg_latest_probability) AS latest_probability_diff,
    ABS(r.avg_prediction_count_7d - b.avg_prediction_count_7d) AS prediction_count_7d_diff,

    SAFE_DIVIDE(
      ABS(r.avg_prediction_count_7d - b.avg_prediction_count_7d),
      NULLIF(b.avg_prediction_count_7d, 0)
    ) AS prediction_count_7d_diff_rate

  FROM baseline b
  CROSS JOIN recent r
)

SELECT
  *,
  CASE
    WHEN baseline_row_count = 0 THEN true
    WHEN recent_row_count = 0 THEN true
    WHEN avg_probability_diff >= 0.10 THEN true
    WHEN latest_probability_diff >= 0.10 THEN true
    WHEN prediction_count_7d_diff_rate >= 0.50 THEN true
    ELSE false
  END AS drift_flag,

  CASE
    WHEN baseline_row_count = 0 THEN 'NO_BASELINE_DATA'
    WHEN recent_row_count = 0 THEN 'NO_RECENT_DATA'
    WHEN avg_probability_diff >= 0.10 THEN 'AVG_PROBABILITY_DRIFT'
    WHEN latest_probability_diff >= 0.10 THEN 'LATEST_PROBABILITY_DRIFT'
    WHEN prediction_count_7d_diff_rate >= 0.50 THEN 'PREDICTION_COUNT_DRIFT'
    ELSE 'NO_DRIFT'
  END AS drift_reason

FROM comparison;
