output "bucket" {
  description = "Bucket name."
  value       = aws_s3_bucket.this.id
}

output "arn" {
  description = "Bucket ARN."
  value       = aws_s3_bucket.this.arn
}

output "regional_domain_name" {
  description = "Region-specific domain name, for building object URLs."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
