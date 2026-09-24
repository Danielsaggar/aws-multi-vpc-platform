variable "suffix" { type = string }
variable "prod" { type = bool }
variable "subnets" { type = map(object({ tier = string, az = string, slot = number, cidr = string, id = string, route_table_id = string })) }
variable "security_groups" { type = map(string) }
variable "db_class" { type = string }
variable "postgres_version" { type = string }
variable "redis_version" { type = string }
variable "cache_node_type" { type = string }
resource "aws_db_subnet_group" "this" {
  for_each   = toset(["db", "history"])
  name       = "${each.key}-${var.suffix}"
  subnet_ids = [for s in values(var.subnets) : s.id if s.tier == each.key]
}
resource "aws_db_instance" "this" {
  for_each                        = toset(["db", "history"])
  identifier                      = "${each.key}-${var.suffix}"
  engine                          = "postgres"
  engine_version                  = var.postgres_version
  instance_class                  = var.db_class
  allocated_storage               = 20
  max_allocated_storage           = 100
  storage_type                    = "gp3"
  storage_encrypted               = true
  db_name                         = each.key == "db" ? "transactions" : "history"
  username                        = "platform_admin"
  manage_master_user_password     = true
  db_subnet_group_name            = aws_db_subnet_group.this[each.key].name
  vpc_security_group_ids          = [var.security_groups[each.key]]
  publicly_accessible             = false
  multi_az                        = each.key == "db" || var.prod
  backup_retention_period         = var.prod ? 14 : 7
  backup_window                   = "06:00-07:00"
  maintenance_window              = "sun:08:00-sun:09:00"
  deletion_protection             = var.prod
  skip_final_snapshot             = !var.prod
  final_snapshot_identifier       = "${each.key}-${var.suffix}-final"
  copy_tags_to_snapshot           = true
  auto_minor_version_upgrade      = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  tags                            = { Name = "${each.key}-${var.suffix}" }
}
resource "aws_elasticache_subnet_group" "this" {
  name       = "cache-${var.suffix}"
  subnet_ids = [for s in values(var.subnets) : s.id if s.tier == "cache"]
}
resource "aws_elasticache_user" "default" {
  user_id       = "disabled-${var.suffix}"
  user_name     = "default"
  engine        = "redis"
  access_string = "off ~* -@all"
  authentication_mode { type = "no-password-required" }
}
resource "aws_elasticache_user" "app" {
  user_id       = "app-${var.suffix}"
  user_name     = "app-${var.suffix}"
  engine        = "redis"
  access_string = "on ~app:* +get +set +del +expire +ttl +ping"
  authentication_mode { type = "iam" }
}
resource "aws_elasticache_user_group" "this" {
  user_group_id = "cache-${var.suffix}"
  engine        = "redis"
  user_ids      = [aws_elasticache_user.default.user_id, aws_elasticache_user.app.user_id]
}
resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = "redis-${var.suffix}"
  description                = "Private application cache"
  engine                     = "redis"
  engine_version             = var.redis_version
  node_type                  = var.cache_node_type
  port                       = 6379
  num_cache_clusters         = var.prod ? 2 : 1
  automatic_failover_enabled = var.prod
  multi_az_enabled           = var.prod
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  transit_encryption_mode    = "required"
  user_group_ids             = [aws_elasticache_user_group.this.user_group_id]
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [var.security_groups["cache"]]
  snapshot_retention_limit   = var.prod ? 7 : 1
  tags                       = { Name = "redis-${var.suffix}" }
}
resource "aws_secretsmanager_secret" "application" {
  for_each                = toset(["backoffice", "webapi", "gameapi"])
  name                    = "secret-${each.key}-${var.suffix}"
  description             = "Restricted ${each.key} database credentials, populated outside Terraform by the authorized database administrator"
  recovery_window_in_days = var.prod ? 30 : 7
  tags                    = { Name = "secret-${each.key}-${var.suffix}" }
}
output "secret_arns" { value = { for k, secret in aws_secretsmanager_secret.application : k => secret.arn } }
output "master_secret_arns" { value = { for k, db in aws_db_instance.this : k => db.master_user_secret[0].secret_arn } }
output "endpoints" { value = { for k, db in aws_db_instance.this : k => db.address } }
output "redis_endpoint" { value = aws_elasticache_replication_group.this.primary_endpoint_address }
output "redis_iam_resources" { value = [aws_elasticache_replication_group.this.arn, aws_elasticache_user.app.arn] }
