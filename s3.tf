module "storage" {
  source     = "./modules/storage"
  suffix     = local.suffix
  account_id = var.account_id
  region     = var.region
  retention  = local.prod ? 90 : 14
}
