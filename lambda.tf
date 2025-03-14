# lambda.tf - Lambda resources

# InventoryFunction Lambda
resource "aws_lambda_function" "inventory_function" {
  function_name = "InventoryFunction"
  handler       = "index.lambda_handler"
  runtime       = var.lambda_runtime
  role          = aws_iam_role.inventory_function_role.arn
  timeout       = var.lambda_timeout

  # Use the zip file created in data.tf
  filename         = data.archive_file.inventory_lambda_zip.output_path
  source_code_hash = data.archive_file.inventory_lambda_zip.output_base64sha256

  depends_on = [
    null_resource.ensure_files_dir
  ]
}

# IAM Role for the Inventory Lambda function
resource "aws_iam_role" "inventory_function_role" {
  name = "inventory_function_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for the Inventory Lambda function
resource "aws_iam_role_policy" "inventory_function_policy" {
  name = "inventory_function_policy"
  role = aws_iam_role.inventory_function_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["events:PutEvents"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda Event Invoke Configuration for Inventory function
resource "aws_lambda_function_event_invoke_config" "inventory_function_invoke_config" {
  function_name                = aws_lambda_function.inventory_function.function_name
  qualifier                    = "$LATEST"
  maximum_retry_attempts       = 0
  maximum_event_age_in_seconds = 21600
}

# DodgyFunction Lambda
resource "aws_lambda_function" "dodgy_function" {
  function_name = "DodgyFunction"
  handler       = "index.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = 10
  role          = aws_iam_role.dodgy_function_role.arn

  # Use the zip file created in data.tf
  filename         = data.archive_file.dodgy_lambda_zip.output_path
  source_code_hash = data.archive_file.dodgy_lambda_zip.output_base64sha256

  depends_on = [
    null_resource.ensure_files_dir
  ]
}

# IAM Role for the Dodgy Lambda function
resource "aws_iam_role" "dodgy_function_role" {
  name = "dodgy_function_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for CloudWatch Logs for Dodgy function
resource "aws_iam_role_policy" "dodgy_function_logs_policy" {
  name = "dodgy_function_logs_policy"
  role = aws_iam_role.dodgy_function_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Custom Authorizer Lambda Function
resource "aws_lambda_function" "custom_authorizer_function" {
  function_name = "CustomAuthorizerFunction"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  memory_size   = var.lambda_memory_size
  timeout       = 5
  role          = aws_iam_role.custom_authorizer_role.arn

  # Use the zip file created in data.tf
  filename         = data.archive_file.authorizer_lambda_zip.output_path
  source_code_hash = data.archive_file.authorizer_lambda_zip.output_base64sha256

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    null_resource.ensure_files_dir
  ]
}

# IAM role for Lambda authorizer
resource "aws_iam_role" "custom_authorizer_role" {
  name = "custom_authorizer_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Basic Lambda execution policy for authorizer
resource "aws_iam_role_policy" "lambda_authorizer_execution" {
  name = "lambda_authorizer_execution"
  role = aws_iam_role.custom_authorizer_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda permission for API Gateway to invoke the authorizer
resource "aws_lambda_permission" "custom_authorizer_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.custom_authorizer_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/authorizers/*"
}