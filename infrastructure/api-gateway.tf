resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  # ADDED: CORS configuration (FIXES browser preflight failure)
  cors_configuration {
    allow_origins = ["http://localhost:5173"]
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["content-type"]
  }
}

resource "aws_apigatewayv2_integration" "presigned_url_integration" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.get_presigned_url.invoke_arn
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

resource "aws_apigatewayv2_integration" "get_results_integration" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.get_results.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "get_results_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /results"
  target    = "integrations/${aws_apigatewayv2_integration.get_results_integration.id}"
}

resource "aws_lambda_permission" "api_invoke_get_results" {
  statement_id  = "AllowAPIGatewayInvokeGetResults"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_results.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}