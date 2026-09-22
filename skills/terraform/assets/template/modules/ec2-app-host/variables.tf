variable "name" {
  description = "Host name, used for every resource name and the Name tag, e.g. \"acme-prod-api\"."
  type        = string
}

variable "vpc_id" {
  description = "VPC to place the host and its security group in."
  type        = string
}

variable "subnet_id" {
  description = "Subnet to launch into."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "ami_id" {
  description = "AMI to launch. Leave null to use the latest Amazon Linux 2023 x86_64 image."
  type        = string
  default     = null
}

variable "key_name" {
  description = "EC2 key pair for SSH. Prefer null and reach the host through SSM Session Manager instead."
  type        = string
  default     = null
}

variable "ingress_rules" {
  description = <<-EOT
    Inbound rules, keyed by a stable name so adding one never renumbers the rest.
    Give exactly one source per rule: cidr_ipv4 or referenced_security_group_id.
  EOT
  type = map(object({
    description                  = optional(string)
    from_port                    = number
    to_port                      = number
    ip_protocol                  = optional(string, "tcp")
    cidr_ipv4                    = optional(string)
    referenced_security_group_id = optional(string)
  }))
  default = {}
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "Root EBS volume type."
  type        = string
  default     = "gp3"
}

variable "assign_eip" {
  description = "Attach a static Elastic IP. Needed wherever a DNS record or a third-party allowlist points at this host."
  type        = bool
  default     = false
}

variable "metadata_hop_limit" {
  description = "IMDS PUT response hop limit. Two lets a container on the host reach the metadata endpoint; one confines it to the host itself."
  type        = number
  default     = 2
}

variable "associate_public_ip" {
  description = <<-EOT
    Give the instance a public IP from the subnet pool. Ignored when assign_eip
    is true. Null leaves it to whatever the instance already has, which is what
    adoption wants: the attribute is ForceNew, so guessing it wrong on a running
    host destroys and recreates it.
  EOT
  type        = bool
  default     = false
}

variable "extra_policy_arns" {
  description = "Additional managed policy ARNs for the instance role, keyed by a stable name."
  type        = map(string)
  default     = {}
}

variable "user_data" {
  description = "Cloud-init user data. Changing it replaces the instance unless user_data_replace_on_change is false."
  type        = string
  default     = null
}

variable "user_data_replace_on_change" {
  description = "Replace the instance when user_data changes. False keeps long-lived pets alive across edits."
  type        = bool
  default     = false
}

variable "enable_detailed_monitoring" {
  description = "One-minute CloudWatch metrics instead of five."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}

# --- adoption ---------------------------------------------------------------
#
# Only for taking over hosts that already exist. A new host should leave all of
# these alone: its own group, its own role, and an encrypted root volume.

variable "manage_security_group" {
  description = "Create a group and its rules for this host. Off when several hosts already share one group, which a per-host group cannot express."
  type        = bool
  default     = true
}

variable "security_group_ids" {
  description = "Existing groups to attach when manage_security_group is off."
  type        = list(string)
  default     = []
}

variable "manage_iam" {
  description = "Create the instance role, its policy attachments and its instance profile. Off when hosts already share one profile."
  type        = bool
  default     = true
}

variable "iam_instance_profile" {
  description = "Existing instance profile name to attach when manage_iam is off."
  type        = string
  default     = null
}

variable "root_volume_encrypted" {
  description = "Encrypt the root volume. ForceNew: changing it on a running host destroys and recreates the instance, so an unencrypted host must be adopted as false and migrated deliberately."
  type        = bool
  default     = true
}

variable "instance_metadata_tags" {
  description = "Expose instance tags through IMDS: \"enabled\" or \"disabled\"."
  type        = string
  default     = "enabled"

  validation {
    condition     = contains(["enabled", "disabled"], var.instance_metadata_tags)
    error_message = "instance_metadata_tags must be enabled or disabled."
  }
}

variable "tag_root_volume" {
  description = "Tag the root volume Name=<name>-root. Off while adopting a volume that carries no tags."
  type        = bool
  default     = true
}

variable "disable_api_termination" {
  description = "Termination protection. null leaves it unset; adopt a protected host as true or the plan switches protection off."
  type        = bool
  default     = null
}

variable "root_volume_delete_on_termination" {
  description = "Delete the root volume with the instance. Adopt a host that keeps its volume as false."
  type        = bool
  default     = true
}
