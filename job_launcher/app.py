import os
import json
from flask import Flask, request, jsonify
from google.cloud import run_v2

app = Flask(__name__)

PROJECT_ID = os.environ.get("PROJECT_ID")
REGION = os.environ.get("REGION", "asia-northeast1")
JOB_NAME = os.environ.get("JOB_NAME", "retraining-job")


@app.route("/", methods=["POST"])
def launch_job():
    envelope = request.get_json(silent=True) or {}

    print("Received Eventarc request:")
    print(json.dumps(envelope, ensure_ascii=False))

    if not PROJECT_ID:
        return jsonify({"status": "error", "message": "PROJECT_ID is not set"}), 500

    client = run_v2.JobsClient()

    job_path = client.job_path(
        project=PROJECT_ID,
        location=REGION,
        job=JOB_NAME,
    )

    operation = client.run_job(name=job_path)

    print(f"Started Cloud Run Job: {job_path}")
    print(f"Operation: {operation.operation.name}")

    return jsonify({
        "status": "ok",
        "message": "retraining job started",
        "job": job_path,
        "operation": operation.operation.name,
    }), 200


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"}), 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)