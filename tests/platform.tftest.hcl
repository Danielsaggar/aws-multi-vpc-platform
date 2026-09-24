mock_provider "aws" {
  mock_resource "aws_db_instance" {
    defaults = { master_user_secret = [{ secret_arn = "arn:aws:secretsmanager:ca-central-1:000000000000:secret:rds!db-test", kms_key_id = "test", secret_status = "active" }] }
  }
  mock_resource "aws_acm_certificate" {
    defaults = { domain_validation_options = [{ domain_name = "*.dev.example.com", resource_record_name = "_test.dev.example.com", resource_record_type = "CNAME", resource_record_value = "_test.acm-validations.aws" }] }
  }
}
variables {
  environment           = "dev"
  account_id            = "000000000000"
  az_ids                = ["cac1-az1", "cac1-az2"]
  primary_cidr          = "10.10.0.0/16"
  historical_cidr       = "10.11.0.0/16"
  ami_id                = "ami-00000000000000000"
  domain_name           = "example.com"
  hosted_zone_id        = "Z000000000"
  workload_boundary_arn = "arn:aws:iam::000000000000:policy/test-boundary"
}
run "dev" {
  command = plan
  assert {
    condition     = length(local.instances) == 4 && length(distinct([for i in values(local.instances) : i.az])) == 2
    error_message = "DEV requires four applications distributed across two AZs."
  }
  assert {
    condition     = length(module.network.subnets) == 12 && alltrue([for s in values(module.network.subnets) : endswith(s.cidr, "/24")])
    error_message = "The architecture requires twelve /24 subnets."
  }
}
run "prod" {
  command = plan
  variables {
    environment     = "prod"
    primary_cidr    = "10.20.0.0/16"
    historical_cidr = "10.21.0.0/16"
  }
  assert {
    condition     = length(local.instances) == 8 && alltrue([for app in local.apps : length(distinct([for i in values(local.instances) : i.az if i.app == app])) == 2])
    error_message = "PROD needs two AZs for each application."
  }
}
run "reject_overlapping_cidrs" {
  command = plan
  variables { historical_cidr = "10.10.0.0/16" }
  expect_failures = [var.historical_cidr]
}
run "reject_public_backoffice" {
  command = plan
  variables { operator_cidrs = ["0.0.0.0/0"] }
  expect_failures = [var.operator_cidrs]
}
run "reject_other_region" {
  command = plan
  variables { region = "us-east-1" }
  expect_failures = [var.region]
}
