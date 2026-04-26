CREATE OR REPLACE TABLE `churn-analysis-491912.raw.activity_log` AS
WITH user_segment_base AS (
  SELECT
    u.user_id,
    u.signup_date,
    CASE
      WHEN seg_r < 0.20 THEN 'heavy'
      WHEN seg_r < 0.45 THEN 'normal'
      WHEN seg_r < 0.70 THEN 'light'
      WHEN seg_r < 0.85 THEN 'declining'
      ELSE 'churned'
    END AS user_segment
  FROM (
    SELECT
      user_id,
      signup_date,
      ABS(MOD(FARM_FINGERPRINT(user_id), 10000)) / 10000.0 AS seg_r
    FROM `churn-analysis-491912.raw.users`
  ) u
),

date_series AS (
  SELECT dt
  FROM UNNEST(GENERATE_DATE_ARRAY(DATE '2025-01-01', DATE '2025-03-31')) AS dt
),

base AS (
  SELECT
    u.user_id,
    d.dt AS activity_date,
    u.signup_date,
    u.user_segment,

    CASE
      WHEN d.dt < u.signup_date THEN 0.0

      WHEN u.user_segment = 'heavy' THEN 0.80
      WHEN u.user_segment = 'normal' THEN 0.45
      WHEN u.user_segment = 'light' THEN 0.20

      WHEN u.user_segment = 'declining' THEN
        GREATEST(
          0.70 - DATE_DIFF(d.dt, u.signup_date, DAY) * 0.01,
          0.05
        )

      WHEN u.user_segment = 'churned' THEN
        CASE
          WHEN DATE_DIFF(d.dt, u.signup_date, DAY) <= 20 THEN 0.50
          ELSE 0.02
        END

      ELSE 0.0
    END AS login_prob,

    ABS(MOD(FARM_FINGERPRINT(CONCAT(u.user_id, CAST(d.dt AS STRING))), 10000)) / 10000.0 AS activity_r,
    ABS(MOD(FARM_FINGERPRINT(CONCAT('sess_', u.user_id, CAST(d.dt AS STRING))), 10000)) / 10000.0 AS session_r
  FROM user_segment_base u
  CROSS JOIN date_series d
)

SELECT
  user_id,
  activity_date,
  ROUND(5 + session_r * 60, 1) AS session_time_minutes
FROM base
WHERE activity_r < login_prob;