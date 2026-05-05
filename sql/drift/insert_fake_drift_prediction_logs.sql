INSERT INTO `churn-analysis-491912.ml_logs.prediction_logs`
(
  request_id,
  request_time,
  model_version,
  variant,
  experiment_id,
  model_uri,
  prediction_probability,
  input_features_json
)

SELECT
  GENERATE_UUID() AS request_id,
  CURRENT_TIMESTAMP() AS request_time,
  'v1' AS model_version,
  'control' AS variant,
  'drift_demo_001' AS experiment_id,
  'gs://churn-model-bucket-ryo/models/model.pkl' AS model_uri,
  0.8 AS prediction_probability,

  TO_JSON_STRING(STRUCT(
    CAST(1 AS FLOAT64) AS login_count_7d,
    CAST(2 AS FLOAT64) AS active_days_30d,
    CAST(30 AS FLOAT64) AS days_since_last_login,
    CAST(8 AS FLOAT64) AS avg_session_time_30d
  )) AS input_features_json

FROM UNNEST(GENERATE_ARRAY(1, 20));