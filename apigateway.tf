# apigateway.tf - API Gateway resources

# API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name        = var.api_name
  description = "API for EventBridge API Destination"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Method
resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.custom_authorizer.id
}

# API Gateway Integration
resource "aws_api_gateway_integration" "post_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.post_method.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# API Gateway Method Response
resource "aws_api_gateway_method_response" "post_method_response" {
  depends_on  = [aws_api_gateway_model.empty_model]
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.post_method.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty" # Use built-in Empty model
  }
}

# API Gateway Integration Response
resource "aws_api_gateway_integration_response" "post_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.post_method.http_method
  status_code = aws_api_gateway_method_response.post_method_response.status_code
}

# API Gateway Model
resource "aws_api_gateway_model" "empty_model" {
  rest_api_id  = aws_api_gateway_rest_api.api.id
  name         = "EmptyModel" # Changed from "Empty" to avoid conflict
  description  = "Empty Schema"
  content_type = "application/json"

  schema = jsonencode({
    title = "Empty Schema"
    type  = "object"
  })
}

# API Gateway Authorizer
resource "aws_api_gateway_authorizer" "custom_authorizer" {
  name                             = "custom-authorizer"
  rest_api_id                      = aws_api_gateway_rest_api.api.id
  authorizer_uri                   = aws_lambda_function.custom_authorizer_function.invoke_arn
  authorizer_credentials           = aws_iam_role.api_gateway_authorizer_role.arn
  type                             = "REQUEST"
  identity_source                  = "method.request.header.Authorization"
  authorizer_result_ttl_in_seconds = 0
}

# IAM role for API Gateway to invoke Lambda authorizer
resource "aws_iam_role" "api_gateway_authorizer_role" {
  name = "api_gateway_authorizer_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Policy for API Gateway to invoke Lambda
resource "aws_iam_role_policy" "api_gateway_invoke_lambda" {
  name = "api_gateway_invoke_lambda"
  role = aws_iam_role.api_gateway_authorizer_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.custom_authorizer_function.arn
      }
    ]
  })
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.post_integration,
    aws_api_gateway_integration_response.post_integration_response
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = var.api_stage_name

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Account for CloudWatch Logs
resource "aws_api_gateway_account" "api_gateway_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn
}

# IAM Role for API Gateway CloudWatch Logs
resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "api_gateway_cloudwatch_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach CloudWatch Logs policy to the role
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch_logs" {
  role       = aws_iam_role.api_gateway_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# API Gateway Stage Settings for CloudWatch Logs
resource "aws_api_gateway_method_settings" "api_settings" {
  depends_on = [
    aws_api_gateway_account.api_gateway_account,
    aws_iam_role_policy_attachment.api_gateway_cloudwatch_logs
  ]
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_deployment.api_deployment.stage_name
  method_path = "*/*"

  settings {
    data_trace_enabled = true
    logging_level      = "INFO"
    metrics_enabled    = true
  }
}