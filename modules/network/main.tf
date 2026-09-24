variable "suffix" { type = string }
variable "primary_cidr" { type = string }
variable "historical_cidr" { type = string }
variable "az_ids" { type = list(string) }
variable "nat_count" { type = number }

locals {
  tiers = { public = 0, app = 10, db = 20, cache = 30, endpoint = 40, history = 20 }
  subnets = merge([for tier, offset in local.tiers : {
    for i, az in var.az_ids : "${tier}-${i}" => {
      tier = tier
      az   = az
      slot = i
      cidr = cidrsubnet(tier == "history" ? var.historical_cidr : var.primary_cidr, 8, offset + i)
    }
  }]...)
}
resource "aws_vpc" "primary" {
  cidr_block           = var.primary_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "vpc-${var.suffix}" }
}
resource "aws_vpc" "historical" {
  cidr_block           = var.historical_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "history-${var.suffix}" }
}
resource "aws_default_security_group" "closed" {
  for_each = { primary = aws_vpc.primary.id, historical = aws_vpc.historical.id }
  vpc_id   = each.value
  tags     = { Name = "default-closed-${each.key}-${var.suffix}" }
}
resource "aws_subnet" "this" {
  for_each                = local.subnets
  vpc_id                  = each.value.tier == "history" ? aws_vpc.historical.id : aws_vpc.primary.id
  cidr_block              = each.value.cidr
  availability_zone_id    = each.value.az
  map_public_ip_on_launch = false
  tags                    = { Name = "${each.key}-${var.suffix}" }
}
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.primary.id
  tags   = { Name = "igw-${var.suffix}" }
}
resource "aws_eip" "nat" {
  count  = var.nat_count
  domain = "vpc"
  tags   = { Name = "eip${count.index + 1}-${var.suffix}" }
}
resource "aws_nat_gateway" "this" {
  count         = var.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.this["public-${count.index}"].id
  depends_on    = [aws_internet_gateway.this]
  tags          = { Name = "nat${count.index + 1}-${var.suffix}" }
}
resource "aws_route_table" "this" {
  for_each = local.subnets
  vpc_id   = each.value.tier == "history" ? aws_vpc.historical.id : aws_vpc.primary.id
  tags     = { Name = "rt-${each.key}-${var.suffix}" }
}
resource "aws_route_table_association" "this" {
  for_each       = local.subnets
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.key].id
}
resource "aws_route" "internet" {
  for_each               = { for k, v in local.subnets : k => v if v.tier == "public" }
  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}
resource "aws_route" "nat" {
  for_each               = { for k, v in local.subnets : k => v if v.tier == "app" }
  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.nat_count == 1 ? 0 : each.value.slot].id
}
resource "aws_vpc_peering_connection" "this" {
  vpc_id      = aws_vpc.primary.id
  peer_vpc_id = aws_vpc.historical.id
  auto_accept = true
  requester { allow_remote_vpc_dns_resolution = true }
  accepter { allow_remote_vpc_dns_resolution = true }
  tags = { Name = "peer-${var.suffix}" }
}
locals {
  peer_routes = merge([for k, subnet in local.subnets : {
    for remote_key, remote in local.subnets : "${k}-${remote_key}" => {
      table = k
      cidr  = remote.cidr
    } if(subnet.tier == "app" && remote.tier == "history") || (subnet.tier == "history" && remote.tier == "app")
  }]...)
}
resource "aws_route" "peer" {
  for_each                  = local.peer_routes
  route_table_id            = aws_route_table.this[each.value.table].id
  destination_cidr_block    = each.value.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}
output "primary_vpc_id" { value = aws_vpc.primary.id }
output "historical_vpc_id" { value = aws_vpc.historical.id }
output "subnets" {
  value = { for k, v in local.subnets : k => merge(v, { id = aws_subnet.this[k].id, route_table_id = aws_route_table.this[k].id }) }
}
output "peering_id" { value = aws_vpc_peering_connection.this.id }
