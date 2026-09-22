locals {
  tags = merge(var.tags, var.add_name_tag ? tomap({ Name = var.bucket }) : tomap({}))

  has_lifecycle = var.noncurrent_version_expiration_days != null || var.expiration_days != null

  # Not coalesce: it unifies types through string, so a literal false would not
  # survive the round trip.
  bucket_key = var.bucket_key_enabled != null ? var.bucket_key_enabled : var.sse_algorithm == "aws:kms"
}

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket
  force_destroy = var.force_destroy

  tags = local.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  count = var.manage_versioning ? 1 : 0

  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = var.sse_algorithm == "aws:kms" ? var.kms_key_arn : null
    }

    bucket_key_enabled = local.bucket_key
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = local.has_lifecycle ? 1 : 0

  bucket = aws_s3_bucket.this.id

  rule {
    id     = "retention"
    status = "Enabled"

    filter {}

    dynamic "noncurrent_version_expiration" {
      for_each = var.noncurrent_version_expiration_days != null ? [1] : []

      content {
        noncurrent_days = var.noncurrent_version_expiration_days
      }
    }

    dynamic "expiration" {
      for_each = var.expiration_days != null ? [1] : []

      content {
        days = var.expiration_days
      }
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_cors_configuration" "this" {
  count = length(var.cors_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "cors_rule" {
    for_each = var.cors_rules

    content {
      id              = cors_rule.key
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      allowed_headers = cors_rule.value.allowed_headers
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

data "aws_iam_policy_document" "this" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  count = var.manage_bucket_policy ? 1 : 0

  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.this.json

  depends_on = [aws_s3_bucket_public_access_block.this]
}
