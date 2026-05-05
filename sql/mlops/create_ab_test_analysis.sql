CREATE OR REPLACE TABLE `churn-analysis-491912.mlops.ab_test_analysis`
AS

SELECT
  experiment_id,
  model_version,
  variant,

  COUNT(*) AS prediction_count,
  COUNT(DISTINCT user_id) AS user_count,

  AVG(prediction_probability) AS avg_probability,
  AVG(CASE WHEN prediction = 1 THEN 1 ELSE 0 END) AS churn_rate

FROM
  `churn-analysis-491912.ml_logs.prediction_logs`

GROUP BY
  experiment_id,
  model_version,
  variant;
