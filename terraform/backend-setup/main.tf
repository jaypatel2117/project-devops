# Run this ONCE before anything else to bootstrap remote state.
# cd terraform/backend-setup && terraform init && terraform apply

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "tfstate" {
  bucket        = "retail-tfstate-${var.aws_account_id}"
  force_destroy = false

  tags = { Name = "Terraform State Bucket", ManagedBy = "Terraform" }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tflock" {
  name         = "retail-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = { Name = "Terraform State Lock", ManagedBy = "Terraform" }
}

variable "aws_region"     { default = "ca-central-1" }
variable "aws_account_id" { type = string }

output "s3_bucket"        { value = aws_s3_bucket.tfstate.bucket }
output "dynamodb_table"   { value = aws_dynamodb_table.tflock.name }
