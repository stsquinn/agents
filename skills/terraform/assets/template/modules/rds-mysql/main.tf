# manage_master_user_password hands generation and rotation to RDS, keeping the
# credential out of state and out of plan output entirely.

locals {
  tags = merge(var.tags, var.add_name_tag ? tomap({ Name = var.identifier }) : tomap({}))

  # null, not {}: an imported resource with no tags reads back as unset, and an
  # empty map plans as a no-op change against it.
  resource_tags = length(local.tags) > 0 ? local.tags : null

  subnet_group_name = var.manage_subnet_group ? aws_db_subnet_group.this[0].name : var.subnet_group_name

  security_group_ids = var.manage_security_group ? [aws_security_group.this[0].id] : var.security_group_ids

  parameter_group_name = var.manage_parameter_group ? aws_db_parameter_group.this[0].name : var.parameter_group_name
}

resource "aws_db_subnet_group" "this" {
  count = var.manage_subnet_group ? 1 : 0

  name       = "${var.identifier}-subnets"
  subnet_ids = var.subnet_ids

  tags = local.resource_tags
}

resource "aws_security_group" "this" {
  count = var.manage_security_group ? 1 : 0

  name        = "${var.identifier}-sg"
  description = "Database access for ${var.identifier}."
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${var.identifier}-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_security_group" {
  for_each = var.manage_security_group ? var.allowed_security_group_ids : {}

  security_group_id            = aws_security_group.this[0].id
  description                  = "MySQL from ${each.key}"
  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value

  tags = merge(local.tags, { Name = "${var.identifier}-from-${each.key}" })
}

resource "aws_vpc_security_group_ingress_rule" "from_cidr" {
  for_each = var.manage_security_group ? var.allowed_cidr_blocks : {}

  security_group_id = aws_security_group.this[0].id
  description       = "MySQL from ${each.key}"
  from_port         = var.port
  to_port           = var.port
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value

  tags = merge(local.tags, { Name = "${var.identifier}-from-${each.key}" })
}

resource "aws_db_parameter_group" "this" {
  count = var.manage_parameter_group ? 1 : 0

  name_prefix = "${var.identifier}-"
  family      = var.parameter_group_family

  dynamic "parameter" {
    for_each = var.parameters

    content {
      name  = parameter.key
      value = parameter.value
    }
  }

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "this" {
  identifier = var.identifier

  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = var.storage_encrypted

  db_name                     = var.db_name
  username                    = var.username
  manage_master_user_password = var.manage_master_user_password ? true : null
  port                        = var.port

  db_subnet_group_name   = local.subnet_group_name
  vpc_security_group_ids = local.security_group_ids
  parameter_group_name   = local.parameter_group_name
  publicly_accessible    = var.publicly_accessible

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true

  auto_minor_version_upgrade = true
  apply_immediately          = var.apply_immediately

  performance_insights_enabled    = var.performance_insights_enabled
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.final_snapshot_identifier

  tags = local.resource_tags

  lifecycle {
    # RDS bumps the patch version during maintenance windows; that is not drift.
    ignore_changes = [engine_version]
  }
}
