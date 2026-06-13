# ---------------------------------------------------------------------------
# VPC Endpoints — keep AWS-bound traffic off the NAT gateway
# ---------------------------------------------------------------------------
# - S3 *Gateway* endpoint: free, and the highest-value one. ECR stores image
#   layers in S3, so `docker pull` data flows over this endpoint at no cost
#   instead of being billed as NAT data processing.
# - Interface (PrivateLink) endpoints: route specific AWS service APIs privately
#   (default: ECR registry/auth + STS for IRSA/Pod Identity). Configurable via
#   var.interface_vpc_endpoints.
# ---------------------------------------------------------------------------

# Security group for the interface endpoints: allow HTTPS only, from within the VPC.
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${local.name}-vpce-"
  description = "HTTPS from the VPC to interface VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from within the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-vpce" }

  lifecycle {
    create_before_destroy = true
  }
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.13"

  vpc_id = module.vpc.vpc_id

  # Defaults applied to every interface endpoint below.
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  endpoints = merge(
    {
      # Free gateway endpoint — attached to the private route tables.
      s3 = {
        service         = "s3"
        service_type    = "Gateway"
        route_table_ids = module.vpc.private_route_table_ids
        tags            = { Name = "${local.name}-s3-gateway" }
      }
    },
    {
      for svc in var.interface_vpc_endpoints : replace(svc, ".", "_") => {
        service             = svc
        private_dns_enabled = true
        tags                = { Name = "${local.name}-${svc}" }
      }
    }
  )
}
