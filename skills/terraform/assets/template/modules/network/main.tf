# Subnets are maps, not lists: with a list, deleting the first CIDR renumbers
# every subnet after it and Terraform destroys and recreates them.

locals {
  tags = merge(var.tags, { Name = coalesce(var.name_overrides.vpc, var.name) })

  # Which AZ hosts NAT for a given private subnet.
  nat_azs = var.enable_nat_gateway ? (
    var.single_nat_gateway
    ? slice(sort(keys(var.public_subnets)), 0, 1)
    : sort(keys(var.public_subnets))
  ) : []

  nat_az_for_private = {
    for az in keys(var.private_subnets) :
    az => contains(local.nat_azs, az) ? az : try(local.nat_azs[0], null)
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = local.tags
}

# Emptying the default SG is a CIS / Security Hub control.
resource "aws_default_security_group" "this" {
  count = var.manage_default_security_group ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, {
    Name = coalesce(var.name_overrides.default_sg, "${var.name}-default-DO-NOT-USE")
  })
}

resource "aws_internet_gateway" "this" {
  count = length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = coalesce(var.name_overrides.igw, "${var.name}-igw") })
}

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = merge(local.tags, {
    Name = lookup(var.name_overrides.public_subnets, each.key, "${var.name}-public-${each.key}")
  }, var.tag_subnet_tier ? tomap({ Tier = "public" }) : tomap({}))
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(local.tags, {
    Name = lookup(var.name_overrides.private_subnets, each.key, "${var.name}-private-${each.key}")
  }, var.tag_subnet_tier ? tomap({ Tier = "private" }) : tomap({}))
}

resource "aws_route_table" "public" {
  count = length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = coalesce(var.name_overrides.public_rt, "${var.name}-public") })
}

resource "aws_route" "public_default" {
  count = length(var.public_subnets) > 0 ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_eip" "nat" {
  for_each = toset(local.nat_azs)

  domain = "vpc"
  tags   = merge(local.tags, { Name = lookup(var.name_overrides.nat_eip, each.key, "${var.name}-nat-${each.key}") })
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_azs)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(local.tags, { Name = lookup(var.name_overrides.nat, each.key, "${var.name}-nat-${each.key}") })

  depends_on = [aws_internet_gateway.this]
}

# One route table per private subnet, so each can point at NAT in its own AZ.
resource "aws_route_table" "private" {
  for_each = var.private_subnets

  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = lookup(var.name_overrides.private_rts, each.key, "${var.name}-private-${each.key}") })
}

resource "aws_route" "private_default" {
  for_each = {
    for az, nat_az in local.nat_az_for_private :
    az => nat_az if nat_az != null
  }

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.value].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
