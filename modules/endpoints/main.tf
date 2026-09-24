variable "suffix" { type = string }
variable "region" { type = string }
variable "vpc_id" { type = string }
variable "subnets" { type = map(object({ tier = string, az = string, slot = number, cidr = string, id = string, route_table_id = string })) }
variable "security_group_id" { type = string }
variable "artifact_arn" { type = string }
variable "secret_arns" { type = list(string) }
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for s in values(var.subnets) : s.route_table_id if !contains(["public", "history"], s.tier)]
  policy            = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = "*", Action = ["s3:GetObject", "s3:ListBucket"], Resource = [var.artifact_arn, "${var.artifact_arn}/*", "arn:aws:s3:::al2023-repos-${var.region}-*", "arn:aws:s3:::al2023-repos-${var.region}-*/*", "arn:aws:s3:::amazoncloudwatch-agent-${var.region}/*"] }] })
  tags              = { Name = "s3ep-${var.suffix}" }
}
resource "aws_vpc_endpoint" "secrets" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in values(var.subnets) : s.id if s.tier == "endpoint"]
  security_group_ids  = [var.security_group_id]
  policy              = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = "*", Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"], Resource = var.secret_arns }] })
  tags                = { Name = "secretsep-${var.suffix}" }
}
