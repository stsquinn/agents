# Same account as prod, so allowed_account_ids cannot tell the two apart --
# every resource here must carry the environment in its name.
#
# No resources yet. Wire the first module here before touching prod.

locals {
  env        = "stg"
  account_id = "__ACCOUNT_ID__"
  region     = "__REGION__"

  vpc_cidr = "10.30.0.0/16"

  public_subnets = {
    "__REGION__a" = "10.30.0.0/20"
    "__REGION__b" = "10.30.16.0/20"
  }

  private_subnets = {
    "__REGION__a" = "10.30.128.0/20"
    "__REGION__b" = "10.30.144.0/20"
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
#   # Staging can tolerate losing an AZ; a second NAT is pure hourly cost.
#   enable_nat_gateway = true
#   single_nat_gateway = true
# }

# --- Compute ---------------------------------------------------------------
#
# module "webapp" {
#   source = "../../modules/ec2-app-host"
#
#   name          = "__PREFIX__-${local.env}-webapp"
#   vpc_id        = module.network.vpc_id
#   subnet_id     = module.network.public_subnet_ids["__REGION__a"]
#   instance_type = "t3.small"
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
#   instance_class = "db.t4g.small"
#   db_name        = "app_stg"
#
#   multi_az                = false
#   backup_retention_period = 3
#   deletion_protection     = false
# }

# --- Storage ---------------------------------------------------------------
#
# module "uploads" {
#   source = "../../modules/s3-bucket"
#
#   bucket = "__PREFIX__-${local.env}-uploads"
# }
