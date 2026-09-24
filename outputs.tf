output "vpc_ids" { value = { primary = module.network.primary_vpc_id, historical = module.network.historical_vpc_id } }
output "instance_ids" { value = module.compute.ids }
output "alb_dns" { value = module.ingress.dns_name }
output "cdn_domain" { value = module.cdn.domain }
output "cdn_id" { value = module.cdn.id }
output "buckets" { value = module.storage.buckets }
output "database_endpoints" { value = module.data.endpoints }
output "database_secret_arns" { value = module.data.master_secret_arns }
output "application_secret_arns" { value = module.data.secret_arns }
output "redis_endpoint" { value = module.data.redis_endpoint }
