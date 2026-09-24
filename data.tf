module "data" {
  source           = "./modules/data"
  suffix           = local.suffix
  prod             = local.prod
  subnets          = module.network.subnets
  security_groups  = module.security.ids
  db_class         = var.db_instance_class
  postgres_version = var.postgres_version
  redis_version    = var.redis_version
  cache_node_type  = var.cache_node_type
}
