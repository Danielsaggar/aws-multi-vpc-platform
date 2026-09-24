mock_provider "aws" {}
run "closed_backoffice" {
  command = plan
  module { source = "./modules/ingress" }
  variables {
    suffix            = "pmp-dev-01-ca-central-1"
    environment       = "dev"
    prod              = false
    apps              = ["frontsite", "backoffice", "webapi", "gameapi"]
    domain            = "example.com"
    zone_id           = "ZEXAMPLE"
    operator_cidrs    = []
    vpc_id            = "vpc-11111111"
    subnets           = ["subnet-11111111", "subnet-22222222"]
    security_group_id = "sg-11111111"
    log_bucket        = "logs-example"
  }
  assert {
    condition     = !contains(keys(aws_lb_listener_rule.app), "backoffice") && length(aws_lb_listener_rule.app) == 3
    error_message = "Empty operator allowlist must keep backoffice closed."
  }
  assert {
    condition     = aws_lb_listener.http.default_action[0].redirect[0].protocol == "HTTPS" && aws_lb_listener.https.default_action[0].fixed_response[0].status_code == "403"
    error_message = "HTTP must redirect; unmatched HTTPS requests must be denied."
  }
}
