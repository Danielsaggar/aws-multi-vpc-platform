variable "suffix" { type = string }
variable "bucket" { type = object({ id = string, arn = string, domain = string }) }
resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "oac-${var.suffix}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  comment             = "cdn-${var.suffix}"
  origin {
    domain_name              = var.bucket.domain
    origin_id                = "static"
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }
  default_cache_behavior {
    target_origin_id       = "static"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }
  restrictions {
    geo_restriction { restriction_type = "none" }
  }
  viewer_certificate { cloudfront_default_certificate = true }
  tags = { Name = "cdn-${var.suffix}" }
}
resource "aws_s3_bucket_policy" "static" {
  bucket = var.bucket.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Principal = { Service = "cloudfront.amazonaws.com" }, Action = "s3:GetObject", Resource = "${var.bucket.arn}/*", Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.this.arn } } },
    { Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [var.bucket.arn, "${var.bucket.arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } }
  ] })
}
output "domain" { value = aws_cloudfront_distribution.this.domain_name }
output "id" { value = aws_cloudfront_distribution.this.id }
