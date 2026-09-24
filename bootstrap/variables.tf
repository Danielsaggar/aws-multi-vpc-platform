variable "account_id" { type = string }
variable "project" {
  type    = string
  default = "pmp"
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,3}$", var.project))
    error_message = "Use a 2-4 character project token matching the platform root."
  }
}
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Use dev or prod; bootstrap once per account."
  }
}
variable "github_repository" {
  type = string
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Use the exact GitHub owner/repository, without wildcards."
  }
}
variable "existing_oidc_provider_arn" {
  type    = string
  default = null
}
variable "hosted_zone_id" { type = string }
