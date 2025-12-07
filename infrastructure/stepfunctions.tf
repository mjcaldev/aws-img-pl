data "aws_iam_policy_document" "step_functions_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "step_functions_role" {
  name               = "${var.project_name}-stepfn-role"
  assume_role_policy = data.aws_iam_policy_document.step_functions_assume_role.json
}

data "aws_iam_policy_document" "step_functions_policy" {
  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      aws_lambda_function_resize_image.arn,
      aws_lambda_function_rekognition_labels.arn,
      aws_lambda_function_store_metadata.arn,
    ]
  }
}

resource "aws_iam_policy" "step_functions_policy" {
  name   = "${var.project_name}-stepfn-policy"
  policy = data.aws_iam_policy_document.step_functions_policy.json
}

resource "aws_iam_role_policy_attachment" "stepfn_attach" {
  role       = aws_iam_role_step_functions_role.name
  policy_arn = aws_iam_policy_step_functions_policy.arn
}

locals {
  stepfn_definition = jsonencode({
    Comment = "Image processing pipeline"
    StartAt = "ResizeImage"
    States = {
      "ResizeImage" = {
        Type       = "Task"
        Resource   = aws_lambda_function_resize_image.arn
        Next       = "RekognitionLabels"
      }
      "RekognitionLabels" = {
        Type       = "Task"
        Resource   = aws_lambda_function_rekognition_labels.arn
        Next       = "StoreMetadata"
      }
      "StoreMetadata" = {
        Type       = "Task"
        Resource   = aws_lambda_function_store_metadata.arn
        End        = true
      }
    }
  })
}

resource "aws_sfn_state_machine" "image_pipeline" {
  name         = "${var.project_name}-state-machine"
  role_arn     = aws_iam_role_step_functions_role.arn
  definition   = local.stepfn_definition
}