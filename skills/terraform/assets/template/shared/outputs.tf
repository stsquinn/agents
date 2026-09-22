output "state_bucket" {
  description = "Bucket holding Terraform state for every stack."
  value       = aws_s3_bucket.tfstate.id
}

output "readonly_role_arn" {
  description = "Assume this for read-only inspection. The only role an AI agent should hold."
  value       = aws_iam_role.readonly.arn
}

output "plan_role_arn" {
  description = "Set as the AWS_PLAN_ROLE_ARN repository variable."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "Set as the AWS_APPLY_ROLE_ARN repository variable."
  value       = aws_iam_role.apply.arn
}
