
# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "birthday-app-ecs-task-execution-role"


  assume_role_policy = jsonencode({
    # tfsec:ignore:aws-iam-no-policy-wildcards - Wildcard is scoped appropriately and needed for dynamic log group creation
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Role Policy Attachment for ECS Task Execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "birthday-app-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for DynamoDB access
resource "aws_iam_policy" "dynamodb_access" {
  name        = "birthday-app-dynamodb-access"
  description = "Policy for DynamoDB access from ECS tasks"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:DescribeTable"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.users.arn
      }
    ]
  })
}

# IAM Policy Attachment for CloudWatch Logs Permissions
# tfsec:ignore:aws-iam-no-policy-wildcards - Wildcard is scoped appropriately and needed for dynamic log group creation
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "ecs-task-execution-logs-policy"
  role = aws_iam_role.ecs_task_execution_role.name

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
        Resource = "${aws_cloudwatch_log_group.ecs_birthday_app.arn}*"
      }
    ]
  })
}

# Attach DynamoDB policy to task role
resource "aws_iam_role_policy_attachment" "task_dynamodb" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}
