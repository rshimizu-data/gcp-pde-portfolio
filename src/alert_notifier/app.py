from flask import Flask, request
import base64
import json
import logging
import requests
import os

app = Flask(__name__)

logging.basicConfig(level=logging.INFO)

SLACK_WEBHOOK_URL = os.environ.get("SLACK_WEBHOOK_URL")


@app.route("/", methods=["POST"])
def receive_alert():

    envelope = request.get_json()

    if not envelope:
        logging.error("No Pub/Sub message received")
        return ("Bad Request", 400)

    pubsub_message = envelope.get("message")

    if not pubsub_message:
        logging.error("No message field")
        return ("Bad Request", 400)

    data = pubsub_message.get("data")

    if data:
        decoded_data = base64.b64decode(data).decode("utf-8")

        try:
            payload = json.loads(decoded_data)
        except Exception:
            payload = {"raw_message": decoded_data}

        logging.info(f"ALERT RECEIVED: {payload}")

        if SLACK_WEBHOOK_URL:
            slack_message = {
                "text": f"""
MLOps Alert

event_type: {payload.get("event_type")}

payload:
{json.dumps(payload.get("payload", {}), ensure_ascii=False, indent=2)}
"""
            }

            try:
                response = requests.post(
                    SLACK_WEBHOOK_URL,
                    json=slack_message,
                    timeout=10,
                )

                logging.info(f"slack_status={response.status_code}")

            except Exception as e:
                logging.error(f"slack_error={e}")

    return ("OK", 200)


@app.route("/health", methods=["GET"])
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)