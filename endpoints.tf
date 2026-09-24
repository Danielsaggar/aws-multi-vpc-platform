module "endpoints" {
  source            = "./modules/endpoints"
  suffix            = local.suffix
  region            = var.region
  vpc_id            = module.network.primary_vpc_id
  subnets           = module.network.subnets
  security_group_id = module.security.ids["endpoint"]
  artifact_arn      = module.storage.buckets["artifacts"].arn
  secret_arns       = values(module.data.secret_arns)
}
