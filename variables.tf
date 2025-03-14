# variables.tf - Consolidated variables

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-1" # Change this to your preferred region
}

variable "stack_name" {
  description = "Name of the stack"
  type        = string
  default     = "event-driven-architecture-workshop"
}

# Cognito variables
variable "cognito_user_pool_name" {
  description = "Name of the Cognito user pool"
  type        = string
  default     = "event-driven-architecture-user-pool"
}

variable "cognito_password_min_length" {
  description = "Minimum length for Cognito user passwords"
  type        = number
  default     = 6
}

variable "cognito_identity_pool_name" {
  description = "Name of the Cognito identity pool"
  type        = string
  default     = "event-driven-architecture-playground"
}

# Lambda variables
variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
  default     = "python3.9"
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda functions"
  type        = number
  default     = 256
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions (in seconds)"
  type        = number
  default     = 30
}

# SQS variables
variable "sqs_message_retention_seconds" {
  description = "Message retention period in seconds for SQS queues"
  type        = number
  default     = 259200 # 3 days
}

# API Gateway variables
variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
  default     = "eventbridge-api-destination"
}

variable "api_stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = "Prod"
}

# Auth variables
variable "api_auth_username" {
  description = "Username for the API Gateway custom authorizer"
  type        = string
  default     = "myUsername"
}

variable "api_auth_password" {
  description = "Password for the API Gateway custom authorizer"
  type        = string
  default     = "myPassword"
  sensitive   = true
}