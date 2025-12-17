import json
import os
import boto3

SFN_ARN = os.environ.get("STATE_MACHINE_ARN")

sfn = boto3.client("stepfunctions")

def lambda_handler(event, context):
    # event is S3 put notification
    # extract bucket + key and kick off Step Functions
    records = event.get("Records", [])
    if not records:
        return {"statusCode": 400, "body": "No records"}

    record = records[0]
    bucket = record["s3"]["bucket"]["name"]
    key = record["s3"]["object"]["key"]

    input_payload = {
        "bucket": bucket,
        "key": key,
    }
    
    # loop guard
    if key.startswith("processed/"):
        print(f"Skipping already processed object: {key}")
        return {
            "statusCode": 200,
            "body": "Skipped processed object"
        }

    sfn.start_execution(
        stateMachineArn=SFN_ARN,
        input=json.dumps(input_payload),
    )

    return {"statusCode": 200, "body": "Started state machine"}