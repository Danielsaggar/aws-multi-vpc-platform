provider "aws" {
  region              = "ca-central-1"
  allowed_account_ids = [var.account_id]
  default_tags {
    tags = { Project = var.project, Environment = var.environment, ManagedBy = "Terraform" }
  }
}
