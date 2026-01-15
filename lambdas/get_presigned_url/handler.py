import json
import boto3
import os
import uuid

s3 = boto3.client("s3")
BUCKET = os.environ.get("UPLOAD_BUCKET")

def lambda_handler(event, context):
    # Safely handle missing or None body from HTTP API
    body_str = event.get("body") or "{}"
    body = json.loads(body_str)

    contentType = body.get("contentType")
    if not contentType:
        return {
            "statusCode": 400,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({"error": "contentType is required"})
        }

    # Map content type to file extension
    extension_map = {
        "image/jpeg": ".jpg",
        "image/jpg": ".jpg",
        "image/png": ".png",
        "image/webp": ".webp"
    }
    extension = extension_map.get(contentType, ".jpg")
    
    image_id = str(uuid.uuid4())
    key = f"uploads/{image_id}{extension}"

    url = s3.generate_presigned_url(
        "put_object",
        Params={"Bucket": BUCKET, "Key": key, "ContentType": contentType},
        ExpiresIn=300
    )

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps({
            "uploadUrl": url,
            "key": key
        })
    }