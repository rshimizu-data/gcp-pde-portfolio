import pickle
from pathlib import Path

import lightgbm as lgb
import pandas as pd
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import train_test_split


# =========================
# 設定
# =========================
TRAIN_PATH = "data/processed/train.csv"
MODEL_PATH = "model.pkl"
IMPORTANCE_PATH = "feature_importance.csv"

TARGET_COL = "label_churn"

# 学習に使わない列
DROP_COLS = [
    "user_id",
    "label_churn",
    "signup_date",
    "base_date",
    "login_per_active_day_7d",  # 固定値になりやすいので除外
    "future_login_count_30d",
]

# カテゴリ列
CATEGORICAL_COLS = [
    "plan_type",
    "gender",
    "user_tenure_segment",
    "activity_segment_30d",
]


# =========================
# ① データ読み込み
# =========================
def load_data(path: str) -> pd.DataFrame:
    file_path = Path(path)
    if not file_path.exists():
        raise FileNotFoundError(f"学習データが見つかりません: {file_path}")

    df = pd.read_csv(file_path)
    print(f"データ読み込み完了: {file_path}")
    print(f"shape = {df.shape}")
    return df


# =========================
# ② 前処理
# =========================
def preprocess(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.Series]:
    if TARGET_COL not in df.columns:
        raise ValueError(f"{TARGET_COL} 列が存在しません")

    y = df[TARGET_COL].copy()

    drop_cols = [col for col in DROP_COLS if col in df.columns]
    X = df.drop(columns=drop_cols).copy()

    # カテゴリ列を category 型へ
    categorical_cols = [col for col in CATEGORICAL_COLS if col in X.columns]
    for col in categorical_cols:
        X[col] = X[col].astype("category")

    print("\n=== 使用特徴量 ===")
    for col in X.columns:
        print(col)

    print("\n=== 目的変数分布 ===")
    print(y.value_counts(dropna=False).sort_index())
    print(f"churn_rate = {y.mean():.4f}")

    return X, y


# =========================
# ③ 学習
# =========================
def train_model(
    X_train: pd.DataFrame,
    y_train: pd.Series,
    X_valid: pd.DataFrame,
    y_valid: pd.Series,
) -> lgb.LGBMClassifier:
    categorical_cols = [col for col in CATEGORICAL_COLS if col in X_train.columns]

    model = lgb.LGBMClassifier(
        objective="binary",
        n_estimators=500,
        learning_rate=0.03,
        max_depth=-1,
        num_leaves=31,
        min_child_samples=20,
        subsample=0.8,
        colsample_bytree=0.8,
        class_weight="balanced",
        random_state=42,
    )

    model.fit(
        X_train,
        y_train,
        eval_set=[(X_valid, y_valid)],
        eval_metric="auc",
        categorical_feature=categorical_cols,
        callbacks=[
            lgb.early_stopping(stopping_rounds=50),
            lgb.log_evaluation(period=50),
        ],
    )

    return model


# =========================
# ④ 評価
# =========================
def evaluate_model(
    model: lgb.LGBMClassifier,
    X_valid: pd.DataFrame,
    y_valid: pd.Series,
) -> float:
    y_pred = model.predict_proba(X_valid)[:, 1]
    auc = roc_auc_score(y_valid, y_pred)
    print(f"\nAUC: {auc:.4f}")
    return auc


# =========================
# ⑤ 特徴量重要度
# =========================
def save_feature_importance(
    model: lgb.LGBMClassifier,
    feature_names: list[str],
    output_path: str,
) -> pd.DataFrame:
    importance_df = pd.DataFrame(
        {
            "feature": feature_names,
            "importance": model.feature_importances_,
        }
    ).sort_values("importance", ascending=False)

    print("\n=== feature importance ===")
    print(importance_df.head(30).to_string(index=False))

    importance_df.to_csv(output_path, index=False, encoding="utf-8-sig")
    print(f"\n特徴量重要度を保存しました: {output_path}")

    return importance_df


# =========================
# ⑥ モデル保存
# =========================
def save_model(model: lgb.LGBMClassifier, output_path: str) -> None:
    with open(output_path, "wb") as f:
        pickle.dump(model, f)
    print(f"モデル保存完了: {output_path}")


# =========================
# ⑦ メイン処理
# =========================
def main() -> None:
    df = load_data(TRAIN_PATH)
    X, y = preprocess(df)

    X_train, X_valid, y_train, y_valid = train_test_split(
        X,
        y,
        test_size=0.2,
        random_state=42,
        stratify=y,
    )

    print("\n=== 分割後データ件数 ===")
    print(f"train: {X_train.shape}")
    print(f"valid: {X_valid.shape}")

    model = train_model(X_train, y_train, X_valid, y_valid)
    evaluate_model(model, X_valid, y_valid)
    save_feature_importance(model, X_train.columns.tolist(), IMPORTANCE_PATH)
    save_model(model, MODEL_PATH)


if __name__ == "__main__":
    main()