variable "region" {
  description = "AWS region for the platform."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix applied to all resource names."
  type        = string
  default     = "adowol"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the platform VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to span."
  type        = number
  default     = 3
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (cheaper, fine for one non-prod env). Set false for one-per-AZ HA."
  type        = bool
  default     = true
}

variable "service_names" {
  description = "Services that each get a private ECR repository."
  type        = list(string)
  default     = ["service-a", "service-b", "frontend"]
}

variable "github_repo" {
  description = "GitHub repository (owner/name) allowed to assume the CI role via OIDC."
  type        = string
  default     = "olayori/platform"
}

variable "interface_vpc_endpoints" {
  description = <<-EOT
    AWS services exposed via Interface (PrivateLink) VPC endpoints so their traffic
    stays off the NAT gateway. The S3 *gateway* endpoint is always created (it is free
    and carries ECR image-layer data, the bulk of EKS egress).

    Each interface endpoint costs ~$0.01/hr PER AZ plus $0.01/GB, so it trades a fixed
    hourly cost for avoided NAT data processing ($0.045/GB). The default set covers the
    EKS essentials (image pulls + IRSA/Pod Identity). Set to [] to keep only the free
    S3 gateway endpoint. Other useful values: "logs", "ec2", "elasticloadbalancing",
    "ssm", "ssmmessages", "ec2messages".
  EOT
  type        = list(string)
  default     = ["ecr.api", "ecr.dkr", "sts"]
}
