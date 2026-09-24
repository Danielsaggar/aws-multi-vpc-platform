variable "suffix" { type = string }
variable "primary_vpc" { type = string }
variable "historical_vpc" { type = string }
variable "apps" { type = list(string) }
variable "subnets" {
  type = map(object({ tier = string, az = string, slot = number, cidr = string, id = string, route_table_id = string }))
}
resource "aws_security_group" "this" {
  for_each    = toset(concat(var.apps, ["alb", "db", "cache", "history", "endpoint"]))
  name        = "${each.key}-${var.suffix}"
  vpc_id      = each.key == "history" ? var.historical_vpc : var.primary_vpc
  description = "Explicit ${each.key} traffic rules"
  tags        = { Name = "${each.key}-${var.suffix}" }
}
locals {
  links = merge(
    { for app in var.apps : "alb-${app}" => { from = "alb", to = app, port = 8080 } },
    { for app in ["webapi", "gameapi"] : "${app}-db" => { from = app, to = "db", port = 5432 } },
    { for app in ["webapi", "gameapi"] : "${app}-cache" => { from = app, to = "cache", port = 6379 } },
    { "backoffice-history" = { from = "backoffice", to = "history", port = 5432 } },
    { for app in ["backoffice", "webapi", "gameapi"] : "${app}-endpoint" => { from = app, to = "endpoint", port = 443 } }
  )
}
resource "aws_vpc_security_group_ingress_rule" "links" {
  for_each                     = local.links
  security_group_id            = aws_security_group.this[each.value.to].id
  referenced_security_group_id = aws_security_group.this[each.value.from].id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
}
resource "aws_vpc_security_group_egress_rule" "links" {
  for_each                     = local.links
  security_group_id            = aws_security_group.this[each.value.from].id
  referenced_security_group_id = aws_security_group.this[each.value.to].id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
}
resource "aws_vpc_security_group_ingress_rule" "public" {
  for_each          = toset(["80", "443"])
  security_group_id = aws_security_group.this["alb"].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.key)
  to_port           = tonumber(each.key)
}
resource "aws_vpc_security_group_egress_rule" "https" {
  for_each          = toset(var.apps)
  security_group_id = aws_security_group.this[each.key].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS bootstrap and AWS APIs via NAT or endpoints"
}

# Stateless ACLs: allow exact service paths and their return traffic.
locals {
  tier_cidrs = { for tier in ["public", "app", "db", "cache", "endpoint", "history"] : tier => [for s in values(var.subnets) : s.cidr if s.tier == tier] }
  flows = concat(
    [for port in [80, 443] : { source = "external", target = "public", port = port }],
    [{ source = "public", target = "app", port = 8080 },
      { source = "app", target = "db", port = 5432 },
      { source = "app", target = "history", port = 5432 },
      { source = "app", target = "cache", port = 6379 },
      { source = "app", target = "endpoint", port = 443 },
      { source = "app", target = "external", port = 443 },
    { source = "public", target = "external", port = 443 }]
  )
  acl_rules = flatten([for tier in keys(local.tier_cidrs) : flatten([for flow in local.flows : concat(
    flow.target == tier ? flatten([for cidr in(flow.source == "external" ? ["0.0.0.0/0"] : local.tier_cidrs[flow.source]) : [
      { tier = tier, egress = false, cidr = cidr, from = flow.port, to = flow.port },
      { tier = tier, egress = true, cidr = cidr, from = 1024, to = 65535 }
    ]]) : [],
    flow.source == tier ? flatten([for cidr in(flow.target == "external" ? ["0.0.0.0/0"] : local.tier_cidrs[flow.target]) : [
      { tier = tier, egress = true, cidr = cidr, from = flow.port, to = flow.port },
      { tier = tier, egress = false, cidr = cidr, from = 1024, to = 65535 }
    ]]) : []
  )])])
}
resource "aws_network_acl" "tier" {
  for_each   = local.tier_cidrs
  vpc_id     = each.key == "history" ? var.historical_vpc : var.primary_vpc
  subnet_ids = [for s in values(var.subnets) : s.id if s.tier == each.key]
  tags       = { Name = "acl-${each.key}-${var.suffix}" }
}
resource "aws_network_acl_rule" "traffic" {
  for_each       = { for i, rule in local.acl_rules : tostring(i) => rule }
  network_acl_id = aws_network_acl.tier[each.value.tier].id
  rule_number    = 100 + tonumber(each.key)
  egress         = each.value.egress
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = each.value.from
  to_port        = each.value.to
}
output "ids" { value = { for k, v in aws_security_group.this : k => v.id } }
