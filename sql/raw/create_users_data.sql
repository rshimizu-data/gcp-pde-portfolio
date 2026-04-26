CREATE OR REPLACE TABLE `churn-analysis-491912.raw.users` AS
WITH user_base AS (
  SELECT
    GENERATE_ARRAY(1, 500) AS ids
)

SELECT
  CONCAT('U', LPAD(CAST(id AS STRING), 4, '0')) AS user_id,

  -- 登録日（90日前〜30日前）
  DATE_SUB(DATE '2025-03-31', INTERVAL CAST(30 + RAND()*60 AS INT64) DAY) AS signup_date,

  -- プラン
  CASE
    WHEN RAND() < 0.6 THEN 'free'
    WHEN RAND() < 0.9 THEN 'standard'
    ELSE 'premium'
  END AS plan_type,

  -- 年齢
  CAST(18 + RAND()*50 AS INT64) AS age,

  -- 性別
  CASE
    WHEN RAND() < 0.5 THEN 'male'
    ELSE 'female'
  END AS gender

FROM user_base, UNNEST(ids) AS id;