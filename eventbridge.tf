# eventbridge.tf - EventBridge and Event-related resources

# EventBus for Inventory
resource "aws_cloudwatch_event_bus" "inventory_event_bus" {
  name = "Inventory"
}

# Log Group for Inventory
resource "aws_cloudwatch_log_group" "inventory_log_group" {
  name              = "/aws/events/inventory"
  retention_in_days = 3
}

# EventBridge Rule for Inventory
resource "aws_cloudwatch_event_rule" "inventory_dev_rule" {
  name           = "InventoryDevRule"
  event_bus_name = aws_cloudwatch_event_bus.inventory_event_bus.name
  event_pattern = jsonencode({
    account = [local.account_id]
  })
}

# Target for the EventBridge Rule
resource "aws_cloudwatch_event_target" "inventory_logs_target" {
  rule           = aws_cloudwatch_event_rule.inventory_dev_rule.name
  event_bus_name = aws_cloudwatch_event_bus.inventory_event_bus.name
  target_id      = "InventoryLogs"
  arn            = aws_cloudwatch_log_group.inventory_log_group.arn
}

# CloudWatch Logs Resource Policy
resource "aws_cloudwatch_log_resource_policy" "cw_logs_resource_policy" {
  policy_name = "EventBridgeToCWLogs"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EventBridgetoCWLogsPolicy"
        Effect = "Allow"
        Principal = {
          Service = [
            "delivery.logs.amazonaws.com",
            "events.amazonaws.com"
          ]
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [aws_cloudwatch_log_group.inventory_log_group.arn]
      }
    ]
  })
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "orders_state_machine" {
  name     = "OrderProcessing"
  role_arn = aws_iam_role.step_functions_service_role.arn

  definition = jsonencode({
    Comment = "Processes an Order received from the EventBridge Subscription"
    StartAt = "ProcessOrder"
    States = {
      ProcessOrder = {
        Type = "Pass"
        Next = "PublishOrderProcessedEvent"
      }
      PublishOrderProcessedEvent = {
        Type     = "Task"
        Resource = "arn:aws:states:::events:putEvents"
        Parameters = {
          Entries = [
            {
              Detail = {
                OrderId          = "new_id"
                "OrderDetails.$" = "$.detail"
              }
              DetailType   = "Order Processed"
              EventBusName = "Orders"
              Source       = "com.aws.orders"
            }
          ]
        }
        End = true
      }
    }
  })
}

# IAM Role for Step Functions
resource "aws_iam_role" "step_functions_service_role" {
  name = "step_functions_service_role"

  managed_policy_arns = ["arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess"]

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.${local.region}.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# EventBridge Policy for Step Functions
resource "aws_iam_role_policy" "event_bridge_service_integration" {
  name = "EventBridgeServiceIntegration"
  role = aws_iam_role.step_functions_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["events:PutEvents"]
        Resource = "*"
      }
    ]
  })
}