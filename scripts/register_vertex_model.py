from src.trainer.vertex_ai_register import register_to_vertex
import os

# ★ローカル用に環境変数を明示
os.environ["PROJECT_ID"] = "churn-analysis-491912"
os.environ["REGION"] = "asia-northeast1"
os.environ["EXPERIMENT_ID"] = "churn_experiment_001"
os.environ["MODEL_VERSION"] = "test_v1"
os.environ["MODEL_DISPLAY_NAME"] = "churn-lightgbm-test"

if __name__ == "__main__":
    # ★実在するモデルパスにする
    model_uri = "gs://churn-model-bucket-ryo/models/versions/v1/model.pkl"

    register_to_vertex(
        auc=0.5,
        model_uri=model_uri
    )
