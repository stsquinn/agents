output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IPv4 address."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IPv4 address, from the Elastic IP when one is attached."
  value       = var.assign_eip ? aws_eip.this[0].public_ip : aws_instance.this.public_ip
}

output "security_group_ids" {
  description = "Groups guarding this host, whether this module made one or they were passed in. Reference these instead of hardcoding CIDRs."
  value       = local.security_group_ids
}

output "iam_instance_profile" {
  description = "Instance profile attached to the host, created here or passed in."
  value       = local.iam_instance_profile
}

# Null when manage_iam is off: the role belongs to whoever does own it.
output "iam_role_name" {
  description = "Instance role name, for attaching further policies."
  value       = one(aws_iam_role.this[*].name)
}

output "iam_role_arn" {
  description = "Instance role ARN."
  value       = one(aws_iam_role.this[*].arn)
}
