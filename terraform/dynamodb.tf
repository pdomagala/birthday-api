resource "aws_dynamodb_table" "users" {
  name           = var.dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "username"

  attribute {
    name = "username"
    type = "S"
  }

  tags = {
    Name        = "sinatra-api-${var.environment}"
    Environment = var.environment
  }
}
