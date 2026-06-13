output "region" {
  value = var.region
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "cluster_name" {
  description = "Name the compute layer should give the EKS cluster (subnets are pre-tagged for it)."
  value       = local.cluster_name
}

output "kms_key_arn" {
  value = aws_kms_key.eks.arn
}

output "ecr_repository_urls" {
  description = "Map of service name -> ECR repository URL."
  value       = { for k, r in aws_ecr_repository.service : k => r.repository_url }
}

output "ecr_registry" {
  description = "ECR registry host (used by CI to docker login)."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

output "github_ci_role_arn" {
  description = "IAM role ARN that GitHub Actions assumes via OIDC."
  value       = aws_iam_role.github_ci.arn
}

output "vpc_endpoint_ids" {
  description = "Map of VPC endpoint key -> endpoint ID (s3 gateway + configured interface endpoints)."
  value       = { for k, v in module.vpc_endpoints.endpoints : k => v.id }
}
