variable "instances" { type = map(object({ app = string, az = number, name = string })) }
variable "apps" { type = list(string) }
variable "suffix" { type = string }
variable "ami_id" { type = string }
variable "instance_type" { type = string }
variable "subnets" { type = map(object({ tier = string, az = string, slot = number, cidr = string, id = string, route_table_id = string })) }
variable "security_groups" { type = map(string) }
variable "target_groups" { type = map(string) }
variable "log_groups" { type = map(object({ name = string, arn = string })) }
variable "boundary_arn" { type = string }
variable "artifact_arn" { type = string }
variable "secrets" { type = map(string) }
variable "redis_resources" { type = list(string) }
variable "region" { type = string }
variable "user_data_template" { type = string }
resource "aws_iam_role" "app" {
  for_each             = toset(var.apps)
  name                 = "${each.key}-${var.suffix}"
  path                 = "/platform/"
  permissions_boundary = var.boundary_arn
  assume_role_policy   = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ec2.amazonaws.com" } }] })
}
resource "aws_iam_role_policy" "app" {
  for_each = toset(var.apps)
  name     = "runtime"
  role     = aws_iam_role.app[each.key].id
  policy = jsonencode({ Version = "2012-10-17", Statement = concat([
    { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"], Resource = "${var.log_groups[each.key].arn}:*" },
    { Effect = "Allow", Action = ["s3:GetObject"], Resource = "${var.artifact_arn}/${each.key}/*" }
    ], each.key == "frontsite" ? [] : [
    { Effect = "Allow", Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"], Resource = var.secrets[each.key] }
    ], contains(["webapi", "gameapi"], each.key) ? [
    { Effect = "Allow", Action = ["elasticache:Connect"], Resource = var.redis_resources }
  ] : []) })
}
resource "aws_iam_instance_profile" "app" {
  for_each = toset(var.apps)
  name     = "${each.key}-${var.suffix}"
  path     = "/platform/"
  role     = aws_iam_role.app[each.key].name
}
resource "aws_instance" "app" {
  for_each                    = var.instances
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnets["app-${each.value.az}"].id
  vpc_security_group_ids      = [var.security_groups[each.value.app]]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.app[each.value.app].name
  user_data_replace_on_change = true
  user_data                   = templatefile(var.user_data_template, { app = each.value.app, log_group = var.log_groups[each.value.app].name, region = var.region })
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 12
  }
  tags       = { Name = each.value.name, Application = each.value.app }
  depends_on = [aws_iam_role_policy.app]
}
resource "aws_lb_target_group_attachment" "app" {
  for_each         = var.instances
  target_group_arn = var.target_groups[each.value.app]
  target_id        = aws_instance.app[each.key].id
  port             = 8080
}
output "ids" { value = { for k, instance in aws_instance.app : k => instance.id } }
