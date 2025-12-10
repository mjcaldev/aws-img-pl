import boto3

s3 = boto3.client("s3")

def lambda_handler(event, context):
    print("Event received:", event)

    bucket = event["bucket"]
    key = event["key"]

    output_key = f"processed/{key}"

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