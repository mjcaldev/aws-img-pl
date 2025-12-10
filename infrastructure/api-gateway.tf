resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "presigned_url_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.get_presigned_url.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "presigned_url_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /upload-url"
  target    = "integrations/${aws_apigatewayv2_integration.presigned_url_integration.id}"
}

resource "aws_lambda_permission" "api_invoke_presigned_url" {
  statement_id  = "AllowAPIGatewayInvokePresigned"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_presigned_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}