locals {
  suffix = "${var.project}-${var.environment}-01-${var.region}"
  apps   = ["frontsite", "backoffice", "webapi", "gameapi"]
  prod   = var.environment == "prod"
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
  instances = merge([for app_index, app in local.apps : {
    for replica in range(local.prod ? 2 : 1) : "${app}-${replica + 1}" => {
      app  = app
      az   = local.prod ? replica : app_index % 2
      name = "${app}-${var.project}-${var.environment}-${format("%02d", replica + 1)}-${var.region}"
    }
  }]...)
}
