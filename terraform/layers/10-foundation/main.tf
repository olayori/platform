provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.name_prefix
      Environment = var.environment
      ManagedBy   = "terraform"
      Layer       = "foundation"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.name_prefix}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # The EKS cluster (created in the compute layer) shares this name. Subnets are
  # tagged for cluster discovery up front so the compute layer needs no changes.
  cluster_name = local.name
}
