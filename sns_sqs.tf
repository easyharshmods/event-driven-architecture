# sns-sqs.tf - SNS and SQS resources

# SNS Topics
resource "aws_sns_topic" "inventory_topic" {
  name = "Inventory"
}

resource "aws_sns_topic" "orders_topic" {
  name = "Orders"
}

# SQS Queues
resource "aws_sqs_queue" "orders_queue" {
  name                      = "Orders"
  message_retention_seconds = var.sqs_message_retention_seconds
}

resource "aws_sqs_queue" "orders_replay_queue" {
  name                      = "OrdersReplayQueue"
  message_retention_seconds = var.sqs_message_retention_seconds
}

# DLQ for Lambda function
resource "aws_sqs_queue" "inventory_function_dlq" {
  name                      = "InventoryFunctionDLQ"
  message_retention_seconds = var.sqs_message_retention_seconds
}

# SNS Topic Subscription
resource "aws_sns_topic_subscription" "orders_queue_subscription" {
  topic_arn = aws_sns_topic.orders_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.orders_queue.arn
}

# SQS Queue Policy
resource "aws_sqs_queue_policy" "orders_queue_policy" {
  queue_url = aws_sqs_queue.orders_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = ["sqs:SendMessage"]
        Resource  = aws_sqs_queue.orders_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.orders_topic.arn
          }
        }
      }
    ]
  })
}