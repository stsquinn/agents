terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Local state the first time -- this stack creates the bucket. After the
  # first apply, uncomment and run `terraform init -migrate-state`.
  #
  # backend "s3" {
  #   bucket       = "__PREFIX__-tfstate-__ACCOUNT_ID__"
  #   key          = "shared/terraform.tfstate"
  #   region       = "__REGION__"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = local.region

  # Hard guardrail: refuses to run against any other AWS account.
  allowed_account_ids = [local.account_id]

  default_tags {
    tags = {
      ManagedBy  = "terraform"
      Repository = "__GITHUB_ORG__/__GITHUB_REPO__"
      Stack      = "shared"
    }
  }
}
