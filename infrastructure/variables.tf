variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Base name for all resources"
  type        = string
  default     = "smart-image-pipeline"
}

variable "uploads_bucket_name" {
  description = "S3 bucket for original image uploads"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table for image metadata"
  type        = string
  default     = "image-metadata"
}
