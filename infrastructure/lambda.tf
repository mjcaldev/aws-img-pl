locals {
  lambda_runtime = "python3.11"
  lambda_arch    = "arm64"
}

resource "aws_lambda_function" "trigger_step_function" {
  function_name = "${var.project_name}-trigger-step-fn"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "handler.lambda_handler"
  runtime       = local.lambda_runtime
  architectures = [local.lambda_arch]

  filename         = "../lambdas/trigger_step_function/build.zip"
  source_code_hash = filebase64sha256("../lambdas/trigger_step_function/build.zip")

   environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.image_pipeline.arn
    }
  }
}

resource "aws_lambda_function" "resize_image" {
  function_name = "${var.project_name}-resize-image"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "handler.lambda_handler"
  runtime       = local.lambda_runtime
  architectures = [local.lambda_arch]

  filename         = "../lambdas/resize_image/build.zip"
  source_code_hash = filebase64sha256("../lambdas/resize_image/build.zip")
}

resource "aws_lambda_function" "rekognition_labels" {
  function_name = "${var.project_name}-rekognition-labels"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "handler.lambda_handler"
  runtime       = local.lambda_runtime
  architectures = [local.lambda_arch]

  filename         = "../lambdas/rekognition_labels/build.zip"
  source_code_hash = filebase64sha256("../lambdas/rekognition_labels/build.zip")
}

resource "aws_lambda_function" "store_metadata" {
  function_name = "${var.project_name}-store-metadata"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "handler.lambda_handler"
  runtime       = local.lambda_runtime
  architectures = [local.lambda_arch]

  filename         = "../lambdas/store_metadata/build.zip"
  source_code_hash = filebase64sha256("../lambdas/store_metadata/build.zip")
}

resource "aws_lambda_function" "get_presigned_url" {
  function_name = "${var.project_name}-get-presigned-url"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "handler.lambda_handler"
  runtime       = local.lambda_runtime
  architectures = [local.lambda_arch]

  filename         = "../lambdas/get_presigned_url/build.zip"
  source_code_hash = filebase64sha256("../lambdas/get_presigned_url/build.zip")

  environment {
    variables = {
      UPLOAD_BUCKET = aws_s3_bucket.uploads.bucket
    }
  }
}
