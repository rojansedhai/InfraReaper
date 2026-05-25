data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "provisioner" {
  name               = "${var.name_prefix}-provisioner"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role" "destroyer" {
  name               = "${var.name_prefix}-destroyer"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "provisioner_logs" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.provisioner.name
}

resource "aws_iam_role_policy_attachment" "destroyer_logs" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.destroyer.name
}

data "aws_iam_policy_document" "terraform_backend" {
  statement {
    actions = ["s3:ListBucket"]
    effect  = "Allow"
    resources = [
      aws_s3_bucket.state.arn
    ]
  }

  statement {
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject"
    ]
    effect = "Allow"
    resources = [
      "${aws_s3_bucket.state.arn}/envs/*"
    ]
  }

  statement {
    actions = [
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:PutItem"
    ]
    effect = "Allow"
    resources = [
      aws_dynamodb_table.locks.arn
    ]
  }

  statement {
    actions = [
      "dynamodb:UpdateItem",
      "dynamodb:GetItem"
    ]
    effect = "Allow"
    resources = [
      aws_dynamodb_table.metrics.arn
    ]
  }
}

data "aws_iam_policy_document" "managed_resources" {
  statement {
    actions   = ["sts:GetCallerIdentity"]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:DeleteBucketWebsite",
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketAcl",
      "s3:GetBucketCors",
      "s3:GetBucketLocation",
      "s3:GetBucketLogging",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetBucketPolicy",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketTagging",
      "s3:GetBucketVersioning",
      "s3:GetBucketWebsite",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetBucketOwnershipControls",
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:PutBucketAcl",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketTagging",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:PutBucketOwnershipControls"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::ir-*"
    ]
  }

  statement {
    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:ListMultipartUploadParts"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::ir-*/*"
    ]
  }

  statement {
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRolePolicies",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:iam::${local.account_id}:role/infrareaper/ir-*"
    ]
  }

  statement {
    actions = [
      "sqs:CreateQueue",
      "sqs:DeleteQueue",
      "sqs:GetQueueAttributes",
      "sqs:SetQueueAttributes",
      "sqs:ListQueueTags",
      "sqs:TagQueue",
      "sqs:UntagQueue"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:sqs:*:${local.account_id}:ir-*"
    ]
  }

  statement {
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:DeleteTable",
      "dynamodb:DescribeTable",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:ListTagsOfResource",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
      "dynamodb:UpdateContinuousBackups",
      "dynamodb:UpdateTimeToLive",
      "dynamodb:UpdateTable"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:dynamodb:*:${local.account_id}:table/ir-*"
    ]
  }
}

data "aws_iam_policy_document" "scheduler_management" {
  statement {
    actions = [
      "scheduler:CreateSchedule",
      "scheduler:DeleteSchedule",
      "scheduler:GetSchedule"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:scheduler:${var.aws_region}:${local.account_id}:schedule/${aws_scheduler_schedule_group.destroy.name}/destroy-env-*"
    ]
  }

  statement {
    actions = ["iam:PassRole"]
    effect  = "Allow"
    resources = [
      aws_iam_role.scheduler_invoke_destroyer.arn
    ]

    condition {
      test     = "StringEquals"
      values   = ["scheduler.amazonaws.com"]
      variable = "iam:PassedToService"
    }
  }
}

resource "aws_iam_policy" "terraform_backend" {
  name   = "${var.name_prefix}-terraform-backend"
  policy = data.aws_iam_policy_document.terraform_backend.json
}

resource "aws_iam_policy" "managed_resources" {
  name   = "${var.name_prefix}-managed-resources"
  policy = data.aws_iam_policy_document.managed_resources.json
}

resource "aws_iam_policy" "scheduler_management" {
  name   = "${var.name_prefix}-scheduler-management"
  policy = data.aws_iam_policy_document.scheduler_management.json
}

resource "aws_iam_role_policy_attachment" "provisioner_backend" {
  policy_arn = aws_iam_policy.terraform_backend.arn
  role       = aws_iam_role.provisioner.name
}

resource "aws_iam_role_policy_attachment" "destroyer_backend" {
  policy_arn = aws_iam_policy.terraform_backend.arn
  role       = aws_iam_role.destroyer.name
}

resource "aws_iam_role_policy_attachment" "provisioner_resources" {
  policy_arn = aws_iam_policy.managed_resources.arn
  role       = aws_iam_role.provisioner.name
}

resource "aws_iam_role_policy_attachment" "destroyer_resources" {
  policy_arn = aws_iam_policy.managed_resources.arn
  role       = aws_iam_role.destroyer.name
}

resource "aws_iam_role_policy_attachment" "provisioner_scheduler" {
  policy_arn = aws_iam_policy.scheduler_management.arn
  role       = aws_iam_role.provisioner.name
}

data "aws_iam_policy_document" "scheduler_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["scheduler.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "scheduler_invoke_destroyer" {
  name               = "${var.name_prefix}-scheduler-invoke-destroyer"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume_role.json
}

data "aws_iam_policy_document" "scheduler_invoke_destroyer" {
  statement {
    actions = ["lambda:InvokeFunction"]
    effect  = "Allow"
    resources = [
      aws_lambda_function.destroyer.arn
    ]
  }

  statement {
    actions = ["sqs:SendMessage"]
    effect  = "Allow"
    resources = [
      aws_sqs_queue.dlq.arn
    ]
  }
}

resource "aws_iam_role_policy" "scheduler_invoke_destroyer" {
  name   = "${var.name_prefix}-invoke-destroyer"
  role   = aws_iam_role.scheduler_invoke_destroyer.id
  policy = data.aws_iam_policy_document.scheduler_invoke_destroyer.json
}

