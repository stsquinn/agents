# Shaped for the pm2-managed Node hosts and self-hosted runners, which are pets
# rather than cattle -- hence user_data_replace_on_change defaulting to false.

locals {
  tags = merge(var.tags, { Name = var.name })

  security_group_ids = var.manage_security_group ? [aws_security_group.this[0].id] : var.security_group_ids

  iam_instance_profile = var.manage_iam ? aws_iam_instance_profile.this[0].name : var.iam_instance_profile
}

data "aws_ami" "al2023" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_security_group" "this" {
  count = var.manage_security_group ? 1 : 0

  name        = "${var.name}-sg"
  description = "Traffic to and from ${var.name}."
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${var.name}-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = var.manage_security_group ? var.ingress_rules : {}

  security_group_id = aws_security_group.this[0].id
  description       = coalesce(each.value.description, each.key)
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.ip_protocol

  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.referenced_security_group_id

  tags = merge(local.tags, { Name = "${var.name}-${each.key}" })
}

resource "aws_vpc_security_group_egress_rule" "all" {
  count = var.manage_security_group ? 1 : 0

  security_group_id = aws_security_group.this[0].id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(local.tags, { Name = "${var.name}-egress" })
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = var.manage_iam ? 1 : 0

  name               = "${var.name}-instance"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = local.tags
}

# Session Manager: shell access without opening port 22 to anything.
resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.manage_iam ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "extra" {
  for_each = var.manage_iam ? var.extra_policy_arns : {}

  role       = aws_iam_role.this[0].name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "this" {
  count = var.manage_iam ? 1 : 0

  name = "${var.name}-instance"
  role = aws_iam_role.this[0].name

  tags = local.tags
}

resource "aws_instance" "this" {
  ami           = coalesce(var.ami_id, try(data.aws_ami.al2023[0].id, null))
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_name

  vpc_security_group_ids = local.security_group_ids
  iam_instance_profile   = local.iam_instance_profile

  associate_public_ip_address = var.assign_eip ? false : var.associate_public_ip
  monitoring                  = var.enable_detailed_monitoring
  disable_api_termination     = var.disable_api_termination

  user_data                   = var.user_data
  user_data_replace_on_change = var.user_data_replace_on_change

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = var.root_volume_encrypted
    delete_on_termination = var.root_volume_delete_on_termination

    tags = var.tag_root_volume ? merge(local.tags, tomap({ Name = "${var.name}-root" })) : null
  }

  # IMDSv2 only: otherwise an SSRF on the app reads the instance role's
  # credentials off the metadata endpoint.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = var.metadata_hop_limit
    instance_metadata_tags      = var.instance_metadata_tags
  }

  tags = local.tags

  lifecycle {
    # A newer AMI should not silently replace a running production host.
    #
    # user_data is ignored for the same reason, plus one of its own. These hosts
    # are pets: their bootstrap ran once and the machine has been hand-tended
    # since, so the script in AWS is history, not desired state. Changing it also
    # is not free -- AWS only accepts a new user_data on a stopped instance, so
    # Terraform would stop, modify and start a running host to reconcile a field
    # nothing reads after first boot. Creation still applies var.user_data;
    # ignore_changes only suppresses updates.
    ignore_changes = [ami, user_data]
  }
}

resource "aws_eip" "this" {
  count = var.assign_eip ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.this.id

  tags = merge(local.tags, { Name = "${var.name}-eip" })
}
