resource "aws_s3_bucket" "uploads" {
  bucket        = var.uploads_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "allow_s3_to_invoke" {
  statement_id  = "AllowS3InvokeTrigger"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger_step_function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.uploads.arn
}

resource "aws_s3_bucket_notification" "uploads_trigger" {
  bucket = aws_s3_bucket.uploads.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.trigger_step_function.arn
    events              = ["s3:ObjectCreated:*"]

    filter_prefix = "uploads/"
  }

  depends_on = [aws_lambda_permission.allow_s3_to_invoke]
}
