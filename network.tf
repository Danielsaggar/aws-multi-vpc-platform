module "network" {
  source          = "./modules/network"
  suffix          = local.suffix
  primary_cidr    = var.primary_cidr
  historical_cidr = var.historical_cidr
  az_ids          = var.az_ids
  nat_count       = local.prod ? 2 : 1
}
module "security" {
  source         = "./modules/security"
  suffix         = local.suffix
  primary_vpc    = module.network.primary_vpc_id
  historical_vpc = module.network.historical_vpc_id
  subnets        = module.network.subnets
  apps           = local.apps
}
