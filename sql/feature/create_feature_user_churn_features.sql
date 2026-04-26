CREATE OR REPLACE TABLE `churn-analysis-491912.feature.user_churn_features` AS
WITH params AS (
  SELECT
    DATE '2025-02-15' AS base_date
),

users_base AS (
  SELECT
    u.user_id,
    u.signup_date,
    u.plan_type,
    u.age,
    u.gender,
    p.base_date
  FROM `churn-analysis-491912.raw.users` u
  CROSS JOIN params p
  WHERE u.signup_date <= p.base_date
),

activity_base AS (
  SELECT
    a.user_id,
    a.activity_date,
    a.session_time_minutes
  FROM `churn-analysis-491912.raw.activity_log` a
),

feature_agg AS (
  SELECT
    u.user_id,
    u.base_date,

    -- 直近7日
    COUNTIF(
      a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 6 DAY) AND u.base_date
    ) AS login_count_7d,

    COUNT(DISTINCT CASE
      WHEN a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 6 DAY) AND u.base_date
      THEN a.activity_date
    END) AS active_days_7d,

    SUM(CASE
      WHEN a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 6 DAY) AND u.base_date
      THEN a.session_time_minutes
      ELSE 0
    END) AS total_session_time_7d,

    AVG(CASE
      WHEN a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 6 DAY) AND u.base_date
      THEN a.session_time_minutes
    END) AS avg_session_time_7d,

    -- 直近14日
    COUNTIF(
      a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 13 DAY) AND u.base_date
    ) AS login_count_14d,

    COUNT(DISTINCT CASE
      WHEN a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 13 DAY) AND u.base_date
      THEN a.activity_date
    END) AS active_days_14d,

    SUM(CASE
      WHEN a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 13 DAY) AND u.base_date
      THEN a.session_time_minutes
      ELSE 0
    END) AS total_session_time_14d,

    AVG(CASE
      WHEN a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 13 DAY) AND u.base_date
      THEN a.session_time_minutes
    END) AS avg_session_time_14d,

    -- 直近30日
    COUNTIF(
      a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 29 DAY) AND u.base_date
    ) AS login_count_30d,

    COUNT(DISTINCT CASE
      WHEN a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 29 DAY) AND u.base_date
      THEN a.activity_date
    END) AS active_days_30d,

    SUM(CASE
      WHEN a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 29 DAY) AND u.base_date
      THEN a.session_time_minutes
      ELSE 0
    END) AS total_session_time_30d,

    AVG(CASE
      WHEN a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 29 DAY) AND u.base_date
      THEN a.session_time_minutes
    END) AS avg_session_time_30d,

    -- 前7日（8〜14日前）
    COUNTIF(
      a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 13 DAY)
                          AND DATE_SUB(u.base_date, INTERVAL 7 DAY)
    ) AS login_count_prev_7d,

    COUNT(DISTINCT CASE
      WHEN a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 13 DAY)
                               AND DATE_SUB(u.base_date, INTERVAL 7 DAY)
      THEN a.activity_date
    END) AS active_days_prev_7d,

    SUM(CASE
      WHEN a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 13 DAY)
                               AND DATE_SUB(u.base_date, INTERVAL 7 DAY)
      THEN a.session_time_minutes
      ELSE 0
    END) AS total_session_time_prev_7d,

    AVG(CASE
      WHEN a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 13 DAY)
                               AND DATE_SUB(u.base_date, INTERVAL 7 DAY)
      THEN a.session_time_minutes
    END) AS avg_session_time_prev_7d,

    -- 前14日（15〜28日前）
    COUNTIF(
      a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 27 DAY)
                          AND DATE_SUB(u.base_date, INTERVAL 14 DAY)
    ) AS login_count_prev_14d,

    COUNT(DISTINCT CASE
      WHEN a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 27 DAY)
                               AND DATE_SUB(u.base_date, INTERVAL 14 DAY)
      THEN a.activity_date
    END) AS active_days_prev_14d,

    SUM(CASE
      WHEN a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 27 DAY)
                               AND DATE_SUB(u.base_date, INTERVAL 14 DAY)
      THEN a.session_time_minutes
      ELSE 0
    END) AS total_session_time_prev_14d,

    AVG(CASE
      WHEN a.activity_date BETWEEN DATE_SUB(u.base_date, INTERVAL 27 DAY)
                               AND DATE_SUB(u.base_date, INTERVAL 14 DAY)
      THEN a.session_time_minutes
    END) AS avg_session_time_prev_14d,

    -- 最終ログイン日
    MAX(CASE
      WHEN a.activity_date <= u.base_date THEN a.activity_date
    END) AS last_login_date

  FROM users_base u
  LEFT JOIN activity_base a
    ON u.user_id = a.user_id
   AND a.activity_date <= u.base_date
  GROUP BY
    u.user_id, u.base_date
),

label_agg AS (
  SELECT
    u.user_id,
    COUNTIF(
      a.activity_date BETWEEN DATE_ADD(u.base_date, INTERVAL 1 DAY)
                          AND DATE_ADD(u.base_date, INTERVAL 30 DAY)
    ) AS future_login_count_30d
  FROM users_base u
  LEFT JOIN activity_base a
    ON u.user_id = a.user_id
  GROUP BY
    u.user_id
)

