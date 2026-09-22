output "endpoint" {
  description = "Connection endpoint, host:port."
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Hostname of the instance."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Listening port."
  value       = aws_db_instance.this.port
}

output "security_group_ids" {
  description = "Security groups guarding the database, whether this module made them or they were passed in."
  value       = local.security_group_ids
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN holding the RDS-managed master password. Read it with the AWS CLI; the value is not in Terraform state."
  value       = try(aws_db_instance.this.master_user_secret[0].secret_arn, null)
}
