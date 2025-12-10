import boto3

rekognition = boto3.client("rekognition")

def lambda_handler(event, context):
    print("Event:", event)

    bucket = event["bucket"]
    key = event["processed_key"]

    response = rekognition.detect_labels(
        Image={"S3Object": {"Bucket": bucket, "Name": key}},
        MaxLabels=10,
        MinConfidence=70
    )

    labels = [label["Name"] for label in response["Labels"]]

    return {
        "bucket": bucket,
        "processed_key": key,
        "labels": labels
    }
