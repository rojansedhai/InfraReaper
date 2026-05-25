variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for the InfraReaper control plane."
}

variable "name_prefix" {
  type        = string
  default     = "infrareaper"
  description = "Prefix for permanent control-plane resources."
}

variable "lambda_zip_path" {
  type        = string
  description = "Path to the packaged Lambda zip containing lambdas/src and lambdas/resource."
}

variable "terraform_layer_zip_path" {
  type        = string
  description = "Path to a Lambda layer zip containing the Terraform binary at bin/terraform."
}

variable "state_bucket_name" {
  type        = string
  default     = null
  description = "Optional explicit S3 bucket name for ephemeral Terraform state."
}

variable "max_ttl_hours" {
  type        = number
  default     = 24
  description = "Maximum lifetime for requested environments."
}

variable "cors_allow_origin" {
  type        = string
  default     = "*"
  description = "CORS origin for the dashboard."
}

variable "jwt_issuer" {
  type        = string
  default     = null
  description = "OIDC issuer URL for API Gateway JWT authorization. Null disables auth for demos."
}

variable "jwt_audience" {
  type        = list(string)
  default     = []
  description = "Accepted JWT audiences for API Gateway."
}

variable "managed_resource_permissions_boundary_arn" {
  type        = string
  default     = null
  description = "Optional IAM permissions boundary ARN applied to temporary IAM roles."
}

