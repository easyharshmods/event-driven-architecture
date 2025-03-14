# outputs.tf - Consolidated outputs

output "wild_rydes_saas_playground_configuration_url" {
  description = "Wild Rydes Saas Playground configuration link"
  value       = "http://saas.wildrydes.com/#/?userPoolId=${aws_cognito_user_pool.user_pool.id}&appClientId=${aws_cognito_user_pool_client.user_pool_client.id}&cognitoIdentityPoolId=${aws_cognito_identity_pool.identity_pool.id}"
}

output "cognito_username" {
  description = "Cognito username for use with Wild Rydes SaaS Playground"
  value       = local.user_credentials.username
  sensitive   = true
}

output "cognito_password" {
  description = "Cognito password for use with Wild Rydes SaaS Playground"
  value       = local.user_credentials.password
  sensitive   = true
}

output "api_url" {
  description = "API Gateway endpoint URL"
  value       = aws_api_gateway_deployment.api_deployment.invoke_url
}

output "inventory_function_name" {
  description = "Name of the Inventory Lambda function"
  value       = aws_lambda_function.inventory_function.function_name
}

output "dodgy_function_name" {
  description = "Name of the Dodgy Lambda function"
  value       = aws_lambda_function.dodgy_function.function_name
}

output "orders_state_machine_arn" {
  description = "ARN of the Orders State Machine"
  value       = aws_sfn_state_machine.orders_state_machine.arn
}

output "inventory_event_bus_name" {
  description = "Name of the Inventory Event Bus"
  value       = aws_cloudwatch_event_bus.inventory_event_bus.name
}

output "orders_queue_url" {
  description = "URL of the Orders SQS Queue"
  value       = aws_sqs_queue.orders_queue.url
}

output "inventory_topic_arn" {
  description = "ARN of the Inventory SNS Topic"
  value       = aws_sns_topic.inventory_topic.arn
}