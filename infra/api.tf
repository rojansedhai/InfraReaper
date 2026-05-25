resource "aws_apigatewayv2_api" "this" {
  name          = "${var.name_prefix}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["authorization", "content-type"]
    allow_methods = ["OPTIONS", "POST", "GET"]
    allow_origins = [var.cors_allow_origin]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  count = local.auth_enabled ? 1 : 0

  api_id           = aws_apigatewayv2_api.this.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.name_prefix}-jwt"

  jwt_configuration {
    audience = var.jwt_audience
    issuer   = var.jwt_issuer
  }
}

resource "aws_apigatewayv2_integration" "provisioner" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.provisioner.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "create_environment" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /environments"
  target    = "integrations/${aws_apigatewayv2_integration.provisioner.id}"

  authorization_type = local.auth_enabled ? "JWT" : "NONE"
  authorizer_id      = local.auth_enabled ? aws_apigatewayv2_authorizer.jwt[0].id : null
}

resource "aws_apigatewayv2_route" "get_metrics" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /metrics"
  target    = "integrations/${aws_apigatewayv2_integration.provisioner.id}"

  authorization_type = "NONE"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_api_gateway" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.provisioner.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

