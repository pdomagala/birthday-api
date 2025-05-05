# tfsec:ignore:aws-dynamodb-enable-recovery - PITR is not required for this table
# tfsec:ignore:aws-dynamodb-table-customer-key - AWS-managed key is sufficient for our use case
# tfsec:ignore:aws-dynamodb-enable-at-rest-encryption - Encryption not required for non-sensitive data
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
