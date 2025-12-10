output "uploads_bucket_name" {
  value = aws_s3_bucket.uploads.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.image_metadata.name
}

output "api_base_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}