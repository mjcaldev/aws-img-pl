resource "aws_lambda_function" "get_presigned_url" {
  function_name = "${var.project_name}-get-presigned-url"
  role          = aws_iam_role_lambda_exec_role.arn
  handler       = "handler.lambda_handler"
  runtime       = local.lambda_runtime
  architectures = [local.lambda_arch]

  filename         = "../lambdas/get_presigned_url/build.zip"
  source_code_hash = filebase64sha256("../lambdas/get_presigned_url/build.zip")
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "presigned_url_integration" {
  api_id           = aws_apigatewayv2_api_http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function_get_presigned_url.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "presigned_url_route" {
  api_id    = aws_apigatewayv2_api_http_api.id
  route_key = "POST /upload-url"
  target    = "integrations/${aws_apigatewayv2_integration_presigned_url_integration.id}"
}

resource "aws_lambda_permission" "api_invoke_presigned_url" {
  statement_id  = "AllowAPIGatewayInvokePresigned"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function_get_presigned_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api_http_api.execution_arn}/*/*"
}