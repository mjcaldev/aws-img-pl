data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name               = "${var.project_name}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_exec_policy" {
  statement {
    sid    = "AllowWriteLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/*"]
  }

  statement {
    sid    = "AllowS3ReadWrite"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.uploads.arn,
      "${aws_s3_bucket.uploads.arn}/*",
    ]
  }

  statement {
    sid    = "AllowDynamoDB"
    effect = "Allow"

    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:GetItem",
    ]

    resources = [aws_dynamodb_table.image_metadata.arn]
  }

  statement {
    sid    = "AllowRekognition"
    effect = "Allow"

    actions = [
      "rekognition:DetectLabels"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowStepFunctions"
    effect = "Allow"

    actions = [
      "states:StartExecution"
    ]

    resources = ["*"] # tighten later to your state machine ARN
  }
}

resource "aws_iam_policy" "lambda_exec_policy" {
  name   = "${var.project_name}-lambda-exec-policy"
  policy = data.aws_iam_policy_document.lambda_exec_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_exec_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_exec_policy.arn
}