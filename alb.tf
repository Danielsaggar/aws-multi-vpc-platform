module "ingress" {
  source            = "./modules/ingress"
  suffix            = local.suffix
  environment       = var.environment
  prod              = local.prod
  apps              = local.apps
  domain            = var.domain_name
  zone_id           = var.hosted_zone_id
  operator_cidrs    = var.operator_cidrs
  vpc_id            = module.network.primary_vpc_id
  subnets           = [for s in values(module.network.subnets) : s.id if s.tier == "public"]
  security_group_id = module.security.ids["alb"]
  log_bucket        = module.storage.buckets["alblogs"].id
  depends_on        = [module.storage]
}
