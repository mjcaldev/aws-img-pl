import boto3
import botocore

config = botocore.config.Config(read_timeout=3, connect_timeout=3)

dynamodb = boto3.resource("dynamodb", config=config)
s3 = boto3.client("s3", config=config)

s3 = boto3.client("s3")

def lambda_handler(event, context):
    print("Event received:", event)

    bucket = event["bucket"]
    key = event["key"]
    
    # stop infinite recursion
    if key.startswith("processed/"):
        print(f"Skipping already processed object: {key}")
        return event
    # only handle images
    if not key.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
        print(f"Skipping non-image file: {key}")
        return event   

    filename = key.split("/")[-1]
    output_key = f"processed/{filename}"

    # Minimal functional version: copy file instead of resizing
    s3.copy_object(
        Bucket=bucket,
        CopySource={"Bucket": bucket, "Key": key},
        Key=output_key
    )

    return {
        "bucket": bucket,
        "processed_key": output_key
    }