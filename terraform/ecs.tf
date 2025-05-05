# Create an ECR repository for the application
# tfsec:ignore:aws-ecr-repository-customer-key - AWS-managed key is sufficient for our use case
resource "aws_ecr_repository" "app_repo" {
  name                 = "birthday-app-repo"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# tfsec:ignore:aws-cloudwatch-log-group-encrypted - Encryption not required for non-sensitive logs
# tfsec:ignore:aws-cloudwatch-log-group-customer-key - As above
resource "aws_cloudwatch_log_group" "ecs_birthday_app" {
  name              = "/ecs/birthday-app"
  retention_in_days = 7
}

# ALB for ECS service
# tfsec:ignore:aws-elb-alb-not-public - Public-facing ALB is required for external access
resource "aws_lb" "app_lb" {
  name                       = "birthday-app-alb"
  drop_invalid_header_fields = true
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.ecs_sg.id]
  subnets                    = aws_subnet.public[*].id

  tags = {
    Name = "birthday-app-alb"
  }
}

# ALB Target Group
resource "aws_lb_target_group" "app_tg" {
  name        = "birthday-app-tg"
  port        = 4567
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200"
  }
}

# ALB Listener
# tfsec:ignore:aws-elb-http-not-used - Intentional use of HTTP to avoid ACM/Custom Domain
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "app_cluster" {
  name = "birthday-app-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}


# ECS Task Definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = "birthday-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "birthday-app"
      image = "${aws_ecr_repository.app_repo.repository_url}:latest"
      portMappings = [
        {
          containerPort = 4567
          hostPort      = 4567
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DYNAMO_TABLE_NAME"
          value = aws_dynamodb_table.users.name
        },
        {
          name  = "ENVIRONMENT",
          value = "production"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/birthday-app"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "app_service" {
  name            = "birthday-app-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  # Using rolling update deployment strategy
  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "birthday-app"
    container_port   = 4567
  }

  # Configure deployment for zero downtime updates
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  
  # Specify deployment configuration for zero-downtime
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  
  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener.app_listener]
}
