variable "name" {
  description = "Group name, unique within the VPC."
  type        = string
}

variable "vpc_id" {
  description = "VPC the group belongs to."
  type        = string
}

variable "description" {
  description = <<-EOT
    Group description. Defaults to the name. AWS cannot change this after
    creation, so a value that does not match an adopted group forces a
    replacement -- which detaches it from everything using it.
  EOT
  type        = string
  default     = null
}

variable "ingress_rules" {
  description = <<-EOT
    Inbound rules, keyed by a stable name so adding one never renumbers the rest.
    Give exactly one source per rule: cidr_ipv4, prefix_list_id or
    referenced_security_group_id. Leave the ports out when ip_protocol is "-1".
  EOT
  type = map(object({
    description                  = optional(string)
    from_port                    = optional(number)
    to_port                      = optional(number)
    ip_protocol                  = optional(string, "tcp")
    cidr_ipv4                    = optional(string)
    prefix_list_id               = optional(string)
    referenced_security_group_id = optional(string)
  }))
  default = {}
}

variable "egress_rules" {
  description = "Outbound rules, same shape as ingress_rules. Default is all traffic out."
  type = map(object({
    description                  = optional(string)
    from_port                    = optional(number)
    to_port                      = optional(number)
    ip_protocol                  = optional(string, "-1")
    cidr_ipv4                    = optional(string)
    prefix_list_id               = optional(string)
    referenced_security_group_id = optional(string)
  }))
  default = {
    all = {
      description = "All outbound"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}

variable "tags" {
  description = "Extra tags merged onto the group."
  type        = map(string)
  default     = {}
}

# --- adoption ---------------------------------------------------------------

variable "add_name_tag" {
  description = "Tag the group Name=<name>. Off while adopting an untagged group."
  type        = bool
  default     = true
}

variable "tag_rules" {
  description = "Tag each rule Name=<name>-<key>. Off while adopting rules that carry no tags."
  type        = bool
  default     = true
}
