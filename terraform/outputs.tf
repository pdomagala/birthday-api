# Output the ALB DNS name
output "alb_dns_name" {
  value = aws_lb.app_lb.dns_name
}

# Output the DynamoDB table name
output "dynamodb_table_name" {
  value = aws_dynamodb_table.users.name
}

# Output the ECR repository URL
output "ecr_repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}
