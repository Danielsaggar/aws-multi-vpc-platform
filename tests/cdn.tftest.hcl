mock_provider "aws" {}
run "private_origin" {
  command = plan
  module { source = "./modules/cdn" }
  variables {
    suffix = "pmp-dev-01-ca-central-1"
    bucket = { id = "test", arn = "arn:aws:s3:::test", domain = "test.s3.ca-central-1.amazonaws.com" }
  }
  assert {
    condition     = aws_cloudfront_origin_access_control.this.signing_behavior == "always" && aws_cloudfront_origin_access_control.this.signing_protocol == "sigv4"
    error_message = "CloudFront must always sign private origin requests."
  }
  assert {
    condition     = aws_cloudfront_distribution.this.default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https"
    error_message = "CDN viewers must use HTTPS."
  }
}
