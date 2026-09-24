mock_provider "aws" {
  mock_resource "aws_db_instance" {
    defaults = { master_user_secret = [{ secret_arn = "arn:aws:secretsmanager:ca-central-1:000000000000:secret:rds!db-test", kms_key_id = "test", secret_status = "active" }] }
  }
}
run "private_prod_data" {
  command = plan
  module { source = "./modules/data" }
  variables {
    suffix = "pmp-prod-01-ca-central-1"
    prod   = true
    subnets = {
      db0      = { tier = "db", az = "cac1-az1", slot = 0, cidr = "10.20.20.0/24", id = "subnet-11111111", route_table_id = "rtb-11111111" }
      db1      = { tier = "db", az = "cac1-az2", slot = 1, cidr = "10.20.21.0/24", id = "subnet-22222222", route_table_id = "rtb-22222222" }
      history0 = { tier = "history", az = "cac1-az1", slot = 0, cidr = "10.21.20.0/24", id = "subnet-33333333", route_table_id = "rtb-33333333" }
      history1 = { tier = "history", az = "cac1-az2", slot = 1, cidr = "10.21.21.0/24", id = "subnet-44444444", route_table_id = "rtb-44444444" }
      cache0   = { tier = "cache", az = "cac1-az1", slot = 0, cidr = "10.20.30.0/24", id = "subnet-55555555", route_table_id = "rtb-55555555" }
      cache1   = { tier = "cache", az = "cac1-az2", slot = 1, cidr = "10.20.31.0/24", id = "subnet-66666666", route_table_id = "rtb-66666666" }
    }
    security_groups  = { db = "sg-11111111", history = "sg-22222222", cache = "sg-33333333" }
    db_class         = "db.t4g.small"
    postgres_version = "16.6"
    redis_version    = "7.1"
    cache_node_type  = "cache.t4g.small"
  }
  assert {
    condition     = alltrue([for db in aws_db_instance.this : db.multi_az && db.storage_encrypted && !db.publicly_accessible && db.manage_master_user_password && db.deletion_protection && !db.skip_final_snapshot])
    error_message = "PROD databases require private, encrypted, protected Multi-AZ deployment."
  }
  assert {
    condition     = aws_elasticache_replication_group.this.automatic_failover_enabled && aws_elasticache_replication_group.this.transit_encryption_enabled && aws_elasticache_replication_group.this.at_rest_encryption_enabled && aws_elasticache_replication_group.this.num_cache_clusters == 2
    error_message = "PROD Redis requires encryption and failover replicas."
  }
  assert {
    condition     = aws_elasticache_user.app.authentication_mode[0].type == "iam" && startswith(aws_elasticache_user.default.access_string, "off")
    error_message = "Redis requires authenticated application users and a disabled default user."
  }
}
