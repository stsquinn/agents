variable "identifier" {
  description = "DB instance identifier, e.g. \"acme-prod-mysql\"."
  type        = string
}

variable "vpc_id" {
  description = "VPC the instance lives in."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group. At least two, in different AZs."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "RDS requires a subnet group spanning at least two availability zones."
  }
}

variable "allowed_security_group_ids" {
  description = "Security groups permitted to reach the database. Prefer this over CIDR allowlists."
  type        = map(string)
  default     = {}
}

variable "allowed_cidr_blocks" {
  description = "CIDRs permitted to reach the database. Keep empty where a security group reference will do."
  type        = map(string)
  default     = {}
}

variable "engine_version" {
  description = "MySQL engine version."
  type        = string
  default     = "8.0"
}

variable "parameter_group_family" {
  description = "Parameter group family, which must match the engine version, e.g. \"mysql8.0\"."
  type        = string
  default     = "mysql8.0"
}

variable "parameters" {
  description = "Engine parameters to override, as name => value."
  type        = map(string)
  default     = {}
}

variable "instance_class" {
  description = "Instance class, e.g. \"db.t4g.medium\"."
  type        = string
}

variable "allocated_storage" {
  description = "Storage in GiB."
  type        = number
  default     = 50
}

variable "max_allocated_storage" {
  description = "Upper bound for storage autoscaling. Set equal to allocated_storage to switch autoscaling off."
  type        = number
  default     = 0
}

variable "db_name" {
  description = "Initial database name. Null leaves the instance without one."
  type        = string
  default     = null
}

variable "username" {
  description = "Master username. The password is generated and rotated by AWS in Secrets Manager -- it is never in Terraform state."
  type        = string
  default     = "admin"
}

variable "port" {
  description = "Listening port."
  type        = number
  default     = 3306
}

variable "multi_az" {
  description = "Synchronous standby in a second AZ. On for prod, usually off for stg."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Days of automated backups. Zero disables them, which also disables point-in-time recovery."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Refuse to delete the instance until this is turned off."
  type        = bool
  default     = true
}

# AWS stores none of these three -- they are parameters on ModifyDBInstance and
# DeleteDBInstance, so describe-db-instances never returns them. An imported
# instance reads back with all three unset, and setting any of them plans as a
# change that makes no API call. Null keeps an adopted instance at 0 to change.

variable "apply_immediately" {
  description = "Apply modifications at once rather than in the maintenance window. Null leaves it unset, which the provider treats as false."
  type        = bool
  default     = null
}

variable "skip_final_snapshot" {
  description = "Skip the snapshot taken on delete. Null leaves it unset, which the provider treats as false -- so a destroy demands final_snapshot_identifier and fails without it."
  type        = bool
  default     = null
}

variable "final_snapshot_identifier" {
  description = "Name for the snapshot taken on delete. AWS requires it whenever skip_final_snapshot is not true and a destroy is actually attempted; deletion_protection is the guard that matters day to day."
  type        = string
  default     = null
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}

# --- adoption ---------------------------------------------------------------
#
# Only for taking over a database that already exists. A new one should leave
# every one of these alone and get the hardened baseline.

variable "manage_subnet_group" {
  description = "Create the subnet group. Off to keep an existing one -- the name is ForceNew on the instance, so a rename moves the database."
  type        = bool
  default     = true
}

variable "subnet_group_name" {
  description = "Existing subnet group to use when manage_subnet_group is off."
  type        = string
  default     = null
}

variable "manage_security_group" {
  description = "Create a group and its ingress rules. Off when the database already sits behind a group owned elsewhere."
  type        = bool
  default     = true
}

variable "security_group_ids" {
  description = "Existing groups to attach when manage_security_group is off."
  type        = list(string)
  default     = []
}

variable "manage_parameter_group" {
  description = "Create a parameter group. Off for a database on an AWS default group, which cannot be managed by Terraform at all."
  type        = bool
  default     = true
}

variable "parameter_group_name" {
  description = "Existing parameter group to use when manage_parameter_group is off, e.g. \"default.mysql8.4\"."
  type        = string
  default     = null
}

variable "storage_encrypted" {
  description = "Encrypt storage at rest. Encryption cannot be turned on in place, so changing this on a live database replaces it -- adopt as-is and migrate deliberately."
  type        = bool
  default     = true
}

variable "manage_master_user_password" {
  description = "Let RDS generate and rotate the master password into Secrets Manager. Turning this on for a database using a classic password rotates it, which cuts every existing connection."
  type        = bool
  default     = true
}

variable "publicly_accessible" {
  description = "Give the instance a public endpoint. Should be false; true only to record a database that already is one."
  type        = bool
  default     = false
}

variable "backup_window" {
  description = "Daily backup window, UTC."
  type        = string
  default     = "01:00-02:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window, UTC."
  type        = string
  default     = "sun:02:30-sun:03:30"
}

variable "enabled_cloudwatch_logs_exports" {
  description = "Log types shipped to CloudWatch. Empty for a database that exports none."
  type        = list(string)
  default     = ["error", "slowquery"]
}

variable "add_name_tag" {
  description = "Tag resources Name=<identifier>. Off while adopting resources that carry different tags."
  type        = bool
  default     = true
}
