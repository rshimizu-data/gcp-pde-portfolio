SELECT
  model_version,
  experiment_id,

  COUNT(*) AS prediction_count,

  AVG(prediction_probability) AS avg_probability,

  -- モデルの強さ（離脱予測の割合）
  AVG(CASE WHEN churn_prediction = 1 THEN 1 ELSE 0 END) AS predicted_churn_rate,

  -- モデルのバラつき（安定性）
  STDDEV(prediction_probability) AS probability_stddev,

  MAX(request_time) AS last_prediction_time

FROM
  `churn-analysis-491912.ml_logs.prediction_logs`

GROUP BY
  model_version,
  experiment_id

ORDER BY
  model_version;
