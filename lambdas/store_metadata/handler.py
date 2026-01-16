import json
import boto3
import logging
import os
from datetime import datetime

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
        processed_key = event.get("processed_key")
        original_key = event.get("key")  # Original upload key from Step Functions input
        labels = event.get("labels")

        if not bucket:
            raise ValueError("Missing required field: bucket")
        if not processed_key:
            raise ValueError("Missing required field: processed_key")
        if labels is None:
            raise ValueError("Missing required field: labels")

        # Use original key for lookup (what frontend polls with)
        # Fallback to processed_key if original_key not available
        if not original_key:
            raise ValueError("Missing required field: key (original upload key)")
        image_key = original_key
        
        logger.info(f"Storing metadata: image_key={image_key}, processed_key={processed_key}, labels_count={len(labels)}")

        table.put_item(
            Item={
                "image_key": image_key,
                "bucket": bucket,
                "processed_key": processed_key,
                "labels": labels,
                "created_at": datetime.utcnow().isoformat() + "Z"
            }
        )

        logger.info(f"Successfully stored metadata for image_key: {image_key}")
        return {"status": "stored", "image_key": image_key}

    except Exception as e:
        logger.exception("Failed to store metadata in DynamoDB")
        raise