import json
import boto3
import os
import uuid

s3 = boto3.client("s3")
BUCKET = os.environ.get("UPLOAD_BUCKET")

def lambda_handler(event, context):
    body = json.loads(event.get("body", "{}"))

    image_id = str(uuid.uuid4())
    key = f"uploads/{image_id}.jpg"

    url = s3.generate_presigned_url(
        "put_object",
        Params={"Bucket": BUCKET, "Key": key, "ContentType": "image/jpeg"},
        ExpiresIn=300
    )

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "uploadUrl": url,
            "key": key
        })
    }