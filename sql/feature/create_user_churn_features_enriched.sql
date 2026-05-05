CREATE OR REPLACE TABLE `churn-analysis-491912.feature.user_churn_features_enriched`
AS

WITH latest_prediction_features AS (
  SELECT
    *
  FROM
    `churn-analysis-491912.feature.prediction_user_features_daily`
  QUALIFY
    ROW_NUMBER() OVER (
      PARTITION BY user_id
      ORDER BY feature_date DESC
    ) = 1
)

SELECT
  base.*,

  IFNULL(pred.prediction_count_7d, 0) AS prediction_count_7d,
  IFNULL(pred.avg_probability_30d, 0.0) AS avg_prediction_probability_30d,
  pred.latest_prediction_time,
  IFNULL(pred.latest_probability, 0.0) AS latest_prediction_probability,
  IFNULL(pred.total_prediction_count, 0) AS total_prediction_count,

  CURRENT_TIMESTAMP() AS feature_created_at

FROM
  `churn-analysis-491912.feature.user_churn_features` base
LEFT JOIN
  latest_prediction_features pred
ON
  base.user_id = pred.user_id;
