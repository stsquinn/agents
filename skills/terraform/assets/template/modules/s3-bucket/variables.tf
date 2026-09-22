variable "bucket" {
  description = "Bucket name. Globally unique across all of AWS."
  type        = string
}

variable "versioning_enabled" {
  description = "Keep previous object versions."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow `terraform destroy` to empty a non-empty bucket. Never true for anything holding real data."
  type        = bool
  default     = false
}

variable "sse_algorithm" {
  description = "Server-side encryption: \"AES256\" for S3-managed keys, \"aws:kms\" for a CMK."
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "aws:kms"], var.sse_algorithm)
    error_message = "sse_algorithm must be AES256 or aws:kms."
  }
}

variable "kms_key_arn" {
  description = "CMK ARN, required when sse_algorithm is aws:kms."
  type        = string
  default     = null
}

variable "noncurrent_version_expiration_days" {
  description = "Delete non-current versions after this many days. Null keeps them forever."
  type        = number
  default     = 90
}

variable "expiration_days" {
  description = "Delete current objects after this many days. Null keeps them forever."
  type        = number
  default     = null
}

variable "cors_rules" {
  description = "CORS rules, keyed by a stable name. Needed for browser uploads straight to S3."
  type = map(object({
    allowed_methods = list(string)
    allowed_origins = list(string)
    allowed_headers = optional(list(string), ["*"])
    expose_headers  = optional(list(string), [])
    max_age_seconds = optional(number, 3000)
  }))
  default = {}
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}

# --- adoption ---------------------------------------------------------------
#
# Only for taking over a bucket that already exists. A new bucket should leave
# all four alone and get the full baseline.

variable "bucket_key_enabled" {
  description = "S3 Bucket Keys. Null follows sse_algorithm -- on for KMS, off for AES256. Set it explicitly to match a bucket that already has them."
  type        = bool
  default     = null
}

variable "manage_versioning" {
  description = "Manage the versioning configuration. Off for a bucket that has never had versioning, where writing even Suspended is a change."
  type        = bool
  default     = true
}

variable "manage_bucket_policy" {
  description = "Own the bucket policy, which means replacing whatever is there with DenyInsecureTransport. Off for a bucket whose policy grants something real, such as CloudFront OAC."
  type        = bool
  default     = true
}

variable "add_name_tag" {
  description = "Tag the bucket Name=<bucket>. Off while adopting an untagged bucket."
  type        = bool
  default     = true
}
