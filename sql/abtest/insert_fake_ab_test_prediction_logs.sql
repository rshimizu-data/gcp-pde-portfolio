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

-- control（現行モデル v1）
SELECT
  GENERATE_UUID(),
  TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL x MINUTE),
  'v1',
  'control',
  'ab_test_001',
  'gs://churn-model-bucket-ryo/models/model_v1.pkl',
  0.45 + RAND() * 0.10,
  TO_JSON_STRING(STRUCT(3.0, 9.0, 5.0, 30.0))
FROM UNNEST(GENERATE_ARRAY(1,50)) AS x

UNION ALL

-- treatment（新モデル v2）
SELECT
  GENERATE_UUID(),
  TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL x MINUTE),
  'v2',
  'treatment',
  'ab_test_001',
  'gs://churn-model-bucket-ryo/models/model_v2.pkl',
  0.58 + RAND() * 0.10,
  TO_JSON_STRING(STRUCT(3.0, 9.0, 5.0, 30.0))
FROM UNNEST(GENERATE_ARRAY(1,50)) AS x;
