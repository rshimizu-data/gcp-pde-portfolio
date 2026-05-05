CREATE OR REPLACE VIEW `churn-analysis-491912.ml_logs.v_recent_feature_stats` AS

SELECT
  model_version,
  variant,
  experiment_id,
  COUNT(*) AS record_count,
  AVG(login_count_7d) AS avg_login_count_7d,
  AVG(active_days_30d) AS avg_active_days_30d,
  AVG(days_since_last_login) AS avg_days_since_last_login,
  AVG(avg_session_time_30d) AS avg_session_time_30d,
  MIN(request_time) AS window_start,
  MAX(request_time) AS window_end
FROM `churn-analysis-491912.ml_logs.v_prediction_features`
WHERE request_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY
  model_version,
  variant,
  experiment_id;
