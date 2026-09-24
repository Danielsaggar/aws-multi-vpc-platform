locals {
  suffix    = "${var.project}-${var.environment}-01-ca-central-1"
  state_key = "platform/${var.environment}/terraform.tfstate"
  oidc_arn  = var.existing_oidc_provider_arn == null ? aws_iam_openid_connect_provider.github[0].arn : var.existing_oidc_provider_arn
}
resource "aws_kms_key" "state" {
  description             = "Terraform state encryption ${var.environment}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  lifecycle { prevent_destroy = true }
}
resource "aws_s3_bucket" "state" {
  bucket = "state-${var.project}-${var.environment}-${var.account_id}01-ca-central-1"
  lifecycle { prevent_destroy = true }
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id
  rule { object_ownership = "BucketOwnerEnforced" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Sid = "DenyInsecureTransport", Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } },
    { Sid = "RequireKmsEncryption", Effect = "Deny", Principal = "*", Action = "s3:PutObject", Resource = "${aws_s3_bucket.state.arn}/*", Condition = { StringNotEquals = { "s3:x-amz-server-side-encryption" = "aws:kms" } } },
    { Sid = "RequireStateKmsKey", Effect = "Deny", Principal = "*", Action = "s3:PutObject", Resource = "${aws_s3_bucket.state.arn}/*", Condition = { ArnNotEquals = { "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.state.arn } } }
  ] })
}
resource "aws_iam_openid_connect_provider" "github" {
  count          = var.existing_oidc_provider_arn == null ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
resource "aws_iam_policy" "boundary" {
  name = "boundary-${local.suffix}"
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"], Resource = "arn:aws:logs:ca-central-1:${var.account_id}:log-group:/platform/${local.suffix}/*:*" },
    { Effect = "Allow", Action = ["s3:GetObject"], Resource = "arn:aws:s3:::artifacts-${var.project}-${var.environment}-${var.account_id}01-ca-central-1/*" },
    { Effect = "Allow", Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"], Resource = "arn:aws:secretsmanager:ca-central-1:${var.account_id}:secret:secret-*-${local.suffix}-??????" },
    { Effect = "Allow", Action = ["elasticache:Connect"], Resource = ["arn:aws:elasticache:ca-central-1:${var.account_id}:replicationgroup:redis-${local.suffix}", "arn:aws:elasticache:ca-central-1:${var.account_id}:user:app-${local.suffix}"] }
  ] })
}
resource "aws_iam_role" "github" {
  for_each             = toset(["plan", "deploy"])
  name                 = "${each.key}-${local.suffix}"
  max_session_duration = 3600
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Federated = local.oidc_arn }, Action = "sts:AssumeRoleWithWebIdentity", Condition = { StringEquals = {
    "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
    "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:environment:${upper(var.environment)}"
  } } }] })
}
resource "aws_iam_role_policy" "state" {
  for_each = aws_iam_role.github
  name     = "platform-state"
  role     = each.value.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["s3:ListBucket"], Resource = aws_s3_bucket.state.arn, Condition = { StringLike = { "s3:prefix" = [local.state_key, "${local.state_key}.tflock"] } } },
    { Effect = "Allow", Action = each.key == "deploy" ? ["s3:GetObject", "s3:PutObject"] : ["s3:GetObject"], Resource = "${aws_s3_bucket.state.arn}/${local.state_key}" },
    { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${aws_s3_bucket.state.arn}/${local.state_key}.tflock" },
    { Effect = "Allow", Action = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"], Resource = aws_kms_key.state.arn, Condition = { StringEquals = { "kms:ViaService" = "s3.ca-central-1.amazonaws.com" } } }
  ] })
}
resource "aws_iam_role_policy" "read" {
  for_each = aws_iam_role.github
  name     = "infrastructure-read"
  role     = each.value.id
  policy   = file("${path.module}/read-policy.json")
}
resource "aws_iam_role_policy" "deploy" {
  name = "infrastructure-write"
  role = aws_iam_role.github["deploy"].id
  policy = templatefile("${path.module}/deploy-policy.json.tftpl", {
    account = var.account_id, project = var.project, environment = var.environment, boundary = aws_iam_policy.boundary.arn,
    zone    = var.hosted_zone_id, suffix = local.suffix
  })
}
