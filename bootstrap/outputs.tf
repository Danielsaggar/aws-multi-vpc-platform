output "state_bucket" { value = aws_s3_bucket.state.id }
output "kms_key_arn" { value = aws_kms_key.state.arn }
output "roles" { value = { for k, role in aws_iam_role.github : k => role.arn } }
output "workload_boundary_arn" { value = aws_iam_policy.boundary.arn }
