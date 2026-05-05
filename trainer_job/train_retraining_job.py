import os

PROJECT_ID = os.environ.get("PROJECT_ID")
BQ_LOCATION = os.environ.get("BQ_LOCATION", "asia-northeast1")
RETRAINING_TABLE = os.environ.get("RETRAINING_TABLE")
MODEL_BUCKET = os.environ.get("MODEL_BUCKET")
MODEL_PREFIX = os.environ.get("MODEL_PREFIX")

query = f"""
SELECT *
FROM `{RETRAINING_TABLE}`
WHERE actual_churn_label IS NOT NULL
"""

print("=== retraining query ===")
print(query)

print("status: skip")
print("reason: labeled data not implemented yet")