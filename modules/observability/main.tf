variable "suffix" { type = string }
variable "apps" { type = list(string) }
variable "retention" { type = number }
resource "aws_cloudwatch_log_group" "app" {
  for_each          = toset(var.apps)
  name              = "/platform/${var.suffix}/${each.key}"
  retention_in_days = var.retention
  tags              = { Name = "logs-${each.key}-${var.suffix}" }
}
output "groups" { value = { for k, group in aws_cloudwatch_log_group.app : k => { name = group.name, arn = group.arn } } }
