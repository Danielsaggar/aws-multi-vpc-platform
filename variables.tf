variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be dev or prod."
  }
}
variable "region" {
  type    = string
  default = "ca-central-1"
  validation {
    condition     = var.region == "ca-central-1"
    error_message = "Regional resources must use ca-central-1."
  }
}
variable "account_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Supply the intended 12-digit account ID."
  }
}
variable "project" {
  type    = string
  default = "pmp"
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,3}$", var.project))
    error_message = "Use a 2-4 character project token to respect AWS name limits."
  }
}
variable "az_ids" {
  type = list(string)
  validation {
    condition     = length(var.az_ids) == 2 && length(distinct(var.az_ids)) == 2 && alltrue([for az in var.az_ids : startswith(az, "cac1-az")])
    error_message = "Supply two distinct Canada Central AZ IDs."
  }
}
variable "primary_cidr" {
  type = string
}
variable "historical_cidr" {
  type = string
  validation {
    condition     = can(cidrnetmask(var.primary_cidr)) && can(cidrnetmask(var.historical_cidr)) && endswith(var.primary_cidr, "/16") && endswith(var.historical_cidr, "/16") && cidrhost(var.primary_cidr, 0) != cidrhost(var.historical_cidr, 0)
    error_message = "Use two distinct non-overlapping IPv4 /16 networks."
  }
}
variable "ami_id" {
  type        = string
  description = "Approved Amazon Linux 2023 x86_64 AMI in ca-central-1."
}
variable "instance_type" {
  type    = string
  default = "t3.small"
}
variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "postgres_version" {
  type    = string
  default = "16.6"
}
variable "redis_version" {
  type    = string
  default = "7.1"
}
variable "cache_node_type" {
  type    = string
  default = "cache.t4g.micro"
}
variable "domain_name" {
  type        = string
  description = "Owned base domain. Application hostnames are service.environment.domain."
}
variable "hosted_zone_id" {
  type = string
}
variable "operator_cidrs" {
  type    = list(string)
  default = []
  validation {
    condition     = length(var.operator_cidrs) <= 4 && alltrue([for cidr in var.operator_cidrs : can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"])
    error_message = "Supply at most four operator IPv4 CIDRs; unrestricted access is forbidden."
  }
}
variable "workload_boundary_arn" {
  type        = string
  description = "Bootstrap-managed permissions boundary for EC2 roles."
}
