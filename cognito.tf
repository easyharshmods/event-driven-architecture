# cognito.tf - Cognito User Pool and Identity Pool resources

# Cognito User Pool
resource "aws_cognito_user_pool" "user_pool" {
  name = var.cognito_user_pool_name

  password_policy {
    minimum_length    = var.cognito_password_min_length
    require_lowercase = false
    require_numbers   = true
    require_symbols   = false
    require_uppercase = false
  }
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = "${var.stack_name}-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# Secret for User Credentials
resource "aws_secretsmanager_secret" "user_credentials" {
  name        = "${var.stack_name}-credentials"
  description = "Cognito User Pool credentials"
}

resource "random_password" "password" {
  length           = 12
  special          = false
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret_version" "user_credentials_version" {
  secret_id = aws_secretsmanager_secret.user_credentials.id
  secret_string = jsonencode({
    username = "user",
    password = random_password.password.result
  })
}

# Lambda function to create user
resource "aws_lambda_function" "create_user_function" {
  function_name = "${var.stack_name}-create-user"
  handler       = "index.lambda_handler"
  role          = aws_iam_role.create_user_role.arn
  timeout       = var.lambda_timeout
  runtime       = var.lambda_runtime
  memory_size   = var.lambda_memory_size

  # Use the zip file created in data.tf
  filename         = data.archive_file.create_user_lambda.output_path
  source_code_hash = data.archive_file.create_user_lambda.output_base64sha256

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    null_resource.ensure_files_dir
  ]
}

# IAM role for create_user Lambda function
resource "aws_iam_role" "create_user_role" {
  name = "${var.stack_name}-create-user-role"

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

# IAM policy for create_user Lambda function
resource "aws_iam_role_policy" "create_user_policy" {
  name = "${var.stack_name}-create-user-policy"
  role = aws_iam_role.create_user_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["cognito-idp:AdminConfirmSignUp"]
        Resource = aws_cognito_user_pool.user_pool.arn
      },
      {
        Effect   = "Allow"
        Action   = ["cognito-idp:SignUp"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.user_credentials.arn
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

# Create a null_resource to invoke the Lambda function to create the user
resource "null_resource" "create_user" {
  triggers = {
    user_pool_id = aws_cognito_user_pool.user_pool.id
    client_id    = aws_cognito_user_pool_client.user_pool_client.id
    secret_id    = aws_secretsmanager_secret.user_credentials.id
  }

  provisioner "local-exec" {
    command = <<EOF
aws lambda invoke \
  --region ${local.region} \
  --function-name ${aws_lambda_function.create_user_function.function_name} \
  --payload "$(echo '{"RequestType": "Create", "ResourceProperties": {"UserPoolId": "${aws_cognito_user_pool.user_pool.id}", "ClientId": "${aws_cognito_user_pool_client.user_pool_client.id}", "SecretId": "${aws_secretsmanager_secret.user_credentials.id}"}}' | base64 -w0)" \
  ${path.module}/files/response.json
EOF
  }

  depends_on = [
    aws_lambda_function.create_user_function,
    aws_cognito_user_pool.user_pool,
    aws_cognito_user_pool_client.user_pool_client,
    aws_secretsmanager_secret_version.user_credentials_version
  ]
}

# Cognito Identity Pool
resource "aws_cognito_identity_pool" "identity_pool" {
  identity_pool_name               = var.cognito_identity_pool_name
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.user_pool_client.id
    provider_name           = aws_cognito_user_pool.user_pool.endpoint
    server_side_token_check = false
  }
}

# IAM role for authenticated users
resource "aws_iam_role" "authenticated_role" {
  name = "${var.stack_name}-authenticated-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.identity_pool.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonAPIGatewayInvokeFullAccess"]
}

# Attach roles to Identity Pool
resource "aws_cognito_identity_pool_roles_attachment" "identity_pool_roles" {
  identity_pool_id = aws_cognito_identity_pool.identity_pool.id

  roles = {
    authenticated = aws_iam_role.authenticated_role.arn
  }
}