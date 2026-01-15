import json
import boto3
import logging
import os
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")

# Maximum processing time: 5 minutes
MAX_PROCESSING_SECONDS = 300

def build_response(status_code, body):
    """Build HTTP response with CORS headers."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Allow-Methods": "GET,OPTIONS"
        },
        "body": json.dumps(body)
    }

def lambda_handler(event, context):
    try:
        # Handle OPTIONS preflight request
        http_method = event.get("requestContext", {}).get("http", {}).get("method", "")
        if http_method == "OPTIONS":
            logger.info("OPTIONS preflight request")
            return build_response(200, {})
        
        # Extract image_key from query parameters
        query_params = event.get("queryStringParameters") or {}
        image_key = query_params.get("image_key")
        
        if not image_key:
            logger.warning("Missing image_key query parameter")
            return build_response(400, {
                "status": "FAILED",
                "reason": "image_key query parameter is required"
            })
        
        logger.info(f"GET /results request: image_key={image_key}")
        
        # Get table name from environment
        table_name = os.environ.get("TABLE_NAME")
        if not table_name:
            logger.error("TABLE_NAME environment variable not set")
            return build_response(500, {
                "status": "FAILED",
                "reason": "Server configuration error"
            })
        
        table = dynamodb.Table(table_name)
        
        # Query DynamoDB for the image metadata
        try:
            logger.info(f"DynamoDB lookup: table={table_name}, key={{'image_key': '{image_key}'}}")
            response = table.get_item(Key={"image_key": image_key})
            
            if "Item" not in response:
                logger.info(f"Record not found: image_key={image_key} - status=PROCESSING")
                return build_response(200, {
                    "status": "PROCESSING"
                })
            
            item = response["Item"]
            labels = item.get("labels", [])
            created_at_str = item.get("created_at")
            
            # Check for timeout if created_at exists
            if created_at_str:
                try:
                    created_at = datetime.fromisoformat(created_at_str.replace("Z", "+00:00"))
                    now = datetime.now(timezone.utc)
                    elapsed_seconds = (now - created_at).total_seconds()
                    
                    logger.info(f"Record found: image_key={image_key}, created_at={created_at_str}, elapsed_seconds={elapsed_seconds:.1f}, labels_count={len(labels)}")
                    
                    if elapsed_seconds > MAX_PROCESSING_SECONDS:
                        logger.warning(f"Processing timeout: image_key={image_key}, elapsed={elapsed_seconds:.1f}s > {MAX_PROCESSING_SECONDS}s")
                        return build_response(200, {
                            "status": "FAILED",
                            "reason": "Processing timeout"
                        })
                except (ValueError, TypeError) as time_error:
                    logger.warning(f"Could not parse created_at timestamp: {created_at_str}, error: {time_error}")
            else:
                logger.info(f"Record found (no timestamp): image_key={image_key}, labels_count={len(labels)}")
            
            # Check if labels exist (complete) or if it's a failed state
            if not labels or len(labels) == 0:
                logger.warning(f"Record found but no labels: image_key={image_key} - status=FAILED")
                return build_response(200, {
                    "status": "FAILED",
                    "reason": "Processing completed but no labels found"
                })
            
            logger.info(f"Record complete: image_key={image_key}, labels_count={len(labels)} - status=COMPLETE")
            return build_response(200, {
                "status": "COMPLETE",
                "results": {
                    "labels": labels,
                    "image_key": item.get("image_key"),
                    "bucket": item.get("bucket")
                }
            })
            
        except Exception as db_error:
            logger.exception(f"DynamoDB error: image_key={image_key}, error={str(db_error)}")
            return build_response(500, {
                "status": "FAILED",
                "reason": "Database error"
            })
            
    except Exception as e:
        logger.exception(f"Unexpected error in get_results handler: {str(e)}")
        return build_response(500, {
            "status": "FAILED",
            "reason": "Internal server error"
        })
