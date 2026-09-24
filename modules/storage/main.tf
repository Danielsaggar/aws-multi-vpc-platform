variable "suffix" { type = string }
variable "account_id" { type = string }
variable "region" { type = string }
variable "retention" { type = number }
resource "aws_s3_bucket" "this" {
  for_each = toset(["static", "artifacts", "alblogs"])
  bucket   = "${each.key}-${replace(var.suffix, "-01-", "-${var.account_id}01-")}"
  tags     = { Name = "${each.key}-${var.suffix}" }
}
resource "aws_s3_bucket_public_access_block" "this" {
  for_each                = aws_s3_bucket.this
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_ownership_controls" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  rule { object_ownership = "BucketOwnerEnforced" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_versioning" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.this["alblogs"].id
  rule {
    id     = "retention"
    status = "Enabled"
    filter { prefix = "" }
    expiration { days = var.retention }
    noncurrent_version_expiration { noncurrent_days = var.retention }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
  depends_on = [aws_s3_bucket_versioning.this]
}
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.this["alblogs"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" }, Action = "s3:PutObject", Resource = "${aws_s3_bucket.this["alblogs"].arn}/alb/AWSLogs/${var.account_id}/*", Condition = { ArnLike = { "aws:SourceArn" = "arn:aws:elasticloadbalancing:${var.region}:${var.account_id}:loadbalancer/*" } } },
    { Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.this["alblogs"].arn, "${aws_s3_bucket.this["alblogs"].arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } }
  ] })
}
resource "aws_s3_bucket_policy" "artifacts" {
  bucket = aws_s3_bucket.this["artifacts"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.this["artifacts"].arn, "${aws_s3_bucket.this["artifacts"].arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } }] })
}
output "buckets" { value = { for k, v in aws_s3_bucket.this : k => { id = v.id, arn = v.arn, domain = v.bucket_regional_domain_name } } }
