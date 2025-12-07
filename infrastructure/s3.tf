resource "aws_s3_bucket" "uploads" {
  bucket        = var.uploads_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket_uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket_uploads.id

  versioning_configuration {
    status = "Enabled"
  }
}

# later add an aws_s3_bucket_notification here to wire S3 → trigger_step_function Lambda, which is the standard Terraform pattern for S3→Lambda events.