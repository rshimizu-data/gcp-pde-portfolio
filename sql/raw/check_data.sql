-- レコード数
SELECT COUNT(*) FROM raw.activity_log;

-- 日付範囲
SELECT MIN(activity_date), MAX(activity_date)
FROM raw.activity_log;

-- ユーザー数
SELECT COUNT(DISTINCT user_id)
FROM raw.activity_log;