data "aws_caller_identity" "current" {}

locals {
  safe_suffix = substr(var.name_suffix, 0, 36)
  bucket_name = lower("ir-${var.env_id}-${local.safe_suffix}")
  role_name   = substr("ir-${var.env_id}-${local.safe_suffix}", 0, 64)

  common_tags = merge(
    {
      Project       = "InfraReaper"
      EnvironmentId = var.env_id
      ExpiresAt     = var.expires_at
      ManagedBy     = "Terraform"
      Purpose       = var.purpose
      RequestedBy   = var.requested_by
    },
    var.extra_tags
  )
}

resource "aws_s3_bucket" "temp" {
  count = var.resource_type == "s3_bucket" ? 1 : 0

  bucket        = local.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "temp" {
  count = var.resource_type == "s3_bucket" ? 1 : 0

  bucket                  = aws_s3_bucket.temp[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "temp" {
  count = var.resource_type == "s3_bucket" ? 1 : 0

  bucket = aws_s3_bucket.temp[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "temp" {
  count = var.resource_type == "s3_bucket" ? 1 : 0

  bucket = aws_s3_bucket.temp[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "temp" {
  count = var.resource_type == "s3_bucket" ? 1 : 0

  bucket = aws_s3_bucket.temp[0].id

  rule {
    id     = "backup-expiration"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 1
    }
  }
}

data "aws_iam_policy_document" "temp_role_trust" {
  count = var.resource_type == "iam_role" ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      type        = "AWS"
    }
  }
}

resource "aws_iam_role" "temp" {
  count = var.resource_type == "iam_role" ? 1 : 0

  name                 = local.role_name
  path                 = "/infrareaper/"
  assume_role_policy   = data.aws_iam_policy_document.temp_role_trust[0].json
  description          = "Temporary InfraReaper role ${var.env_id}; expires ${var.expires_at}"
  max_session_duration = 3600
  permissions_boundary = var.managed_resource_permissions_boundary_arn
}

resource "aws_sqs_queue" "temp" {
  count = var.resource_type == "sqs_queue" ? 1 : 0

  name = local.bucket_name
  tags = local.common_tags
}

resource "aws_dynamodb_table" "temp" {
  count = var.resource_type == "dynamodb_table" ? 1 : 0

  name         = local.bucket_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = local.common_tags
}
