# A group whose rules are standalone resources. Inline ingress/egress blocks
# churn on every plan and cannot be imported a rule at a time.

locals {
  tags = merge(var.tags, var.add_name_tag ? tomap({ Name = var.name }) : tomap({}))

  # null, not {}. An imported resource with no tags reads back as unset, and a
  # configured empty map plans as a change against it -- a no-op write, but it
  # keeps the plan off zero.
  group_tags = length(local.tags) > 0 ? local.tags : null
}

resource "aws_security_group" "this" {
  name        = var.name
  description = coalesce(var.description, var.name)
  vpc_id      = var.vpc_id

  tags = local.group_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = var.ingress_rules

  security_group_id = aws_security_group.this.id
  description       = each.value.description
  ip_protocol       = each.value.ip_protocol

  # AWS rejects ports on protocol -1 and stores them as -1.
  from_port = each.value.ip_protocol == "-1" ? null : each.value.from_port
  to_port   = each.value.ip_protocol == "-1" ? null : each.value.to_port

  cidr_ipv4                    = each.value.cidr_ipv4
  prefix_list_id               = each.value.prefix_list_id
  referenced_security_group_id = each.value.referenced_security_group_id

  tags = var.tag_rules ? merge(local.tags, tomap({ Name = "${var.name}-${each.key}" })) : null
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = var.egress_rules

  security_group_id = aws_security_group.this.id
  description       = each.value.description
  ip_protocol       = each.value.ip_protocol

  from_port = each.value.ip_protocol == "-1" ? null : each.value.from_port
  to_port   = each.value.ip_protocol == "-1" ? null : each.value.to_port

  cidr_ipv4                    = each.value.cidr_ipv4
  prefix_list_id               = each.value.prefix_list_id
  referenced_security_group_id = each.value.referenced_security_group_id

  tags = var.tag_rules ? merge(local.tags, tomap({ Name = "${var.name}-${each.key}" })) : null
}
