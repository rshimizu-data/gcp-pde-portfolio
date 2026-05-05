import streamlit as st
from google.cloud import bigquery
import pandas as pd

PROJECT_ID = "churn-analysis-491912"
BQ_LOCATION = "asia-northeast1"
DATASET = "ml_logs"

st.set_page_config(
    page_title="推論ログ可視化ダッシュボード",
    layout="wide"
)

st.title("推論ログ可視化ダッシュボード")
st.caption("Cloud Run /predict → BigQuery prediction_logs → Streamlit")

client = bigquery.Client(project=PROJECT_ID)

@st.cache_data(ttl=300)
def run_query(sql: str) -> pd.DataFrame:
    job = client.query(sql, location=BQ_LOCATION)
    return job.to_dataframe()

daily_sql = f"""
SELECT *
FROM `{PROJECT_ID}.{DATASET}.v_prediction_daily_summary`
ORDER BY log_date DESC
"""

model_sql = f"""
SELECT *
FROM `{PROJECT_ID}.{DATASET}.v_prediction_model_summary`
ORDER BY prediction_count DESC
"""

user_sql = f"""
SELECT *
FROM `{PROJECT_ID}.{DATASET}.v_prediction_user_latest`
ORDER BY request_time DESC
"""

daily_df = run_query(daily_sql)
model_df = run_query(model_sql)
user_df = run_query(user_sql)

st.sidebar.header("フィルター")

model_versions = sorted(user_df["model_version"].dropna().unique()) if "model_version" in user_df.columns else []
variants = sorted(user_df["variant"].dropna().unique()) if "variant" in user_df.columns else []

selected_model_version = st.sidebar.multiselect(
    "model_version",
    model_versions,
    default=model_versions
)

selected_variant = st.sidebar.multiselect(
    "variant",
    variants,
    default=variants
)

filtered_user_df = user_df.copy()

if selected_model_version:
    filtered_user_df = filtered_user_df[
        filtered_user_df["model_version"].isin(selected_model_version)
    ]

if selected_variant:
    filtered_user_df = filtered_user_df[
        filtered_user_df["variant"].isin(selected_variant)
    ]

col1, col2, col3 = st.columns(3)

with col1:
    st.metric(
        "推論件数",
        int(daily_df["prediction_count"].sum()) if not daily_df.empty else 0
    )

with col2:
    st.metric(
        "平均離脱確率",
        round(float(daily_df["avg_probability"].mean()), 4) if not daily_df.empty else 0
    )

with col3:
    st.metric(
        "平均離脱予測率",
        round(float(daily_df["predicted_churn_rate"].mean()), 4) if not daily_df.empty else 0
    )

st.subheader("日次推論ログ")
st.dataframe(daily_df, use_container_width=True)

st.subheader("日次推論件数")
if not daily_df.empty:
    chart_df = daily_df.sort_values("log_date").set_index("log_date")
    st.line_chart(chart_df["prediction_count"])

st.subheader("日次 平均離脱確率")
if not daily_df.empty:
    chart_df = daily_df.sort_values("log_date").set_index("log_date")
    st.line_chart(chart_df["avg_probability"])

st.subheader("日次 離脱予測率")
if not daily_df.empty:
    chart_df = daily_df.sort_values("log_date").set_index("log_date")
    st.line_chart(chart_df["predicted_churn_rate"])

st.subheader("モデル別・variant別 推論状況")
st.dataframe(model_df, use_container_width=True)

st.subheader("ユーザー別 最新推論ログ")
st.dataframe(filtered_user_df, use_container_width=True)
