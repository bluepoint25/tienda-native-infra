resource "aws_dynamodb_table" "productos" {
  name         = "${var.project_name}-productos"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-productos-table"
    Environment = var.environment
  }
}
