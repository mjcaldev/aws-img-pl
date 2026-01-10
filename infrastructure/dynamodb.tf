resource "aws_dynamodb_table" "image_metadata" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "image_key"

  attribute {
    name = "image_key"
    type = "S"
  }

  # Optional: add GSI later for querying by userId, tag, etc.
}