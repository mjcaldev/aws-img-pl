import json
import boto3
import os

dynamodb = boto3.resource("dynamodb")

TABLE_NAME = os.environ.get("TABLE_NAME")
table = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    print("Event:", event)

    bucket = event["bucket"]
    key = event["processed_key"]
    labels = event["labels"]

    table.put_item(
        Item={
            "image_key": key,
            "bucket": bucket,
            "labels": labels
        }
    )

    return {"status": "stored", "image_key": key}