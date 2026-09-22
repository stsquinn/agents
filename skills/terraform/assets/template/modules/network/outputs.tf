output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "IPv4 CIDR of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Map of availability zone => public subnet ID."
  value       = { for az, s in aws_subnet.public : az => s.id }
}

output "private_subnet_ids" {
  description = "Map of availability zone => private subnet ID."
  value       = { for az, s in aws_subnet.private : az => s.id }
}

output "public_subnet_id_list" {
  description = "Public subnet IDs, AZ-sorted. For resources taking a plain list."
  value       = [for az in sort(keys(aws_subnet.public)) : aws_subnet.public[az].id]
}

output "private_subnet_id_list" {
  description = "Private subnet IDs, AZ-sorted. For resources taking a plain list."
  value       = [for az in sort(keys(aws_subnet.private)) : aws_subnet.private[az].id]
}

output "nat_public_ips" {
  description = "Elastic IPs the NAT gateways egress from. These are the addresses to allowlist on third-party services."
  value       = { for az, e in aws_eip.nat : az => e.public_ip }
}
