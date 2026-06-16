import json
from datetime import datetime, timezone

import apache_beam as beam
from apache_beam.io.gcp.bigquery import WriteToBigQuery
from apache_beam.io.gcp.pubsub import ReadFromPubSub

from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.options.pipeline_options import StandardOptions


SUBSCRIPTION = "projects/churn-analysis-491912/subscriptions/user-events-sub"


def decode_message(message):
    return message.decode("utf-8")


def transform_event(event_json):
    import json
    from datetime import datetime, timezone

    event = json.loads(event_json)

    event["event_type"] = event["event_type"].upper()
    event["processed_flag"] = True
    event["processed_at"] = datetime.now(timezone.utc).isoformat()

    return event


def main():
    options = PipelineOptions(
        runner="DataflowRunner",
        project="churn-analysis-491912",
        region="asia-northeast2",
        temp_location="gs://churn-model-bucket-ryo/temp",
        job_name="beam-streaming-user-events-v2",
    )

    options.view_as(StandardOptions).streaming = True

    with beam.Pipeline(options=options) as pipeline:
        (
            pipeline
            | "ReadFromPubSub" >> ReadFromPubSub(subscription=SUBSCRIPTION)
            | "DecodeMessage" >> beam.Map(decode_message)
            | "TransformEvent" >> beam.Map(transform_event)
            | "WriteToBigQuery" >> WriteToBigQuery(
                table="churn-analysis-491912:raw_stream.user_events_transformed",
                schema={
                    "fields": [
                        {"name": "event_id", "type": "STRING", "mode": "NULLABLE"},
                        {"name": "event_type", "type": "STRING", "mode": "NULLABLE"},
                        {"name": "user_id", "type": "STRING", "mode": "NULLABLE"},
                        {"name": "event_timestamp", "type": "STRING", "mode": "NULLABLE"},
                        {"name": "processed_flag", "type": "BOOLEAN", "mode": "NULLABLE"},
                        {"name": "processed_at", "type": "STRING", "mode": "NULLABLE"}
                    ]
                },
                write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND,
                create_disposition=beam.io.BigQueryDisposition.CREATE_NEVER,
                method=WriteToBigQuery.Method.STREAMING_INSERTS
            )
        )


if __name__ == "__main__":
    main()
