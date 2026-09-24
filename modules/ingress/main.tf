variable "suffix" { type = string }
variable "environment" { type = string }
variable "prod" { type = bool }
variable "apps" { type = list(string) }
variable "domain" { type = string }
variable "zone_id" { type = string }
variable "operator_cidrs" { type = list(string) }
variable "vpc_id" { type = string }
variable "subnets" { type = list(string) }
variable "security_group_id" { type = string }
variable "log_bucket" { type = string }
resource "aws_acm_certificate" "this" {
  domain_name       = "*.${var.environment}.${var.domain}"
  validation_method = "DNS"
  lifecycle { create_before_destroy = true }
}
resource "aws_route53_record" "validation" {
  zone_id = var.zone_id
  name    = one(aws_acm_certificate.this.domain_validation_options).resource_record_name
  type    = one(aws_acm_certificate.this.domain_validation_options).resource_record_type
  records = [one(aws_acm_certificate.this.domain_validation_options).resource_record_value]
  ttl     = 60
}
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [aws_route53_record.validation.fqdn]
}
resource "aws_lb" "this" {
  name                       = "alb-${var.suffix}"
  internal                   = false
  load_balancer_type         = "application"
  subnets                    = var.subnets
  security_groups            = [var.security_group_id]
  drop_invalid_header_fields = true
  enable_deletion_protection = var.prod
  access_logs {
    enabled = true
    bucket  = var.log_bucket
    prefix  = "alb"
  }
}
resource "aws_lb_target_group" "app" {
  for_each = toset(var.apps)
  name     = "${substr(each.key, 0, 4)}-${var.suffix}"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path    = "/healthz"
    matcher = "200"
  }
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate_validation.this.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
}
resource "aws_lb_listener_rule" "app" {
  for_each     = { for i, app in var.apps : app => i if app != "backoffice" || length(var.operator_cidrs) > 0 }
  listener_arn = aws_lb_listener.https.arn
  priority     = 100 + each.value
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[each.key].arn
  }
  condition {
    host_header { values = ["${each.key}.${var.environment}.${var.domain}"] }
  }
  dynamic "condition" {
    for_each = each.key == "backoffice" ? [1] : []
    content {
      source_ip { values = var.operator_cidrs }
    }
  }
}
resource "aws_route53_record" "app" {
  for_each = toset(var.apps)
  zone_id  = var.zone_id
  name     = "${each.key}.${var.environment}.${var.domain}"
  type     = "A"
  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}
output "targets" { value = { for k, tg in aws_lb_target_group.app : k => tg.arn } }
output "dns_name" { value = aws_lb.this.dns_name }
