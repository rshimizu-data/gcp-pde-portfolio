import base64
import json
import os

import google.auth
from google.auth.transport.requests import AuthorizedSession
from flask import Flask, jsonify, request

app = Flask(__name__)

PROJECT_ID = os.environ.get("PROJECT_ID", "churn-analysis-491912")
REGION = os.environ.get("REGION", "asia-northeast1")
RETRAINING_JOB = os.environ.get("RETRAINING_JOB", "churn-retraining-job")


def run_cloud_run_job(job_name: str) -> dict:
    credentials, _ = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    authed_session = AuthorizedSession(credentials)

    url = (
        f"https://run.googleapis.com/v2/projects/{PROJECT_ID}"
        f"/locations/{REGION}/jobs/{job_name}:run"
    )

    print("==== Trigger Cloud Run Job ====")
    print("PROJECT_ID:", PROJECT_ID)
    print("REGION:", REGION)
    print("JOB:", job_name)
    print("URL:", url)

    response = authed_session.post(url, json={})

    print("Cloud Run Job API status:", response.status_code)
    print("Cloud Run Job API response:", response.text)

    response.raise_for_status()
    return response.json()


def parse_pubsub_event(req) -> dict:
    envelope = req.get_json(silent=True)

    print("==== Raw Eventarc Request ====")
    print(json.dumps(envelope, ensure_ascii=False, indent=2))

    if not envelope:
        raise ValueError("No JSON payload received.")

    message = envelope.get("message", {})
    data = message.get("data")

    if not data:
        raise ValueError("No Pub/Sub message data received.")

    decoded = base64.b64decode(data).decode("utf-8")
    event = json.loads(decoded)

    print("==== Decoded Pub/Sub Event ====")
    print(json.dumps(event, ensure_ascii=False, indent=2))

    return event


@app.route("/", methods=["POST"])
def handle_event():
    try:
        event = parse_pubsub_event(request)

        event_type = event.get("event_type")
        payload = event.get("payload", {})
        action = payload.get("action")

        print("==== Event Received ====")
        print("Received event_type:", event_type)
        print("Received action:", action)
        print("Received payload:", json.dumps(payload, ensure_ascii=False))

        if action == "trigger_retraining" and event_type in [
            "drift_detected",
            "ab_test_degraded",
        ]:
            result = run_cloud_run_job(RETRAINING_JOB)

            print("==== Event Handling Result ====")
            print("status: retraining_job_triggered")
            print("event_type:", event_type)
            print("job:", RETRAINING_JOB)

            return jsonify({
                "status": "retraining_job_triggered",
                "event_type": event_type,
                "job": RETRAINING_JOB,
                "result": result,
            }), 200

        print("==== Event Ignored ====")
        print("reason: No retraining action required.")

        return jsonify({
            "status": "ignored",
            "event_type": event_type,
            "reason": "No retraining action required.",
        }), 200

    except Exception as e:
        print("==== Event Handling Error ====")
        print("error:", str(e))

        return jsonify({
            "status": "error",
            "message": str(e),
        }), 500


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"}), 200
