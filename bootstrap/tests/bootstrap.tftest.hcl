mock_provider "aws" {}
override_resource {
  override_during = plan
  target          = aws_kms_key.state
  values          = { arn = "arn:aws:kms:ca-central-1:000000000000:key/test-state-key" }
}
override_resource {
  override_during = plan
  target          = aws_s3_bucket.state
  values          = { arn = "arn:aws:s3:::test-state-bucket" }
}
variables {
  account_id                 = "000000000000"
  environment                = "dev"
  github_repository          = "example/aws-multi-vpc-platform"
  hosted_zone_id             = "ZEXAMPLE"
  existing_oidc_provider_arn = "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
}
run "identity_and_state" {
  command = plan
  assert {
    condition = (
      jsondecode(aws_s3_bucket_policy.state.policy).Statement[1].Condition.StringNotEquals["s3:x-amz-server-side-encryption"] == "aws:kms" &&
      jsondecode(aws_s3_bucket_policy.state.policy).Statement[2].Condition.ArnNotEquals["s3:x-amz-server-side-encryption-aws-kms-key-id"] == aws_kms_key.state.arn &&
      alltrue([for s in slice(jsondecode(aws_s3_bucket_policy.state.policy).Statement, 1, 3) : s.Effect == "Deny" && s.Action == "s3:PutObject" && s.Resource == "${aws_s3_bucket.state.arn}/*"])
    )
    error_message = "State and lock writes must explicitly request the intended KMS key."
  }
  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "State versioning is mandatory."
  }
  assert {
    condition     = jsondecode(aws_iam_role.github["deploy"].assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:example/aws-multi-vpc-platform:environment:DEV"
    error_message = "OIDC trust must match the exact protected environment."
  }
}
