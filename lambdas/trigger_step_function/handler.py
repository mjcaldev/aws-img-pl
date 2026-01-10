import json
import logging
import os
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SFN_ARN = os.environ.get("STATE_MACHINE_ARN")
if not SFN_ARN:
    raise ValueError("STATE_MACHINE_ARN environment variable is required")

sfn = boto3.client("stepfunctions")

def lambda_handler(event, context):
    try:
        # event is S3 put notification
        # extract bucket + key and kick off Step Functions
        records = event.get("Records", [])
        if not records:
            return {"statusCode": 400, "body": "No records"}

        record = records[0]
        bucket = record.get("s3", {}).get("bucket", {}).get("name")
        key = record.get("s3", {}).get("object", {}).get("key")

        if not bucket or not key:
            raise ValueError(f"Missing required S3 event fields: bucket={bucket}, key={key}")

        input_payload = {
            "bucket": bucket,
            "key": key,
        }
        
        # loop guard
        if key.startswith("processed/"):
            logger.info(f"Skipping already processed object: {key}")
            return {
                "statusCode": 200,
                "body": "Skipped processed object"
            }

        response = sfn.start_execution(
            stateMachineArn=SFN_ARN,
            input=json.dumps(input_payload),
        )

        logger.info(f"Started Step Functions execution: {response['executionArn']}")
        return {"statusCode": 200, "body": "Started state machine"}

    except Exception as e:
        logger.exception(f"Error processing S3 event: {str(e)}")
        raise