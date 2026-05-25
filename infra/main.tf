data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id       = data.aws_caller_identity.current.account_id
  auth_enabled     = var.jwt_issuer != null && length(var.jwt_audience) > 0
  state_bucket     = coalesce(var.state_bucket_name, "ir-state-${local.account_id}-${var.aws_region}")
  schedule_group   = "${var.name_prefix}-destroy"
  provisioner_name = "${var.name_prefix}-provisioner"
  destroyer_name   = "${var.name_prefix}-destroyer"
}

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "locks" {
  name         = "${var.name_prefix}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_dynamodb_table" "metrics" {
  name         = "${var.name_prefix}-metrics"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"

  attribute {
    name = "PK"
    type = "S"
  }
}

resource "aws_scheduler_schedule_group" "destroy" {
  name = local.schedule_group
}

resource "aws_sqs_queue" "dlq" {
  name = "${var.name_prefix}-dlq"
}

resource "aws_lambda_layer_version" "terraform" {
  filename            = var.terraform_layer_zip_path
  layer_name          = "${var.name_prefix}-terraform"
  compatible_runtimes = ["nodejs20.x", "nodejs22.x"]
  source_code_hash    = filebase64sha256(var.terraform_layer_zip_path)
}

resource "aws_lambda_function" "provisioner" {
  function_name    = local.provisioner_name
  filename         = var.lambda_zip_path
  handler          = "src/provisioner.handler"
  role             = aws_iam_role.provisioner.arn
  runtime          = "nodejs20.x"
  layers           = [aws_lambda_layer_version.terraform.arn]
  memory_size      = 1024
  timeout          = 900
  source_code_hash = filebase64sha256(var.lambda_zip_path)

  ephemeral_storage {
    size = 2048
  }

  environment {
    variables = merge(
      {
        CORS_ALLOW_ORIGIN  = var.cors_allow_origin
        DESTROY_LAMBDA_ARN = aws_lambda_function.destroyer.arn
        DLQ_ARN            = aws_sqs_queue.dlq.arn
        LOCK_TABLE         = aws_dynamodb_table.locks.name
        METRICS_TABLE      = aws_dynamodb_table.metrics.name
        MAX_TTL_HOURS      = tostring(var.max_ttl_hours)
        RESOURCE_DIR       = "/var/task/resource"
        SCHEDULE_GROUP     = aws_scheduler_schedule_group.destroy.name
        SCHEDULER_ROLE_ARN = aws_iam_role.scheduler_invoke_destroyer.arn
        STATE_BUCKET       = aws_s3_bucket.state.bucket
        TERRAFORM_BIN      = "/opt/bin/terraform"
      },
      var.managed_resource_permissions_boundary_arn == null ? {} : {
        TF_VAR_managed_resource_permissions_boundary_arn = var.managed_resource_permissions_boundary_arn
      }
    )
  }
}

resource "aws_lambda_function" "destroyer" {
  function_name    = local.destroyer_name
  filename         = var.lambda_zip_path
  handler          = "src/destroyer.handler"
  role             = aws_iam_role.destroyer.arn
  runtime          = "nodejs20.x"
  layers           = [aws_lambda_layer_version.terraform.arn]
  memory_size      = 1024
  timeout          = 900
  source_code_hash = filebase64sha256(var.lambda_zip_path)

  ephemeral_storage {
    size = 2048
  }

  environment {
    variables = merge(
      {
        LOCK_TABLE     = aws_dynamodb_table.locks.name
        RESOURCE_DIR   = "/var/task/resource"
        SCHEDULE_GROUP = aws_scheduler_schedule_group.destroy.name
        STATE_BUCKET   = aws_s3_bucket.state.bucket
        TERRAFORM_BIN  = "/opt/bin/terraform"
      },
      var.managed_resource_permissions_boundary_arn == null ? {} : {
        TF_VAR_managed_resource_permissions_boundary_arn = var.managed_resource_permissions_boundary_arn
      }
    )
  }
}

resource "aws_cloudwatch_log_group" "provisioner" {
  name              = "/aws/lambda/${aws_lambda_function.provisioner.function_name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "destroyer" {
  name              = "/aws/lambda/${aws_lambda_function.destroyer.function_name}"
  retention_in_days = 30
}
