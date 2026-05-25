output "api_endpoint" {
  value = aws_apigatewayv2_api.this.api_endpoint
}

output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "lock_table" {
  value = aws_dynamodb_table.locks.name
}

output "provisioner_lambda" {
  value = aws_lambda_function.provisioner.function_name
}

output "destroyer_lambda" {
  value = aws_lambda_function.destroyer.function_name
}

output "schedule_group" {
  value = aws_scheduler_schedule_group.destroy.name
}

output "dlq_url" {
  value = aws_sqs_queue.dlq.url
}

