# Everything account-wide and applied once: the state bucket every stack keeps
# its state in, and the IAM roles CI and engineers assume. IAM is global and
# both environments share one account, so it cannot live under envs/.

locals {
  account_id  = "__ACCOUNT_ID__"
  region      = "__REGION__"
  bucket_name = "__PREFIX__-tfstate-__ACCOUNT_ID__"

  github_org  = "__GITHUB_ORG__"
  github_repo = "__GITHUB_REPO__"

  readonly_role_name = "__PREFIX__-terraform-readonly"
  plan_role_name     = "__PREFIX__-terraform-plan"
  apply_role_name    = "__PREFIX__-terraform-apply"

  apply_role_arn = "arn:aws:iam::${local.account_id}:role/${local.apply_role_name}"
  plan_role_arn  = "arn:aws:iam::${local.account_id}:role/${local.plan_role_name}"

  # TODO: narrow to specific user/role ARNs once the IAM users are known.
  readonly_trusted_principals = [
    "arn:aws:iam::${local.account_id}:root",
  ]

  # Object ARNs the readonly role must never read, on top of the deny policy.
  # Add the bucket holding the production RDS dump once its name is confirmed.
  readonly_denied_objects = []

  # A fork, a feature branch or a replayed old workflow matches none of these.
  apply_subjects = [
    "repo:${local.github_org}/${local.github_repo}:ref:refs/heads/main",
    "repo:${local.github_org}/${local.github_repo}:environment:stg",
    "repo:${local.github_org}/${local.github_repo}:environment:prod",
  ]

  plan_subjects = [
    "repo:${local.github_org}/${local.github_repo}:*",
  ]
}

# If this already exists in the account, import it before applying:
#   terraform import aws_iam_openid_connect_provider.github \
#     arn:aws:iam::__ACCOUNT_ID__:oidc-provider/token.actions.githubusercontent.com
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # No longer verified by AWS for this issuer, kept so the trust is explicit.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
