mock_provider "aws" {}
run "network_prod_routes" {
  command = plan
  module { source = "./modules/network" }
  variables {
    suffix          = "pmp-prod-01-ca-central-1"
    primary_cidr    = "10.20.0.0/16"
    historical_cidr = "10.21.0.0/16"
    az_ids          = ["cac1-az1", "cac1-az2"]
    nat_count       = 2
  }
  assert {
    condition     = length(aws_route.peer) == 8 && length(aws_nat_gateway.this) == 2
    error_message = "PROD requires reciprocal application/history routes and two NAT gateways."
  }
  assert {
    condition     = alltrue([for k, route in aws_route.nat : startswith(k, "app-")]) && length(aws_route.nat) == 2
    error_message = "Only application subnets may have NAT default routes."
  }
  assert {
    condition     = alltrue([for s in aws_subnet.this : !s.map_public_ip_on_launch])
    error_message = "No subnet may automatically assign public instance addresses."
  }
}
