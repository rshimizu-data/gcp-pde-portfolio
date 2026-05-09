import subprocess
from src.events.publish_event import publish_mlops_event

PROJECT_ID = "churn-analysis-491912"
REGION = "asia-northeast1"
JOB_NAME = "retraining-job"

def main():
    cmd = [
        r"C:\Users\rshim\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd",
        "run", "jobs", "executions", "list",
        f"--job={JOB_NAME}",
        f"--region={REGION}",
        "--format=value(EXECUTION,COMPLETE)"
    ]

    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        check=True,
    )

    lines = [line for line in result.stdout.splitlines() if line.strip()]

    if not lines:
        print("No executions found.")
        return

    latest = lines[0]
    parts = latest.split()

    execution_name = parts[0]
    complete_status = parts[1] if len(parts) > 1 else ""

    job_failed = complete_status not in ["1", "1/1"]

    print(f"execution_name={execution_name}")
    print(f"complete_status={complete_status}")
    print(f"job_failed={job_failed}")

    if job_failed:
        publish_mlops_event(
            event_type="job_failure",
            payload={
                "source": "job_failure_check",
                "project_id": PROJECT_ID,
                "severity": "critical",
                "message": "Cloud Run Jobs execution failed.",
                "job_name": JOB_NAME,
                "execution_name": execution_name,
                "complete_status": complete_status,
            },
            topic_id="mlops-alerts",
        )

        print("status: job_failure_detected")
        print("action: publish_alert_event")

    else:
        print("status: job_success")
        print("action: skip_alert_event")

if __name__ == "__main__":
    main()
