import json
import boto3
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")

def lambda_handler(event, context):
    try:
        table_name = os.environ.get("TABLE_NAME")
        if not table_name:
            raise ValueError("TABLE_NAME environment variable not set")

        table = dynamodb.Table(table_name)

        logger.info(f"Event: {event}")

        bucket = event.get("bucket")
        key = event.get("processed_key")
        labels = event.get("labels")

        if not bucket:
            raise ValueError("Missing required field: bucket")
        if not key:
            raise ValueError("Missing required field: processed_key")
        if labels is None:
            raise ValueError("Missing required field: labels")

        table.put_item(
            Item={
                "image_key": key,
                "bucket": bucket,
                "labels": labels
            }
        )

        return {"status": "stored", "image_key": key}

    except Exception as e:
        logger.exception("Failed to store metadata in DynamoDB")
        raise