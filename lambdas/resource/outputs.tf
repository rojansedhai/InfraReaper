output "environment_id" {
  value = var.env_id
}

output "resource_type" {
  value = var.resource_type
}

output "s3_bucket_name" {
  value = try(aws_s3_bucket.temp[0].bucket, null)
}

output "iam_role_arn" {
  value = try(aws_iam_role.temp[0].arn, null)
}

output "expires_at" {
  value = var.expires_at
}

output "sqs_queue_url" {
  value = try(aws_sqs_queue.temp[0].url, null)
}

output "dynamodb_table_name" {
  value = try(aws_dynamodb_table.temp[0].name, null)
}
