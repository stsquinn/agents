# No resources yet. When adopting live infrastructure, uncomment a module
# block only together with its `import` blocks, so the first plan reads "0 to add".

locals {
  env        = "prod"
  account_id = "__ACCOUNT_ID__"
  region     = "__REGION__"

  # Reserved, unclaimed until the network module is wired. Recorded so stg and
  # prod never overlap if they are later peered.
  vpc_cidr = "10.20.0.0/16"

  public_subnets = {
    "__REGION__a" = "10.20.0.0/20"
    "__REGION__b" = "10.20.16.0/20"
    "__REGION__c" = "10.20.32.0/20"
  }

  private_subnets = {
    "__REGION__a" = "10.20.128.0/20"
    "__REGION__b" = "10.20.144.0/20"
    "__REGION__c" = "10.20.160.0/20"
  }
}

# --- Networking ------------------------------------------------------------
#
# module "network" {
#   source = "../../modules/network"
#
#   name            = "__PREFIX__-${local.env}"
#   cidr_block      = local.vpc_cidr
#   public_subnets  = local.public_subnets
#   private_subnets = local.private_subnets
#
#   # One NAT per AZ -- a single NAT makes its AZ a shared failure domain.
#   enable_nat_gateway = true
#   single_nat_gateway = false
# }

# --- Compute ---------------------------------------------------------------
#
# One block per host. Name each after what it runs, so the host-to-workload
# mapping stays obvious.
#
# module "mobile_api" {
#   source = "../../modules/ec2-app-host"
#
#   name          = "__PREFIX__-${local.env}-mobile-api"
#   vpc_id        = module.network.vpc_id
#   subnet_id     = module.network.public_subnet_ids["__REGION__a"]
#   instance_type = "t3.medium"
#   assign_eip    = true
#
#   ingress_rules = {
#     https = {
#       description = "HTTPS from the internet"
#       from_port   = 443
#       to_port     = 443
#       cidr_ipv4   = "0.0.0.0/0"
#     }
#   }
# }

# --- Data ------------------------------------------------------------------
#
# module "mysql" {
#   source = "../../modules/rds-mysql"
#
#   identifier     = "__PREFIX__-${local.env}-mysql"
#   vpc_id         = module.network.vpc_id
#   subnet_ids     = module.network.private_subnet_id_list
#   instance_class = "db.t4g.large"
#   db_name        = "app_prod"
#
#   multi_az                = true
#   backup_retention_period = 14
#   deletion_protection     = true
#
#   allowed_security_group_ids = {
#     mobile_api = module.mobile_api.security_group_id
#   }
# }

# --- Storage ---------------------------------------------------------------
#
# module "uploads" {
#   source = "../../modules/s3-bucket"
#
#   bucket = "__PREFIX__-${local.env}-uploads"
# }
