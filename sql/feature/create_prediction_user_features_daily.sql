CREATE OR REPLACE TABLE `churn-analysis-491912.feature.prediction_user_features_daily`
AS

WITH base AS (
  SELECT
    user_id,
    DATE(request_time) AS feature_date,
    request_time,
    model_version,
    variant,
    prediction_probability
  FROM
    `churn-analysis-491912.ml_logs.prediction_logs`
  WHERE
    user_id IS NOT NULL
    AND prediction_probability IS NOT NULL
),

features AS (
  SELECT
    user_id,
    feature_date,

    COUNTIF(
      request_time >= TIMESTAMP_SUB(TIMESTAMP(feature_date), INTERVAL 7 DAY)
    ) AS prediction_count_7d,

    AVG(
      IF(
        request_time >= TIMESTAMP_SUB(TIMESTAMP(feature_date), INTERVAL 30 DAY),
        prediction_probability,
        NULL
      )
    ) AS avg_probability_30d,

    MAX(request_time) AS latest_prediction_time,

    ARRAY_AGG(
      prediction_probability
      ORDER BY request_time DESC
      LIMIT 1
    )[OFFSET(0)] AS latest_probability,

    COUNT(*) AS total_prediction_count

  FROM base
  GROUP BY user_id, feature_date
)

SELECT
  *,
  CURRENT_TIMESTAMP() AS created_at
FROM features;