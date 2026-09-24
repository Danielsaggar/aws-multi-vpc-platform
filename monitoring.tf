module "observability" {
  source    = "./modules/observability"
  suffix    = local.suffix
  apps      = local.apps
  retention = local.prod ? 90 : 14
}
