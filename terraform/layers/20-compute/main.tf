provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.name_prefix
      Environment = var.environment
      ManagedBy   = "terraform"
      Layer       = "compute"
    }
  }
}

# Read the foundation layer's outputs (VPC, subnets, KMS, cluster name).
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "layers/10-foundation/terraform.tfstate"
    region = var.region
  }
}

locals {
  name         = "${var.name_prefix}-${var.environment}"
  cluster_name = data.terraform_remote_state.foundation.outputs.cluster_name
  vpc_id       = data.terraform_remote_state.foundation.outputs.vpc_id
  subnet_ids   = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  kms_key_arn  = data.terraform_remote_state.foundation.outputs.kms_key_arn
}

# ---------------------------------------------------------------------------
# EKS — Auto Mode
# ---------------------------------------------------------------------------
# Auto Mode (cluster_compute_config.enabled = true) makes AWS manage compute
# autoscaling (Karpenter), the AWS Load Balancer Controller, EBS CSI, pod
# networking, CoreDNS scaling and node OS patching. We declare almost nothing
# about nodes — we just enable the built-in node pools.
# ---------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = local.vpc_id
  subnet_ids = local.subnet_ids

  # --- EKS Auto Mode ---
  cluster_compute_config = {
    enabled    = true
    node_pools = var.node_pools
  }

  # Modern API-based authz (no aws-auth ConfigMap). The operator running
  # `terraform apply` is granted cluster-admin via an access entry so kubectl
  # and the addons layer work immediately.
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  cluster_endpoint_public_access = var.cluster_endpoint_public_access

  # Envelope-encrypt Kubernetes secrets with the foundation KMS key.
  cluster_encryption_config = {
    provider_key_arn = local.kms_key_arn
    resources        = ["secrets"]
  }

  # Ship control-plane logs to CloudWatch.
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }
}
