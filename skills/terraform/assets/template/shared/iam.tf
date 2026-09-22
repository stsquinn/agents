# AWS's ReadOnlyAccess can read secret values, which is not what "read only"
# means here. This subtracts that; an explicit Deny beats every Allow.
data "aws_iam_policy_document" "deny_sensitive_reads" {
  statement {
    sid    = "DenySecretAndParameterValues"
    effect = "Deny"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:BatchGetSecretValue",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext",
      "ec2:GetPasswordData",
    ]

    resources = ["*"]
  }

  # Guards against a future trust policy being written too loosely.
  statement {
    sid    = "DenyPrivilegeEscalation"
    effect = "Deny"

    actions = [
      "sts:AssumeRole",
      "sts:AssumeRoleWithWebIdentity",
    ]

    resources = [
      local.apply_role_arn,
      local.plan_role_arn,
    ]
  }

  dynamic "statement" {
    for_each = length(local.readonly_denied_objects) > 0 ? [1] : []

    content {
      sid       = "DenyReadingSensitiveObjects"
      effect    = "Deny"
      actions   = ["s3:GetObject", "s3:GetObjectVersion"]
      resources = local.readonly_denied_objects
    }
  }
}

resource "aws_iam_policy" "deny_sensitive_reads" {
  name        = "__PREFIX__-deny-sensitive-reads"
  description = "Subtracts secret/parameter value reads and role-hopping from ReadOnlyAccess."
  policy      = data.aws_iam_policy_document.deny_sensitive_reads.json
}

# Taking the state lock is a write. Scoping it to *.tflock means a plan can
# lock without being able to overwrite state.
data "aws_iam_policy_document" "state_lock" {
  statement {
    sid       = "ListStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tfstate.arn]
  }

  statement {
    sid       = "ReadState"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]
  }

  statement {
    sid       = "WriteLockfileOnly"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*.tflock"]
  }
}

resource "aws_iam_policy" "state_lock" {
  name        = "__PREFIX__-terraform-state-lock"
  description = "Read Terraform state and take/release the native S3 lock, without write access to state itself."
  policy      = data.aws_iam_policy_document.state_lock.json
}

# --- readonly: engineers and AI agents -------------------------------------

data "aws_iam_policy_document" "readonly_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = local.readonly_trusted_principals
    }
  }
}

# Enough for `terraform plan -lock=false` and console inspection. Not enough to
# change anything, take a lock, or read a credential.
resource "aws_iam_role" "readonly" {
  name                 = local.readonly_role_name
  description          = "Read-only inspection of the AWS account. Used by engineers and AI agents."
  assume_role_policy   = data.aws_iam_policy_document.readonly_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "readonly_aws_managed" {
  role       = aws_iam_role.readonly.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "readonly_guardrail" {
  role       = aws_iam_role.readonly.name
  policy_arn = aws_iam_policy.deny_sensitive_reads.arn
}

# --- CI: assumed via GitHub OIDC, no access keys exist ----------------------

data "aws_iam_policy_document" "github_plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.plan_subjects
    }
  }
}

data "aws_iam_policy_document" "github_apply_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.apply_subjects
    }
  }
}

resource "aws_iam_role" "plan" {
  name                 = local.plan_role_name
  description          = "GitHub Actions role for `terraform plan` on pull requests."
  assume_role_policy   = data.aws_iam_policy_document.github_plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan_aws_managed" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "plan_guardrail" {
  role       = aws_iam_role.plan.name
  policy_arn = aws_iam_policy.deny_sensitive_reads.arn
}

resource "aws_iam_role_policy_attachment" "plan_state_lock" {
  role       = aws_iam_role.plan.name
  policy_arn = aws_iam_policy.state_lock.arn
}

resource "aws_iam_role" "apply" {
  name                 = local.apply_role_name
  description          = "GitHub Actions role for `terraform apply`. Reachable only from main or a protected environment."
  assume_role_policy   = data.aws_iam_policy_document.github_apply_trust.json
  max_session_duration = 3600
}

# TODO(narrow): this repo manages IAM itself and the service set is not yet
# settled. Replace with an explicit policy once envs/ stops growing.
resource "aws_iam_role_policy_attachment" "apply_admin" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
