variable "name" {
  description = "Name prefix for every resource in this VPC, e.g. \"acme-prod\"."
  type        = string
}

variable "cidr_block" {
  description = "IPv4 CIDR for the VPC."
  type        = string
}

variable "public_subnets" {
  description = "Map of availability zone => CIDR for internet-facing subnets."
  type        = map(string)
  default     = {}
}

variable "private_subnets" {
  description = "Map of availability zone => CIDR for private subnets."
  type        = map(string)
  default     = {}
}

variable "enable_nat_gateway" {
  description = "Create NAT so private subnets reach the internet outbound. Costs money per hour and per GB."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Route every private subnet through one NAT. Cheaper, but the NAT's AZ becomes a single point of failure. Reasonable for stg, not for prod."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Ship VPC flow logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "CloudWatch retention for flow logs."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}

# --- adoption ---------------------------------------------------------------
#
# Only for taking over a VPC that already exists. A greenfield VPC should leave
# all three alone and take the generated names and the emptied default group.

variable "name_overrides" {
  description = "Name tag to keep per resource, so adopting does not rename what is already running. A key left out gets the generated name."
  type = object({
    vpc             = optional(string)
    default_sg      = optional(string)
    igw             = optional(string)
    public_rt       = optional(string)
    public_subnets  = optional(map(string), {})
    private_subnets = optional(map(string), {})
    private_rts     = optional(map(string), {})
    nat             = optional(map(string), {})
    nat_eip         = optional(map(string), {})
  })
  default = {}
}

variable "tag_subnet_tier" {
  description = "Tag subnets Tier=public/private. Off while adopting subnets that do not carry it, since adding a tag is still a write."
  type        = bool
  default     = true
}

variable "manage_default_security_group" {
  description = "Adopt the VPC's default security group and empty it (a CIS control). Off leaves it untouched -- emptying a live group revokes real rules."
  type        = bool
  default     = true
}
