module "cdn" {
  source = "./modules/cdn"
  suffix = local.suffix
  bucket = module.storage.buckets["static"]
}
