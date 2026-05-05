CREATE OR REPLACE TABLE `churn-analysis-491912.ml_logs.baseline_feature_stats` AS

SELECT
  feature_name,
  baseline_mean,
  baseline_std,
  baseline_min,
  baseline_max,
  CURRENT_TIMESTAMP() AS created_at,
  'v1' AS model_version
FROM (
  SELECT
    AVG(login_count_7d) AS login_count_7d_mean,
    STDDEV(login_count_7d) AS login_count_7d_std,
    MIN(login_count_7d) AS login_count_7d_min,
    MAX(login_count_7d) AS login_count_7d_max,
  
    AVG(active_days_30d) AS active_days_30d_mean,
    STDDEV(active_days_30d) AS active_days_30d_std,
    MIN(active_days_30d) AS active_days_30d_min,
    MAX(active_days_30d) AS active_days_30d_max,
  
    AVG(days_since_last_login) AS days_since_last_login_mean,
    STDDEV(days_since_last_login) AS days_since_last_login_std,
    MIN(days_since_last_login) AS days_since_last_login_min,
    MAX(days_since_last_login) AS days_since_last_login_max,
  
    AVG(avg_session_time_30d) AS avg_session_time_30d_mean,
    STDDEV(avg_session_time_30d) AS avg_session_time_30d_std,
    MIN(avg_session_time_30d) AS avg_session_time_30d_min,
    MAX(avg_session_time_30d) AS avg_session_time_30d_max
  FROM `churn-analysis-491912.feature.user_churn_features`
),
UNNEST([
  STRUCT('login_count_7d' AS feature_name, login_count_7d_mean AS baseline_mean, login_count_7d_std AS baseline_std, login_count_7d_min AS baseline_min, login_count_7d_max AS baseline_max),
  STRUCT('active_days_30d' AS feature_name, active_days_30d_mean AS baseline_mean, active_days_30d_std AS baseline_std, active_days_30d_min AS baseline_min, active_days_30d_max AS baseline_max),
  STRUCT('days_since_last_login' AS feature_name, days_since_last_login_mean AS baseline_mean, days_since_last_login_std AS baseline_std, days_since_last_login_min AS baseline_min, days_since_last_login_max AS baseline_max),
  STRUCT('avg_session_time_30d' AS feature_name, avg_session_time_30d_mean AS baseline_mean, avg_session_time_30d_std AS baseline_std, avg_session_time_30d_min AS baseline_min, avg_session_time_30d_max AS baseline_max)
]);
