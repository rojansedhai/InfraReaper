variable "aws_region" {
  type = string
}

variable "env_id" {
  type = string

  validation {
    condition     = can(regex("^env-[a-f0-9]{12}$", var.env_id))
    error_message = "env_id must look like env- followed by 12 lowercase hex characters."
  }
}

variable "resource_type" {
  type = string

  validation {
    condition     = contains(["s3_bucket", "iam_role", "sqs_queue", "dynamodb_table"], var.resource_type)
    error_message = "resource_type must be s3_bucket, iam_role, sqs_queue, or dynamodb_table."
  }
}

variable "requested_by" {
  type = string
}

variable "purpose" {
  type = string
}

variable "expires_at" {
  type = string
}

variable "name_suffix" {
  type = string
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}

variable "managed_resource_permissions_boundary_arn" {
  type    = string
  default = null
}

