import json
import os
from datetime import datetime, timezone
from google.cloud import pubsub_v1

PROJECT_ID = os.environ.get("PROJECT_ID", "churn-analysis-491912")
TOPIC_ID = os.environ.get("MLOPS_EVENT_TOPIC", "mlops-events")

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)


def publish_mlops_event(event_type: str, payload: dict) -> str:
    """
    MLOpsイベントをPub/Subへ送信する共通関数
    """

    message = {
        "event_type": event_type,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "source": payload.get("source", "unknown"),
        "payload": payload,
    }

    data = json.dumps(message, ensure_ascii=False).encode("utf-8")

    future = publisher.publish(
        topic_path,
        data,
        event_type=event_type,
        source=message["source"],
    )

    message_id = future.result()
    print(f"Published MLOps event. event_type={event_type}, message_id={message_id}")

    return message_id