SELECT
  u.user_id,
  u.signup_date,
  DATE_DIFF(u.base_date, u.signup_date, DAY) AS signup_days,
  u.plan_type,
  u.age,
  u.gender,
  u.base_date,

  -- 基本集計
  COALESCE(f.login_count_7d, 0) AS login_count_7d,
  COALESCE(f.active_days_7d, 0) AS active_days_7d,
  COALESCE(f.total_session_time_7d, 0) AS total_session_time_7d,
  COALESCE(f.avg_session_time_7d, 0) AS avg_session_time_7d,

  COALESCE(f.login_count_14d, 0) AS login_count_14d,
  COALESCE(f.active_days_14d, 0) AS active_days_14d,
  COALESCE(f.total_session_time_14d, 0) AS total_session_time_14d,
  COALESCE(f.avg_session_time_14d, 0) AS avg_session_time_14d,

  COALESCE(f.login_count_30d, 0) AS login_count_30d,
  COALESCE(f.active_days_30d, 0) AS active_days_30d,
  COALESCE(f.total_session_time_30d, 0) AS total_session_time_30d,
  COALESCE(f.avg_session_time_30d, 0) AS avg_session_time_30d,

  COALESCE(f.login_count_prev_7d, 0) AS login_count_prev_7d,
  COALESCE(f.active_days_prev_7d, 0) AS active_days_prev_7d,
  COALESCE(f.total_session_time_prev_7d, 0) AS total_session_time_prev_7d,
  COALESCE(f.avg_session_time_prev_7d, 0) AS avg_session_time_prev_7d,

  COALESCE(f.login_count_prev_14d, 0) AS login_count_prev_14d,
  COALESCE(f.active_days_prev_14d, 0) AS active_days_prev_14d,
  COALESCE(f.total_session_time_prev_14d, 0) AS total_session_time_prev_14d,
  COALESCE(f.avg_session_time_prev_14d, 0) AS avg_session_time_prev_14d,

  -- recency
  CASE
    WHEN f.last_login_date IS NULL THEN 60
    ELSE LEAST(DATE_DIFF(u.base_date, f.last_login_date, DAY), 60)
  END AS days_since_last_login,

  -- diff系
  COALESCE(f.login_count_7d, 0) - COALESCE(f.login_count_prev_7d, 0) AS login_count_diff_7d,
  COALESCE(f.active_days_7d, 0) - COALESCE(f.active_days_prev_7d, 0) AS active_days_diff_7d,
  COALESCE(f.total_session_time_7d, 0) - COALESCE(f.total_session_time_prev_7d, 0) AS total_session_time_diff_7d,

  COALESCE(f.login_count_14d, 0) - COALESCE(f.login_count_prev_14d, 0) AS login_count_diff_14d,
  COALESCE(f.active_days_14d, 0) - COALESCE(f.active_days_prev_14d, 0) AS active_days_diff_14d,
  COALESCE(f.total_session_time_14d, 0) - COALESCE(f.total_session_time_prev_14d, 0) AS total_session_time_diff_14d,

  -- ratio系
  SAFE_DIVIDE(
    COALESCE(f.login_count_7d, 0),
    NULLIF(COALESCE(f.login_count_prev_7d, 0), 0)
  ) AS login_count_ratio_7d,

  SAFE_DIVIDE(
    COALESCE(f.active_days_7d, 0),
    NULLIF(COALESCE(f.active_days_prev_7d, 0), 0)
  ) AS active_days_ratio_7d,

  SAFE_DIVIDE(
    COALESCE(f.total_session_time_7d, 0),
    NULLIF(COALESCE(f.total_session_time_prev_7d, 0), 0)
  ) AS total_session_time_ratio_7d,

  SAFE_DIVIDE(
    COALESCE(f.login_count_7d, 0),
    NULLIF(COALESCE(f.login_count_30d, 0), 0)
  ) AS login_ratio_7d_30d,

  SAFE_DIVIDE(
    COALESCE(f.active_days_7d, 0),
    NULLIF(COALESCE(f.active_days_30d, 0), 0)
  ) AS active_days_ratio_7d_30d,

  SAFE_DIVIDE(
    COALESCE(f.total_session_time_7d, 0),
    NULLIF(COALESCE(f.total_session_time_30d, 0), 0)
  ) AS session_time_ratio_7d_30d,

  SAFE_DIVIDE(
    COALESCE(f.login_count_14d, 0),
    NULLIF(COALESCE(f.login_count_30d, 0), 0)
  ) AS login_ratio_14d_30d,

  SAFE_DIVIDE(
    COALESCE(f.total_session_time_14d, 0),
    NULLIF(COALESCE(f.total_session_time_30d, 0), 0)
  ) AS session_time_ratio_14d_30d,

  -- 密度・強度
  SAFE_DIVIDE(COALESCE(f.login_count_30d, 0), 30) AS avg_login_per_day_30d,
  SAFE_DIVIDE(COALESCE(f.active_days_30d, 0), 30) AS active_day_rate_30d,
  SAFE_DIVIDE(
    COALESCE(f.total_session_time_30d, 0),
    NULLIF(COALESCE(f.login_count_30d, 0), 0)
  ) AS avg_session_time_per_login_30d,
  SAFE_DIVIDE(
    COALESCE(f.total_session_time_30d, 0),
    NULLIF(COALESCE(f.active_days_30d, 0), 0)
  ) AS avg_session_time_per_active_day_30d,

  SAFE_DIVIDE(
    COALESCE(f.login_count_7d, 0),
    NULLIF(COALESCE(f.active_days_7d, 0), 0)
  ) AS login_per_active_day_7d,

  SAFE_DIVIDE(
    COALESCE(f.total_session_time_7d, 0),
    NULLIF(COALESCE(f.active_days_7d, 0), 0)
  ) AS session_per_active_day_7d,

  -- decline / momentum 系
  CASE
    WHEN COALESCE(f.login_count_7d, 0) < COALESCE(f.login_count_prev_7d, 0) THEN 1
    ELSE 0
  END AS is_login_declining,

  CASE
    WHEN COALESCE(f.total_session_time_7d, 0) < COALESCE(f.total_session_time_prev_7d, 0) THEN 1
    ELSE 0
  END AS is_session_declining,

  CASE
    WHEN COALESCE(f.login_count_14d, 0) < COALESCE(f.login_count_prev_14d, 0) THEN 1
    ELSE 0
  END AS is_shrinking_14d_vs_prev14d,

  CASE
    WHEN COALESCE(f.login_count_7d, 0) = 0
     AND COALESCE(f.login_count_30d, 0) > 0 THEN 1
    ELSE 0
  END AS recently_dropped_to_zero,

  SAFE_DIVIDE(
    COALESCE(f.login_count_7d, 0),
    NULLIF(COALESCE(f.login_count_14d, 0), 0)
  ) AS momentum_7d_14d,

  SAFE_DIVIDE(
    COALESCE(f.total_session_time_7d, 0),
    NULLIF(COALESCE(f.total_session_time_14d, 0), 0)
  ) AS session_momentum_7d_14d,

  SAFE_DIVIDE(
    CASE
      WHEN f.last_login_date IS NULL THEN 60
      ELSE LEAST(DATE_DIFF(u.base_date, f.last_login_date, DAY), 60)
    END,
    30
  ) AS recency_ratio_7d_30d,

  -- inactivity系
  CASE WHEN COALESCE(f.login_count_7d, 0) = 0 THEN 1 ELSE 0 END AS is_inactive_7d,
  CASE WHEN COALESCE(f.login_count_14d, 0) = 0 THEN 1 ELSE 0 END AS is_inactive_14d,
  CASE WHEN COALESCE(f.login_count_30d, 0) = 0 THEN 1 ELSE 0 END AS is_inactive_30d,

  CASE WHEN COALESCE(f.active_days_30d, 0) <= 2 THEN 1 ELSE 0 END AS is_low_activity_30d,
  CASE WHEN COALESCE(f.active_days_30d, 0) <= 5 THEN 1 ELSE 0 END AS is_mid_low_activity_30d,

  CASE WHEN
    CASE
      WHEN f.last_login_date IS NULL THEN 60
      ELSE LEAST(DATE_DIFF(u.base_date, f.last_login_date, DAY), 60)
    END >= 7
  THEN 1 ELSE 0 END AS recency_ge_7d,

  CASE WHEN
    CASE
      WHEN f.last_login_date IS NULL THEN 60
      ELSE LEAST(DATE_DIFF(u.base_date, f.last_login_date, DAY), 60)
    END >= 14
  THEN 1 ELSE 0 END AS recency_ge_14d,

  CASE WHEN
    CASE
      WHEN f.last_login_date IS NULL THEN 60
      ELSE LEAST(DATE_DIFF(u.base_date, f.last_login_date, DAY), 60)
    END >= 30
  THEN 1 ELSE 0 END AS recency_ge_30d,

  -- ユーザー成熟度
  CASE
    WHEN DATE_DIFF(u.base_date, u.signup_date, DAY) < 14 THEN 'new'
    WHEN DATE_DIFF(u.base_date, u.signup_date, DAY) < 45 THEN 'middle'
    ELSE 'mature'
  END AS user_tenure_segment,

  -- 活動セグメント
  CASE
    WHEN COALESCE(f.login_count_30d, 0) >= 15 THEN 'heavy'
    WHEN COALESCE(f.login_count_30d, 0) >= 8 THEN 'normal'
    WHEN COALESCE(f.login_count_30d, 0) >= 3 THEN 'light'
    ELSE 'rare'
  END AS activity_segment_30d,

  -- label
  CASE
    WHEN COALESCE(l.future_login_count_30d, 0) <= 2 THEN 1
    ELSE 0
  END AS label_churn

FROM users_base u
LEFT JOIN feature_agg f
  ON u.user_id = f.user_id
 AND u.base_date = f.base_date
LEFT JOIN label_agg l
  ON u.user_id = l.user_id;