FROM python:3.11-slim

WORKDIR /app

COPY requirements-drift.txt .
RUN pip install --no-cache-dir -r requirements-drift.txt

COPY drift_check_job.py .
COPY drift_metrics.py .
COPY src ./src

CMD ["python", "drift_check_job.py"]